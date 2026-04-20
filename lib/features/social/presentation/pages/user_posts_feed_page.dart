import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/social_repository.dart';
import '../../domain/social_models.dart';
import '../cubit/user_posts_feed_cubit.dart';
import '../widgets/social_feed_post_card.dart';

/// Full-height feed of one user's posts (same cards as Community), optionally
/// seeded from the profile grid and scrolled to [scrollToPostId].
class UserPostsFeedPage extends StatefulWidget {
  const UserPostsFeedPage({
    super.key,
    required this.userId,
    required this.displayName,
    required this.scrollToPostId,
    this.seedPosts = const [],
    required this.nextPageToFetch,
    required this.initialHasMore,
  });

  final int userId;
  final String displayName;
  final int scrollToPostId;
  final List<SocialPost> seedPosts;
  final int nextPageToFetch;
  final bool initialHasMore;

  @override
  State<UserPostsFeedPage> createState() => _UserPostsFeedPageState();
}

class _UserPostsFeedPageState extends State<UserPostsFeedPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _anchorKey = GlobalKey();
  bool _didScrollToAnchor = false;
  bool _scrollPipelineQueued = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _queueScrollToAnchor(UserPostsFeedLoaded state) {
    if (_didScrollToAnchor || _scrollPipelineQueued) return;
    final idx = state.posts.indexWhere((p) => p.id == widget.scrollToPostId);
    if (idx < 0) return;
    _scrollPipelineQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollPipelineQueued = false;
      if (!mounted || _didScrollToAnchor) return;
      _jumpThenEnsureVisible(state, idx);
    });
  }

  void _jumpThenEnsureVisible(UserPostsFeedLoaded state, int index) {
    if (!mounted || _didScrollToAnchor) return;
    final w = MediaQuery.sizeOf(context).width;
    const chromeBelowMedia = 260.0;
    final estimatedRow = w + chromeBelowMedia;
    if (_scrollController.hasClients) {
      final max = _scrollController.position.maxScrollExtent;
      final target = math.min(index * estimatedRow, max);
      _scrollController.jumpTo(target);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didScrollToAnchor) return;
      final ctx = _anchorKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.05,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
      _didScrollToAnchor = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocProvider(
      create: (_) => UserPostsFeedCubit(
        context.read<SocialRepository>(),
        widget.userId,
        seedPosts: widget.seedPosts,
        nextPageToFetch: widget.nextPageToFetch,
        seedHasMore: widget.initialHasMore,
      ),
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : null,
        appBar: AppBar(
          backgroundColor: isDark ? Colors.black : null,
          surfaceTintColor: Colors.transparent,
          title: Text(
            widget.displayName.isEmpty ? 'Posts' : '${widget.displayName} — posts',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: BlocBuilder<UserPostsFeedCubit, UserPostsFeedState>(
          builder: (context, state) {
            if (state is UserPostsFeedLoading || state is UserPostsFeedInitial) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is UserPostsFeedFailure) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.message, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => context.read<UserPostsFeedCubit>().refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (state is! UserPostsFeedLoaded) {
              return const SizedBox.shrink();
            }
            if (state.posts.isEmpty) {
              return RefreshIndicator(
                onRefresh: () => context.read<UserPostsFeedCubit>().refresh(),
                child: ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('No posts yet. Pull to refresh.')),
                  ],
                ),
              );
            }

            _queueScrollToAnchor(state);

            return RefreshIndicator(
              onRefresh: () => context.read<UserPostsFeedCubit>().refresh(),
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is ScrollEndNotification) {
                    final m = n.metrics;
                    if (m.pixels >= m.maxScrollExtent - 120) {
                      context.read<UserPostsFeedCubit>().loadMore();
                    }
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: _scrollController,
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
                    final cubit = context.read<UserPostsFeedCubit>();
                    final isAnchor = p.id == widget.scrollToPostId;
                    final card = SocialFeedPostCard(
                      post: p,
                      onToggleLike: () => cubit.toggleLike(p.id),
                      onToggleBookmark: () => cubit.toggleBookmark(p.id),
                      onCommentCountBump: () => cubit.bumpCommentCount(p.id),
                      onPostDeleted: () => cubit.removePost(p.id),
                      onFeedRefresh: () => cubit.refresh(),
                    );
                    if (!isAnchor) return card;
                    return KeyedSubtree(
                      key: _anchorKey,
                      child: card,
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
