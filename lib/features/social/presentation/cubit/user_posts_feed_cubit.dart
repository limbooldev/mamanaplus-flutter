import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/social_repository.dart';
import '../../domain/social_models.dart';

sealed class UserPostsFeedState extends Equatable {
  @override
  List<Object?> get props => [];
}

class UserPostsFeedInitial extends UserPostsFeedState {}

class UserPostsFeedLoading extends UserPostsFeedState {}

class UserPostsFeedLoaded extends UserPostsFeedState {
  UserPostsFeedLoaded({
    required this.posts,
    required this.nextPageToFetch,
    this.loadingMore = false,
    this.hasMore = true,
  });

  final List<SocialPost> posts;
  /// Next `page` query param for [SocialRepository.userPosts] (1-based).
  final int nextPageToFetch;
  final bool loadingMore;
  final bool hasMore;

  @override
  List<Object?> get props => [posts, nextPageToFetch, loadingMore, hasMore];
}

class UserPostsFeedFailure extends UserPostsFeedState {
  UserPostsFeedFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

/// Paginated posts for one user (same API actions as [SocialFeedCubit]).
class UserPostsFeedCubit extends Cubit<UserPostsFeedState> {
  UserPostsFeedCubit(
    this._repo,
    this.userId, {
    List<SocialPost>? seedPosts,
    int? nextPageToFetch,
    bool? seedHasMore,
  }) : super(UserPostsFeedInitial()) {
    if (seedPosts != null && seedPosts.isNotEmpty) {
      emit(UserPostsFeedLoaded(
        posts: List<SocialPost>.from(seedPosts),
        nextPageToFetch: nextPageToFetch ?? 2,
        hasMore: seedHasMore ?? true,
        loadingMore: false,
      ));
    } else {
      refresh();
    }
  }

  final SocialRepository _repo;
  final int userId;

  Future<void> refresh() async {
    emit(UserPostsFeedLoading());
    try {
      final posts = await _repo.userPosts(userId, page: 1);
      emit(UserPostsFeedLoaded(
        posts: posts,
        nextPageToFetch: 2,
        hasMore: posts.length >= 20,
        loadingMore: false,
      ));
    } catch (e) {
      emit(UserPostsFeedFailure(e.toString()));
    }
  }

  Future<void> loadMore() async {
    final s = state;
    if (s is! UserPostsFeedLoaded || s.loadingMore || !s.hasMore) return;
    emit(UserPostsFeedLoaded(
      posts: s.posts,
      nextPageToFetch: s.nextPageToFetch,
      loadingMore: true,
      hasMore: s.hasMore,
    ));
    try {
      final next = await _repo.userPosts(userId, page: s.nextPageToFetch);
      if (next.isEmpty) {
        emit(UserPostsFeedLoaded(
          posts: s.posts,
          nextPageToFetch: s.nextPageToFetch,
          loadingMore: false,
          hasMore: false,
        ));
        return;
      }
      emit(UserPostsFeedLoaded(
        posts: [...s.posts, ...next],
        nextPageToFetch: s.nextPageToFetch + 1,
        loadingMore: false,
        hasMore: next.length >= 20,
      ));
    } catch (_) {
      emit(UserPostsFeedLoaded(
        posts: s.posts,
        nextPageToFetch: s.nextPageToFetch,
        loadingMore: false,
        hasMore: s.hasMore,
      ));
    }
  }

  Future<void> toggleLike(int postId) async {
    final s = state;
    if (s is! UserPostsFeedLoaded) return;
    final i = s.posts.indexWhere((p) => p.id == postId);
    if (i < 0) return;
    final p = s.posts[i];
    final nextLiked = !p.likedByViewer;
    final nextCount = p.likeCount + (nextLiked ? 1 : -1);
    final optimistic = p.copyWith(
      likedByViewer: nextLiked,
      likeCount: nextCount < 0 ? 0 : nextCount,
    );
    _replacePostAt(s, i, optimistic);
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
    if (s is! UserPostsFeedLoaded) return;
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

  void _replacePostAt(UserPostsFeedLoaded s, int index, SocialPost post) {
    final next = List<SocialPost>.from(s.posts);
    next[index] = post;
    emit(UserPostsFeedLoaded(
      posts: next,
      nextPageToFetch: s.nextPageToFetch,
      loadingMore: s.loadingMore,
      hasMore: s.hasMore,
    ));
  }

  void bumpCommentCount(int postId, {int delta = 1}) {
    final s = state;
    if (s is! UserPostsFeedLoaded) return;
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
    if (s is! UserPostsFeedLoaded) return;
    emit(UserPostsFeedLoaded(
      posts: s.posts.where((p) => p.id != postId).toList(),
      nextPageToFetch: s.nextPageToFetch,
      loadingMore: s.loadingMore,
      hasMore: s.hasMore,
    ));
  }
}
