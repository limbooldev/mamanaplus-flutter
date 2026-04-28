import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/jwt_util.dart';
import '../../../../shared/ui/ui.dart';
import '../../../chat/presentation/cubit/auth_cubit.dart';
import '../../data/social_repository.dart';
import '../cubit/social_post_cubit.dart';
import '../widgets/social_media_widgets.dart';
import '../widgets/social_post_comment_widgets.dart';
import 'social_user_list_page.dart';
import 'user_profile_page.dart';

class SocialPostPage extends StatelessWidget {
  const SocialPostPage({super.key, required this.postId});

  final int postId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SocialPostCubit(context.read<SocialRepository>(), postId),
      child: const _PostScaffold(),
    );
  }
}

class _PostScaffold extends StatelessWidget {
  const _PostScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          BlocBuilder<SocialPostCubit, SocialPostState>(
            builder: (context, state) {
              if (state is! SocialPostReady) {
                return const SizedBox.shrink();
              }
              final auth = context.watch<AuthCubit>().state;
              if (auth is! AuthAuthenticated) {
                return const SizedBox.shrink();
              }
              final me = parseUserIdFromAccessToken(auth.accessToken);
              if (me != null && me == state.post.authorId) {
                return IconButton(
                  tooltip: 'Delete post',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
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
                    if (ok == true && context.mounted) {
                      try {
                        await context
                            .read<SocialRepository>()
                            .deletePost(state.post.id);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      }
                    }
                  },
                );
              }
              return _FollowAction(targetUserId: state.post.authorId);
            },
          ),
        ],
      ),
      body: BlocBuilder<SocialPostCubit, SocialPostState>(
        builder: (context, state) {
          if (state is SocialPostLoading || state is SocialPostInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is SocialPostFailure) {
            return Center(child: Text(state.message));
          }
          if (state is! SocialPostReady) {
            return const SizedBox.shrink();
          }
          final p = state.post;
          final hasVideo =
              p.postType == 'video' && (p.mediaUrl != null && p.mediaUrl!.isNotEmpty);
          final imageRef = hasVideo ? p.thumbnailUrl : (p.thumbnailUrl ?? p.mediaUrl);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (hasVideo)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SocialPostVideo(mediaRef: p.mediaUrl),
                )
              else if (imageRef != null && imageRef.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: SocialPostImage(
                      mediaRef: imageRef,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => UserProfilePage(userId: p.authorId),
                    ),
                  );
                },
                child: Text(
                  p.authorName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.subtitleLight,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.subtitleLight,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                p.content.isNotEmpty ? p.content : 'Post',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        context.read<SocialPostCubit>().toggleLike(),
                    icon: Icon(
                      p.likedByViewer ? Icons.favorite : Icons.favorite_border,
                    ),
                    label: Text('${p.likeCount}'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        context.read<SocialPostCubit>().toggleBookmark(),
                    icon: Icon(
                      p.bookmarked ? Icons.bookmark : Icons.bookmark_border,
                    ),
                    label: const Text('Save'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await context.read<SocialPostCubit>().loadLikers();
                      if (!context.mounted) return;
                      final s = context.read<SocialPostCubit>().state;
                      if (s is! SocialPostReady) return;
                      await showModalBottomSheet<void>(
                        context: context,
                        builder: (ctx) => ListView(
                          children: [
                            const ListTile(title: Text('Liked by')),
                            ...s.likers.map(
                              (u) => ListTile(
                                title: Text(u.displayName),
                                subtitle: Text('id ${u.id}'),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.people_outline),
                    label: const Text('Likes'),
                  ),
                  TextButton(
                    onPressed: () async {
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
                      if (ok == true && context.mounted) {
                        await context.read<SocialPostCubit>().reportPost();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reported')),
                          );
                        }
                      }
                    },
                    child: const Text('Report'),
                  ),
                  TextButton(
                    onPressed: () async {
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
                      if (ok == true && context.mounted) {
                        try {
                          await context
                              .read<SocialRepository>()
                              .hideUserContent(p.authorId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Author hidden from your feed',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      }
                    },
                    child: const Text('Hide author'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => RepositoryProvider.value(
                            value: context.read<SocialRepository>(),
                            child: SocialUserListPage(
                              title: 'Followers',
                              load: (repo, page) =>
                                  repo.followers(p.authorId, page: page),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Followers'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => RepositoryProvider.value(
                            value: context.read<SocialRepository>(),
                            child: SocialUserListPage(
                              title: 'Following',
                              load: (repo, page) =>
                                  repo.following(p.authorId, page: page),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Following'),
                  ),
                ],
              ),
              const Divider(height: 32),
              Text(
                'Comments (${p.commentCount})',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SocialPostCommentComposer(
                onSubmit: (t) =>
                    context.read<SocialPostCubit>().submitComment(t),
              ),
              ...state.comments.map(
                (c) => SocialPostCommentTile(
                  comment: c,
                  onReport: (id) =>
                      context.read<SocialPostCubit>().reportComment(id),
                ),
              ),
              if (!state.commentsDone)
                TextButton(
                  onPressed: () =>
                      context.read<SocialPostCubit>().loadMoreComments(),
                  child: const Text('Load more comments'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FollowAction extends StatefulWidget {
  const _FollowAction({required this.targetUserId});

  final int targetUserId;

  @override
  State<_FollowAction> createState() => _FollowActionState();
}

class _FollowActionState extends State<_FollowAction> {
  bool? _following;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = context.read<SocialRepository>();
    try {
      final v = await r.followStatus(widget.targetUserId);
      if (mounted) setState(() => _following = v);
    } catch (_) {
      if (mounted) setState(() => _following = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_following == null) {
      return const Padding(
        padding: EdgeInsets.only(right: 12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return TextButton(
      onPressed: _busy
          ? null
          : () async {
              setState(() => _busy = true);
              final r = context.read<SocialRepository>();
              final messenger = ScaffoldMessenger.of(context);
              try {
                if (_following!) {
                  await r.unfollowUser(widget.targetUserId);
                } else {
                  await r.followUser(widget.targetUserId);
                }
                if (!mounted) return;
                setState(() {
                  _following = !_following!;
                  _busy = false;
                });
              } catch (e) {
                if (!mounted) return;
                setState(() => _busy = false);
                messenger.showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            },
      child: Text(_following! ? 'Unfollow' : 'Follow'),
    );
  }
}
