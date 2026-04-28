import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/api_config.dart';
import '../../../../core/jwt_util.dart';
import '../../../../shared/ui/ui.dart';
import '../../../chat/presentation/cubit/auth_cubit.dart';
import '../../data/social_repository.dart';
import '../../domain/social_models.dart';
import '../pages/social_user_list_page.dart';
import '../pages/user_profile_page.dart';
import 'social_comments_bottom_sheet.dart';
import 'social_media_widgets.dart';

String socialFeedRelativeTime(BuildContext context, DateTime t) {
  final now = DateTime.now();
  final d = now.difference(t);
  if (d.isNegative) return '';
  if (d.inSeconds < 60) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  if (d.inDays < 365) return '${(d.inDays / 7).floor()}w ago';
  return '${(d.inDays / 365).floor()}y ago';
}

/// Single-column feed post: header, 1:1 media (video plays inline), actions, caption, time.
/// Post-page actions live in the ⋮ menu; comments open in a bottom sheet.
class SocialFeedPostCard extends StatefulWidget {
  const SocialFeedPostCard({
    super.key,
    required this.post,
    required this.onToggleLike,
    required this.onToggleBookmark,
    required this.onCommentCountBump,
    required this.onPostDeleted,
    required this.onFeedRefresh,
  });

  final SocialPost post;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleBookmark;
  final VoidCallback onCommentCountBump;
  final VoidCallback onPostDeleted;
  final VoidCallback onFeedRefresh;

  @override
  State<SocialFeedPostCard> createState() => _SocialFeedPostCardState();
}

class _SocialFeedPostCardState extends State<SocialFeedPostCard> {
  bool? _following;
  bool _followChecked = false;
  bool _followBusy = false;

  SocialPost get post => widget.post;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_followChecked) return;
    _followChecked = true;
    final auth = context.read<AuthCubit>().state;
    final me = auth is AuthAuthenticated
        ? parseUserIdFromAccessToken(auth.accessToken)
        : null;
    if (me != null && me != post.authorId) {
      _loadFollow();
    }
  }

  int? _meId(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    if (auth is! AuthAuthenticated) return null;
    return parseUserIdFromAccessToken(auth.accessToken);
  }

  Future<void> _loadFollow() async {
    final r = context.read<SocialRepository>();
    try {
      final v = await r.followStatus(post.authorId);
      if (mounted) setState(() => _following = v);
    } catch (_) {
      if (mounted) setState(() => _following = false);
    }
  }

  Future<void> _openComments() async {
    await showSocialCommentsBottomSheet(
      context,
      postId: post.id,
      onCommentAdded: widget.onCommentCountBump,
    );
  }

  Future<void> _showLikers() async {
    final repo = context.read<SocialRepository>();
    try {
      final likers = await repo.postLikers(post.id, page: 1);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const ListTile(title: Text('Liked by')),
            ...likers.map(
              (u) => ListTile(
                title: Text(u.displayName),
                subtitle: Text('id ${u.id}'),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _onMenuSelected(String value) async {
    final repo = context.read<SocialRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    switch (value) {
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete this post?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (ok == true && mounted) {
          try {
            await repo.deletePost(post.id);
            widget.onPostDeleted();
            messenger.showSnackBar(const SnackBar(content: Text('Post deleted')));
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
        return;
      case 'follow':
        setState(() => _followBusy = true);
        try {
          await repo.followUser(post.authorId);
          if (mounted) setState(() => _following = true);
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(e.toString())));
        } finally {
          if (mounted) setState(() => _followBusy = false);
        }
        return;
      case 'unfollow':
        setState(() => _followBusy = true);
        try {
          await repo.unfollowUser(post.authorId);
          if (mounted) setState(() => _following = false);
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(e.toString())));
        } finally {
          if (mounted) setState(() => _followBusy = false);
        }
        return;
      case 'likes':
        await _showLikers();
        return;
      case 'report':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Report post?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Report'),
              ),
            ],
          ),
        );
        if (ok == true && mounted) {
          try {
            await repo.reportPost(post.id);
            messenger.showSnackBar(const SnackBar(content: Text('Reported')));
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
        return;
      case 'hide':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hide this author from your feed?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Hide'),
              ),
            ],
          ),
        );
        if (ok == true && mounted) {
          try {
            await repo.hideUserContent(post.authorId);
            widget.onFeedRefresh();
            messenger.showSnackBar(
              const SnackBar(content: Text('Author hidden from your feed')),
            );
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
        return;
      case 'followers':
        await nav.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => RepositoryProvider.value(
              value: repo,
              child: SocialUserListPage(
                title: 'Followers',
                load: (r, page) => r.followers(post.authorId, page: page),
              ),
            ),
          ),
        );
        return;
      case 'following':
        await nav.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => RepositoryProvider.value(
              value: repo,
              child: SocialUserListPage(
                title: 'Following',
                load: (r, page) => r.following(post.authorId, page: page),
              ),
            ),
          ),
        );
        return;
      default:
        return;
    }
  }

  List<PopupMenuEntry<String>> _menuEntries(BuildContext context, int? me) {
    final owner = me != null && me == post.authorId;
    final out = <PopupMenuEntry<String>>[];

    if (owner) {
      out.add(const PopupMenuItem(value: 'delete', child: Text('Delete')));
    } else if (me != null) {
      if (_followBusy) {
        out.add(
          PopupMenuItem(
            enabled: false,
            child: SizedBox(
              height: 24,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        );
      } else if (_following == true) {
        out.add(
          const PopupMenuItem(value: 'unfollow', child: Text('Unfollow')),
        );
      } else {
        out.add(const PopupMenuItem(value: 'follow', child: Text('Follow')));
      }
    }

    out.add(const PopupMenuItem(value: 'likes', child: Text('View likes')));

    if (!owner && me != null) {
      out.add(const PopupMenuItem(value: 'report', child: Text('Report')));
      out.add(const PopupMenuItem(value: 'hide', child: Text('Hide author')));
    }

    out.add(const PopupMenuItem(value: 'followers', child: Text('Followers')));
    out.add(const PopupMenuItem(value: 'following', child: Text('Following')));

    return out;
  }

  Future<void> _sharePost() async {
    final config = context.read<ApiConfig>();
    final link = 'mamana://social/post/${post.id}';
    final apiRef = '${config.baseUrl}/v1/social/posts/${post.id}';
    final body = StringBuffer()
      ..writeln(post.authorName)
      ..writeln(post.content)
      ..writeln()
      ..writeln(link)
      ..writeln(apiRef);
    await Share.share(body.toString());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final muted = isDark ? AppColors.subtitleDark : AppColors.subtitleLight;
    final me = _meId(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => UserProfilePage(userId: post.authorId),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.25),
                        child: Text(
                          post.authorName.isNotEmpty
                              ? post.authorName[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          post.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, color: onSurface),
                onSelected: _onMenuSelected,
                itemBuilder: (ctx) => _menuEntries(ctx, me),
              ),
            ],
          ),
        ),
        AspectRatio(
          aspectRatio: 1,
          child: _FeedMediaPreview(post: post),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: widget.onToggleLike,
                icon: Icon(
                  post.likedByViewer ? Icons.favorite : Icons.favorite_border,
                  color: post.likedByViewer ? Colors.redAccent : onSurface,
                  size: 26,
                ),
              ),
              Text(
                '${post.likeCount}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: onSurface,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _openComments,
                icon: Icon(Icons.chat_bubble_outline, color: onSurface, size: 24),
              ),
              Text(
                '${post.commentCount}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: onSurface,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _sharePost,
                icon: Icon(Icons.send_outlined, color: onSurface, size: 24),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: widget.onToggleBookmark,
                icon: Icon(
                  post.bookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: onSurface,
                  size: 26,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: _ExpandableCaption(
            username: post.authorName,
            caption: post.content,
            onSurface: onSurface,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          child: Text(
            socialFeedRelativeTime(context, post.createdAt),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: muted,
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
      ],
    );
  }
}

class _FeedMediaPreview extends StatelessWidget {
  const _FeedMediaPreview({required this.post});

  final SocialPost post;

  @override
  Widget build(BuildContext context) {
    if (post.postType == 'video') {
      final url = post.mediaUrl;
      if (url != null && url.isNotEmpty) {
        return SocialPostVideo(mediaRef: url);
      }
      final t = post.thumbnailUrl;
      if (t != null && t.isNotEmpty) {
        return SocialPostImage(mediaRef: t, fit: BoxFit.cover);
      }
      return ColoredBox(
        color: Colors.grey.shade900,
        child: const Center(
          child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 64),
        ),
      );
    }
    final ref = post.thumbnailUrl ?? post.mediaUrl;
    if (ref != null && ref.isNotEmpty) {
      return SocialPostImage(mediaRef: ref, fit: BoxFit.cover);
    }
    return ColoredBox(
      color: Colors.grey.shade800,
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.white38, size: 48),
      ),
    );
  }
}

class _ExpandableCaption extends StatefulWidget {
  const _ExpandableCaption({
    required this.username,
    required this.caption,
    required this.onSurface,
  });

  final String username;
  final String caption;
  final Color onSurface;

  @override
  State<_ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<_ExpandableCaption> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cap = widget.caption.trim();
    if (cap.isEmpty && widget.username.isEmpty) {
      return const SizedBox.shrink();
    }
    if (cap.isEmpty) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: widget.username,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: widget.onSurface,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final baseStyle = GoogleFonts.inter(
          fontSize: 14,
          height: 1.35,
          color: widget.onSurface,
        );
        final boldName = GoogleFonts.inter(
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w700,
          color: widget.onSurface,
        );
        final span = TextSpan(
          children: [
            TextSpan(text: '${widget.username} ', style: boldName),
            TextSpan(text: cap, style: baseStyle),
          ],
        );
        final measure = TextPainter(
          text: span,
          textDirection: TextDirection.ltr,
          maxLines: 2,
        )..layout(maxWidth: constraints.maxWidth);
        final exceeds = measure.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              span,
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (exceeds)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _expanded ? 'less' : 'more',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: widget.onSurface.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
