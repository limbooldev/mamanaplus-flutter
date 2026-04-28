import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
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
                elevation: 0,
                scrolledUnderElevation: 0.5,
                surfaceTintColor: Colors.transparent,
                backgroundColor: theme.scaffoldBackgroundColor,
                title: Text(
                  p.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                actions: [
                  if (!isSelf && me != null)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz),
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
              ),
              SliverToBoxAdapter(child: _igProfileBlock(context, theme, p, isSelf: isSelf, me: me)),
              const SliverToBoxAdapter(child: _IgPostsTabStrip()),
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
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                    childAspectRatio: 1,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final post = _posts[i];
                      final tileBg = theme.brightness == Brightness.dark
                          ? const Color(0xFF121212)
                          : theme.colorScheme.surfaceContainerHighest;
                      return Material(
                        color: tileBg,
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

  static const Color _igFollowBlue = Color(0xFF0095F6);

  Widget _igProfileBlock(
    BuildContext context,
    ThemeData theme,
    UserProfile p, {
    required bool isSelf,
    required int? me,
  }) {
    final fmt = NumberFormat('#,###');
    final onSurface = theme.colorScheme.onSurface;
    final igGreyFill = theme.brightness == Brightness.dark
        ? const Color(0xFF262626)
        : const Color(0xFFEFEFEF);
    final igGreyFg = theme.brightness == Brightness.dark ? Colors.white : Colors.black87;

    ButtonStyle igCompactGrey({bool outlined = false}) {
      final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
      if (outlined) {
        return OutlinedButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: shape,
          side: BorderSide(color: theme.dividerColor),
          foregroundColor: onSurface,
        );
      }
      return FilledButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        elevation: 0,
        shape: shape,
        backgroundColor: igGreyFill,
        foregroundColor: igGreyFg,
      );
    }

    void openFollowers() {
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
    }

    void openFollowing() {
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
    }

    Future<void> openEdit() async {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const EditProfilePage()),
      );
      if (mounted) await _refreshAll();
    }

    Future<void> shareProfile() async {
      await Share.share('${p.displayName} — Mamana+');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipOval(
                child: SizedBox(
                  width: 86,
                  height: 86,
                  child: p.avatarMediaKey != null && p.avatarMediaKey!.isNotEmpty
                      ? SocialPostImage(
                          mediaRef: p.avatarMediaKey,
                          fit: BoxFit.cover,
                        )
                      : ColoredBox(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          child: Center(
                            child: Text(
                              p.displayName.isNotEmpty ? p.displayName[0].toUpperCase() : '?',
                              style: GoogleFonts.inter(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _IgStatColumn(
                        valueText: fmt.format(p.postsCount),
                        label: 'Posts',
                        onTap: null,
                      ),
                    ),
                    Expanded(
                      child: _IgStatColumn(
                        valueText: fmt.format(p.followersCount),
                        label: 'Followers',
                        onTap: openFollowers,
                      ),
                    ),
                    Expanded(
                      child: _IgStatColumn(
                        valueText: fmt.format(p.followingCount),
                        label: 'Following',
                        onTap: openFollowing,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!p.profileApproved)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Pending approval',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ),
          Text(
            p.displayName,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: onSurface,
            ),
          ),
          if (p.bio.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              p.bio,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.35,
                color: onSurface,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (isSelf)
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: openEdit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      elevation: 0,
                      backgroundColor: igGreyFill,
                      foregroundColor: igGreyFg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'Edit profile',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FilledButton(
                    onPressed: shareProfile,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      elevation: 0,
                      backgroundColor: igGreyFill,
                      foregroundColor: igGreyFg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'Share profile',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
              ],
            )
          else if (me != null)
            Row(
              children: [
                Expanded(
                  child: p.following
                      ? FilledButton(
                          onPressed: _followBusy ? null : () => _toggleFollow(p),
                          style: igCompactGrey(),
                          child: Text(
                            'Following',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        )
                      : FilledButton(
                          onPressed: _followBusy ? null : () => _toggleFollow(p),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            elevation: 0,
                            backgroundColor: _igFollowBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            'Follow',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _messageUser,
                    style: igCompactGrey(outlined: true),
                    child: Text(
                      'Message',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
                if (_isSuperAdmin && !p.profileApproved) ...[
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 44,
                    height: 36,
                    child: FilledButton(
                      onPressed: _actionBusy ? null : _approveProfile,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        elevation: 0,
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Icon(Icons.check, size: 20),
                    ),
                  ),
                ],
              ],
            ),
        ],
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
      color: Colors.black26,
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
    child: Icon(Icons.article_outlined, color: Color(0xFF8E8E8E)),
  );
}

/// Instagram-style stat: bold count on top, label below, equal width columns.
class _IgStatColumn extends StatelessWidget {
  const _IgStatColumn({
    required this.valueText,
    required this.label,
    this.onTap,
  });

  final String valueText;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.75);
    final col = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            valueText,
            maxLines: 1,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: muted,
          ),
        ),
      ],
    );
    final padded = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: col,
    );
    if (onTap == null) {
      return SizedBox(width: double.infinity, child: padded);
    }
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: padded,
      ),
    );
  }
}

/// Single “Posts” grid tab with underline, matching Instagram’s tab strip.
class _IgPostsTabStrip extends StatelessWidget {
  const _IgPostsTabStrip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = theme.colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.35)),
        ),
      ),
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.grid_on_rounded, size: 22, color: line),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(height: 1.5, width: 28, color: line),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
