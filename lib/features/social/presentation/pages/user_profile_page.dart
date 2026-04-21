import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/jwt_util.dart';
import '../../../../router/app_routes.dart';
import '../../../../shared/ui/ui.dart';
import '../../../chat/data/chat_repository.dart';
import '../../../chat/presentation/cubit/auth_cubit.dart';
import '../../data/social_repository.dart';
import '../../domain/social_models.dart';
import '../widgets/social_media_widgets.dart';
import 'edit_profile_page.dart';
import 'social_user_list_page.dart';
import 'user_posts_feed_page.dart';

/// Public profile for any user (including self). Requires auth + [SocialRepository].
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key, required this.userId});

  final int userId;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  UserProfile? _profile;
  final List<SocialPost> _posts = [];
  bool _loadingProfile = true;
  bool _loadingPosts = false;
  bool _blocked = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  bool _isSuperAdmin = false;
  bool _followBusy = false;
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadMeFlags(), _refreshAll()]);
  }

  Future<void> _loadMeFlags() async {
    try {
      final me = await context.read<ChatRepository>().fetchMe();
      if (!mounted) return;
      setState(() => _isSuperAdmin = me['is_super_admin'] == true);
    } catch (_) {}
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loadingProfile = true;
      _error = null;
      _blocked = false;
      _posts.clear();
      _page = 1;
      _hasMore = true;
    });
    await _loadProfile();
    if (_error == null && !_blocked) {
      await _loadPosts(reset: true);
    }
  }

  Future<void> _loadProfile() async {
    final repo = context.read<SocialRepository>();
    try {
      final p = await repo.userProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = p;
        _loadingProfile = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final code = e.response?.statusCode;
      if (code == 403) {
        setState(() {
          _blocked = true;
          _loadingProfile = false;
          _error = 'You cannot view this profile.';
        });
        return;
      }
      setState(() {
        _loadingProfile = false;
        _error = e.message ?? 'Failed to load profile';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadPosts({bool reset = false}) async {
    if (_loadingPosts) return;
    if (!reset && !_hasMore) return;
    final page = reset ? 1 : _page;
    if (reset) {
      _page = 1;
      _hasMore = true;
    }
    setState(() => _loadingPosts = true);
    final repo = context.read<SocialRepository>();
    try {
      final items = await repo.userPosts(widget.userId, page: page);
      if (!mounted) return;
      setState(() {
        if (reset) {
          _posts
            ..clear()
            ..addAll(items);
        } else {
          _posts.addAll(items);
        }
        _hasMore = items.length >= 20;
        _page = page + 1;
        _loadingPosts = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 403) {
        setState(() {
          _blocked = true;
          _loadingPosts = false;
        });
        return;
      }
      setState(() => _loadingPosts = false);
    } catch (_) {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  int? _meId() {
    final auth = context.read<AuthCubit>().state;
    if (auth is! AuthAuthenticated) return null;
    return parseUserIdFromAccessToken(auth.accessToken);
  }

  Future<void> _toggleFollow(UserProfile p) async {
    if (_followBusy) return;
    setState(() => _followBusy = true);
    final repo = context.read<SocialRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (p.following) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Unfollow?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unfollow')),
            ],
          ),
        );
        if (ok == true) {
          await repo.unfollowUser(p.id);
          if (!mounted) return;
          setState(() {
            _profile = p.copyWith(
              following: false,
              followersCount: p.followersCount > 0 ? p.followersCount - 1 : 0,
            );
          });
        }
      } else {
        await repo.followUser(p.id);
        if (!mounted) return;
        setState(() {
          _profile = p.copyWith(
            following: true,
            followersCount: p.followersCount + 1,
          );
        });
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _messageUser() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dm = await context.read<ChatRepository>().createDm(widget.userId);
      final cid = (dm['id'] as num).toInt();
      if (!mounted) return;
      await context.pushThread<void>(cid, conversationType: 'private');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _approveProfile() async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    final repo = context.read<SocialRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.approveUserProfile(widget.userId);
      if (!mounted) return;
      final p = _profile;
      if (p != null) {
        setState(() => _profile = p.copyWith(profileApproved: true));
      }
      messenger.showSnackBar(const SnackBar(content: Text('Profile approved')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _toggleHide(UserProfile p) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    final repo = context.read<SocialRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (p.hiddenByMe) {
        await repo.unhideUserContent(p.id);
        if (!mounted) return;
        setState(() => _profile = p.copyWith(hiddenByMe: false));
        messenger.showSnackBar(const SnackBar(content: Text('Author unhidden')));
      } else {
        await repo.hideUserContent(p.id);
        if (!mounted) return;
        setState(() => _profile = p.copyWith(hiddenByMe: true));
        messenger.showSnackBar(const SnackBar(content: Text('Author hidden from feed')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _reportUser() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report user'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<SocialRepository>().reportUser(widget.userId, reason: ctrl.text);
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Report submitted')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loadingProfile && _profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_blocked || _error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error ?? 'This profile is not available.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 15),
            ),
          ),
        ),
      );
    }
    final p = _profile!;
    final me = _meId();
    final isSelf = p.isSelf || (me != null && me == p.id);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
              _loadPosts();
            }
            return false;
          },
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 180,
                title: Text(
                  p.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  if (isSelf)
                    IconButton(
                      tooltip: 'Edit profile',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(builder: (_) => const EditProfilePage()),
                        );
                        if (mounted) await _refreshAll();
                      },
                    ),
                  if (!isSelf && me != null)
                    PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'hide') await _toggleHide(p);
                        if (v == 'report') await _reportUser();
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'hide',
                          child: Text(p.hiddenByMe ? 'Unhide from feed' : 'Hide from feed'),
                        ),
                        const PopupMenuItem(value: 'report', child: Text('Report user')),
                      ],
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.35),
                          theme.scaffoldBackgroundColor,
                        ],
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 88,
                            height: 88,
                            child: p.avatarMediaKey != null && p.avatarMediaKey!.isNotEmpty
                                ? SocialPostImage(
                                    mediaRef: p.avatarMediaKey,
                                    fit: BoxFit.cover,
                                  )
                                : ColoredBox(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                    child: Center(
                                      child: Text(
                                        p.displayName.isNotEmpty
                                            ? p.displayName[0].toUpperCase()
                                            : '?',
                                        style: GoogleFonts.inter(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!p.profileApproved)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    'Pending approval',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: theme.colorScheme.tertiary,
                                    ),
                                  ),
                                ),
                              if (p.bio.isNotEmpty)
                                Text(
                                  p.bio,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      _StatChip(
                        label: 'Followers',
                        value: p.followersCount,
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => RepositoryProvider.value(
                                value: context.read<SocialRepository>(),
                                child: SocialUserListPage(
                                  title: 'Followers',
                                  load: (r, page) => r.followers(p.id, page: page),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _StatChip(
                        label: 'Following',
                        value: p.followingCount,
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => RepositoryProvider.value(
                                value: context.read<SocialRepository>(),
                                child: SocialUserListPage(
                                  title: 'Following',
                                  load: (r, page) => r.following(p.id, page: page),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _StatChip(label: 'Posts', value: p.postsCount, onTap: null),
                    ],
                  ),
                ),
              ),
              if (!isSelf && me != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonal(
                          onPressed: _followBusy ? null : () => _toggleFollow(p),
                          child: Text(p.following ? 'Following' : 'Follow'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _messageUser,
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text('Message'),
                        ),
                        if (_isSuperAdmin && !p.profileApproved)
                          FilledButton(
                            onPressed: _actionBusy ? null : _approveProfile,
                            child: const Text('Approve'),
                          ),
                      ],
                    ),
                  ),
                ),
              if (_posts.isEmpty && !_loadingPosts)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No posts yet',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 1,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final post = _posts[i];
                      return Material(
                        color: Colors.grey.shade900,
                        child: InkWell(
                          onTap: () {
                            final p = _profile;
                            if (p == null) return;
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => RepositoryProvider.value(
                                  value: context.read<SocialRepository>(),
                                  child: UserPostsFeedPage(
                                    userId: widget.userId,
                                    displayName: p.displayName,
                                    scrollToPostId: post.id,
                                    seedPosts: List<SocialPost>.from(_posts),
                                    nextPageToFetch: _page,
                                    initialHasMore: _hasMore,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: _profilePostGridPreview(post),
                        ),
                      );
                    },
                    childCount: _posts.length,
                  ),
                ),
              ),
              if (_loadingPosts)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Static grid preview: video uses [SocialPost.thumbnailUrl] only (never [SocialPost.mediaUrl],
/// which points at the video file). Matches [SocialFeedPostCard] / explore tile behavior.
Widget _profilePostGridPreview(SocialPost post) {
  if (post.postType == 'video') {
    final t = post.thumbnailUrl;
    if (t != null && t.isNotEmpty) {
      return SocialPostImage(mediaRef: t, fit: BoxFit.cover);
    }
    return ColoredBox(
      color: Colors.grey.shade900,
      child: const Center(
        child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 40),
      ),
    );
  }
  final ref = post.thumbnailUrl ?? post.mediaUrl;
  if (ref != null && ref.isNotEmpty) {
    return SocialPostImage(mediaRef: ref, fit: BoxFit.cover);
  }
  return const Center(
    child: Icon(Icons.article_outlined, color: Colors.white38),
  );
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return box;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: box);
  }
}
