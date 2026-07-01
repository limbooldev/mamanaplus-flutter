import 'dart:async';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/social_repository.dart';
import '../../domain/social_models.dart';

sealed class ExploreFeedState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ExploreFeedInitial extends ExploreFeedState {}

class ExploreFeedLoading extends ExploreFeedState {}

class ExploreFeedLoaded extends ExploreFeedState {
  ExploreFeedLoaded({
    required this.posts,
    required this.nextPageToFetch,
    this.loadingMore = false,
    this.hasMore = true,
    this.loadError,
  });

  final List<SocialPost> posts;
  final int nextPageToFetch;
  final bool loadingMore;
  final bool hasMore;
  final String? loadError;

  @override
  List<Object?> get props => [posts, nextPageToFetch, loadingMore, hasMore, loadError];
}

class ExploreFeedFailure extends ExploreFeedState {
  ExploreFeedFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

/// Vertical Explore feed: seed post first, then related posts from the API.
class ExploreFeedCubit extends Cubit<ExploreFeedState> {
  ExploreFeedCubit(this._repo, this._seedPost)
      : super(ExploreFeedInitial()) {
    emit(ExploreFeedLoaded(
      posts: [_seedPost],
      nextPageToFetch: 1,
      hasMore: true,
      loadingMore: false,
    ));
    unawaited(loadMore());
  }

  final SocialRepository _repo;
  final SocialPost _seedPost;

  final Set<int> _pendingViewIds = {};
  final Set<int> _recordedViewIds = {};
  Timer? _viewFlushTimer;

  @override
  Future<void> close() {
    _viewFlushTimer?.cancel();
    unawaited(_flushViews());
    return super.close();
  }

  Future<void> loadMore() async {
    final s = state;
    if (s is! ExploreFeedLoaded || s.loadingMore || !s.hasMore) return;
    emit(ExploreFeedLoaded(
      posts: s.posts,
      nextPageToFetch: s.nextPageToFetch,
      loadingMore: true,
      hasMore: s.hasMore,
    ));
    try {
      final next = await _repo.relatedExplore(
        seedPostId: _seedPost.id,
        page: s.nextPageToFetch,
      );
      final existing = s.posts.map((p) => p.id).toSet();
      final fresh = next.where((p) => !existing.contains(p.id)).toList();
      if (fresh.isEmpty) {
        emit(ExploreFeedLoaded(
          posts: s.posts,
          nextPageToFetch: s.nextPageToFetch,
          loadingMore: false,
          hasMore: next.length >= 20,
        ));
        return;
      }
      emit(ExploreFeedLoaded(
        posts: [...s.posts, ...fresh],
        nextPageToFetch: s.nextPageToFetch + 1,
        loadingMore: false,
        hasMore: next.length >= 20,
      ));
    } catch (e) {
      emit(ExploreFeedLoaded(
        posts: s.posts,
        nextPageToFetch: s.nextPageToFetch,
        loadingMore: false,
        hasMore: false,
        loadError: _loadErrorMessage(e),
      ));
    }
  }

  static String _loadErrorMessage(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 404) {
        return 'Related feed is not available on the server yet (404).';
      }
      if (status == 500) {
        return 'Server error loading related posts (500).';
      }
      if (status != null) {
        return 'Could not load more posts (HTTP $status).';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Could not reach the server. Check your connection.';
      }
    }
    return 'Could not load more posts.';
  }

  void clearLoadError() {
    final s = state;
    if (s is! ExploreFeedLoaded || s.loadError == null) return;
    emit(ExploreFeedLoaded(
      posts: s.posts,
      nextPageToFetch: s.nextPageToFetch,
      loadingMore: s.loadingMore,
      hasMore: true,
      loadError: null,
    ));
  }

  Future<void> retryLoadMore() async {
    clearLoadError();
    await loadMore();
  }

  void markPostVisible(int postId) {
    if (postId <= 0 || _recordedViewIds.contains(postId)) return;
    _pendingViewIds.add(postId);
    _viewFlushTimer?.cancel();
    _viewFlushTimer = Timer(const Duration(milliseconds: 600), () {
      unawaited(_flushViews());
    });
  }

  Future<void> _flushViews() async {
    if (_pendingViewIds.isEmpty) return;
    final batch = List<int>.from(_pendingViewIds);
    _pendingViewIds.clear();
    try {
      await _repo.recordPostViews(batch);
      _recordedViewIds.addAll(batch);
    } catch (_) {
      _pendingViewIds.addAll(batch);
    }
  }

  Future<void> toggleLike(int postId) async {
    final s = state;
    if (s is! ExploreFeedLoaded) return;
    final i = s.posts.indexWhere((p) => p.id == postId);
    if (i < 0) return;
    final p = s.posts[i];
    final nextLiked = !p.likedByViewer;
    final nextCount = p.likeCount + (nextLiked ? 1 : -1);
    _replacePostAt(
      s,
      i,
      p.copyWith(
        likedByViewer: nextLiked,
        likeCount: nextCount < 0 ? 0 : nextCount,
      ),
    );
    try {
      if (nextLiked) {
        await _repo.likePost(postId);
      } else {
        await _repo.unlikePost(postId);
      }
    } catch (_) {
      _replacePostAt(s, i, p);
    }
  }

  Future<void> toggleBookmark(int postId) async {
    final s = state;
    if (s is! ExploreFeedLoaded) return;
    final i = s.posts.indexWhere((p) => p.id == postId);
    if (i < 0) return;
    final p = s.posts[i];
    final nextBm = !p.bookmarked;
    _replacePostAt(s, i, p.copyWith(bookmarked: nextBm));
    try {
      if (nextBm) {
        await _repo.bookmarkPost(postId);
      } else {
        await _repo.unbookmarkPost(postId);
      }
    } catch (_) {
      _replacePostAt(s, i, p);
    }
  }

  void _replacePostAt(ExploreFeedLoaded s, int index, SocialPost post) {
    final next = List<SocialPost>.from(s.posts);
    next[index] = post;
    emit(ExploreFeedLoaded(
      posts: next,
      nextPageToFetch: s.nextPageToFetch,
      loadingMore: s.loadingMore,
      hasMore: s.hasMore,
      loadError: s.loadError,
    ));
  }

  void bumpCommentCount(int postId, {int delta = 1}) {
    final s = state;
    if (s is! ExploreFeedLoaded) return;
    final i = s.posts.indexWhere((p) => p.id == postId);
    if (i < 0) return;
    final p = s.posts[i];
    _replacePostAt(
      s,
      i,
      p.copyWith(
        commentCount: (p.commentCount + delta).clamp(0, 1 << 30),
      ),
    );
  }

  void removePost(int postId) {
    final s = state;
    if (s is! ExploreFeedLoaded) return;
    emit(ExploreFeedLoaded(
      posts: s.posts.where((p) => p.id != postId).toList(),
      nextPageToFetch: s.nextPageToFetch,
      loadingMore: s.loadingMore,
      hasMore: s.hasMore,
      loadError: s.loadError,
    ));
  }
}
