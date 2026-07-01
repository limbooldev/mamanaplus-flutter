import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/social_repository.dart';
import '../../domain/social_models.dart';
import '../cubit/explore_feed_cubit.dart';
import '../widgets/social_feed_post_card.dart';

/// Instagram-style Explore feed: tapped post first, then related posts below.
class ExploreFeedPage extends StatefulWidget {
  const ExploreFeedPage({super.key, required this.seedPost});

  final SocialPost seedPost;

  @override
  State<ExploreFeedPage> createState() => _ExploreFeedPageState();
}

class _ExploreFeedPageState extends State<ExploreFeedPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _anchorKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocProvider(
      create: (_) => ExploreFeedCubit(
        context.read<SocialRepository>(),
        widget.seedPost,
      ),
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : null,
        appBar: AppBar(
          backgroundColor: isDark ? Colors.black : null,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Explore',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
        body: BlocBuilder<ExploreFeedCubit, ExploreFeedState>(
          builder: (context, state) {
            if (state is ExploreFeedFailure) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(state.message, textAlign: TextAlign.center),
                ),
              );
            }
            if (state is! ExploreFeedLoaded) {
              return const Center(child: CircularProgressIndicator());
            }

            return NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollEndNotification) {
                  final m = n.metrics;
                  if (m.pixels >= m.maxScrollExtent - 120) {
                    context.read<ExploreFeedCubit>().loadMore();
                  }
                }
                return false;
              },
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                itemCount: state.posts.length +
                    (state.loadError != null ? 1 : 0) +
                    ((state.hasMore || state.loadingMore) ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i >= state.posts.length + (state.loadError != null ? 1 : 0)) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  if (state.loadError != null && i == state.posts.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Could not load more posts.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: () =>
                                context.read<ExploreFeedCubit>().retryLoadMore(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  final p = state.posts[i];
                  final cubit = context.read<ExploreFeedCubit>();
                  cubit.markPostVisible(p.id);
                  final isAnchor = p.id == widget.seedPost.id;
                  final card = SocialFeedPostCard(
                    post: p,
                    onToggleLike: () => cubit.toggleLike(p.id),
                    onToggleBookmark: () => cubit.toggleBookmark(p.id),
                    onCommentCountBump: () => cubit.bumpCommentCount(p.id),
                    onPostDeleted: () => cubit.removePost(p.id),
                    onFeedRefresh: () {},
                  );
                  if (!isAnchor) return card;
                  return KeyedSubtree(
                    key: _anchorKey,
                    child: card,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
