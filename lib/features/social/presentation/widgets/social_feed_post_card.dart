import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/api_config.dart';
import '../../../../shared/ui/ui.dart';
import '../../domain/social_models.dart';
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

/// Single-column feed post: header, 1:1 media, actions, caption, time.
class SocialFeedPostCard extends StatelessWidget {
  const SocialFeedPostCard({
    super.key,
    required this.post,
    required this.onOpenPost,
    required this.onToggleLike,
    required this.onToggleBookmark,
    required this.onReport,
  });

  final SocialPost post;
  final VoidCallback onOpenPost;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleBookmark;
  final Future<void> Function() onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final muted = isDark ? AppColors.subtitleDark : AppColors.subtitleLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
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
                child: InkWell(
                  onTap: onOpenPost,
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
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, color: onSurface),
                onSelected: (v) async {
                  if (v == 'report') await onReport();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'report', child: Text('Report')),
                ],
              ),
            ],
          ),
        ),
        AspectRatio(
          aspectRatio: 1,
          child: GestureDetector(
            onTap: onOpenPost,
            child: _FeedMediaPreview(post: post),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onToggleLike,
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
                onPressed: onOpenPost,
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
                onPressed: () => _sharePost(context, post),
                icon: Icon(Icons.send_outlined, color: onSurface, size: 24),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onToggleBookmark,
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

  Future<void> _sharePost(BuildContext context, SocialPost post) async {
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
}

class _FeedMediaPreview extends StatelessWidget {
  const _FeedMediaPreview({required this.post});

  final SocialPost post;

  @override
  Widget build(BuildContext context) {
    if (post.postType == 'video') {
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
