import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/ui/ui.dart';
import '../../data/social_repository.dart';
import '../../domain/social_models.dart';
import '../cubit/social_feed_cubit.dart';
import '../widgets/social_media_widgets.dart';
import 'social_composer_page.dart';
import 'social_post_page.dart';
import 'story_viewer_page.dart';

class SocialFeedPage extends StatelessWidget {
  const SocialFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SocialFeedCubit(context.read<SocialRepository>())..refresh(),
      child: const _SocialFeedView(),
    );
  }
}

class _SocialFeedView extends StatelessWidget {
  const _SocialFeedView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => RepositoryProvider.value(
                value: context.read<SocialRepository>(),
                child: const SocialComposerPage(),
              ),
            ),
          );
          if (context.mounted) {
            context.read<SocialFeedCubit>().refresh();
          }
        },
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('New post'),
      ),
      body: BlocBuilder<SocialFeedCubit, SocialFeedState>(
        builder: (context, state) {
          if (state is SocialFeedLoading || state is SocialFeedInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is SocialFeedFailure) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(state.message, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          context.read<SocialFeedCubit>().refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state is! SocialFeedLoaded) {
            return const SizedBox.shrink();
          }
          if (state.posts.isEmpty && state.stories.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => context.read<SocialFeedCubit>().refresh(),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No posts yet. Pull to refresh.')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => context.read<SocialFeedCubit>().refresh(),
            child: Column(
              children: [
                if (state.stories.isNotEmpty)
                  _StoryStrip(
                    stories: state.stories,
                    onOpen: (ring) {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => RepositoryProvider.value(
                            value: context.read<SocialRepository>(),
                            child: StoryViewerPage(
                              storyId: ring.storyId,
                              title: ring.displayName,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is ScrollEndNotification) {
                        final m = n.metrics;
                        if (m.pixels >= m.maxScrollExtent - 80) {
                          context.read<SocialFeedCubit>().loadMore();
                        }
                      }
                      return false;
                    },
                    child: GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: state.posts.length +
                          ((state.hasMore || state.loadingMore) ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i >= state.posts.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final p = state.posts[i];
                        return _PostTile(
                          post: p,
                          onTap: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => RepositoryProvider.value(
                                  value: context.read<SocialRepository>(),
                                  child: SocialPostPage(postId: p.id),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StoryStrip extends StatelessWidget {
  const _StoryStrip({required this.stories, required this.onOpen});

  final List<StoryRing> stories;
  final void Function(StoryRing) onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = stories[i];
          return InkWell(
            onTap: () => onOpen(s),
            borderRadius: BorderRadius.circular(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      backgroundImage: (s.coverUrl != null && s.coverUrl!.isNotEmpty)
                          ? NetworkImage(s.coverUrl!)
                          : null,
                      child: (s.coverUrl == null || s.coverUrl!.isEmpty)
                          ? Text(
                              s.displayName.isNotEmpty
                                  ? s.displayName[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    if (s.hasUnseen)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 72,
                  child: Text(
                    s.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 11),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post, required this.onTap});

  final SocialPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget preview;
    if (post.postType == 'video') {
      final t = post.thumbnailUrl;
      if (t != null && t.isNotEmpty) {
        preview = SocialPostImage(mediaRef: t, fit: BoxFit.cover);
      } else {
        preview = ColoredBox(
          color: Colors.grey.shade800,
          child: const Center(
            child: Icon(
              Icons.play_circle_outline,
              color: Colors.white70,
              size: 48,
            ),
          ),
        );
      }
    } else {
      final ref = post.thumbnailUrl ?? post.mediaUrl;
      preview = ref != null && ref.isNotEmpty
          ? SocialPostImage(mediaRef: ref, fit: BoxFit.cover)
          : Container(
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: const Icon(Icons.image_outlined, size: 40),
            );
    }
    return Material(
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: preview),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.content.isNotEmpty ? post.content : 'Post',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    post.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.subtitleLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
