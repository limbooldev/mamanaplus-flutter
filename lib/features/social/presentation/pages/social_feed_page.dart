import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/ui/ui.dart';
import '../../data/social_repository.dart';
import '../../domain/social_models.dart' show StoryRing;
import '../cubit/social_feed_cubit.dart';
import '../widgets/social_feed_post_card.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : null,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : null,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Community',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
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
                        if (m.pixels >= m.maxScrollExtent - 120) {
                          context.read<SocialFeedCubit>().loadMore();
                        }
                      }
                      return false;
                    },
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: state.posts.length +
                          ((state.hasMore || state.loadingMore) ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i >= state.posts.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final p = state.posts[i];
                        final repo = context.read<SocialRepository>();
                        final cubit = context.read<SocialFeedCubit>();
                        return SocialFeedPostCard(
                          post: p,
                          onOpenPost: () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => RepositoryProvider.value(
                                  value: repo,
                                  child: SocialPostPage(postId: p.id),
                                ),
                              ),
                            );
                            if (context.mounted) {
                              cubit.refresh();
                            }
                          },
                          onToggleLike: () => cubit.toggleLike(p.id),
                          onToggleBookmark: () => cubit.toggleBookmark(p.id),
                          onReport: () async {
                            try {
                              await repo.reportPost(p.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Reported')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: isDark ? Colors.black : Theme.of(context).colorScheme.surface,
      child: SizedBox(
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
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.2),
                        backgroundImage: (s.coverUrl != null &&
                                s.coverUrl!.isNotEmpty)
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
      ),
    );
  }
}
