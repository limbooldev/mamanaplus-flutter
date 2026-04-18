import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/social_repository.dart';
import '../../domain/social_models.dart';

sealed class SocialFeedState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SocialFeedInitial extends SocialFeedState {}

class SocialFeedLoading extends SocialFeedState {}

class SocialFeedLoaded extends SocialFeedState {
  SocialFeedLoaded({
    required this.posts,
    required this.stories,
    required this.page,
    this.loadingMore = false,
    this.hasMore = true,
  });

  final List<SocialPost> posts;
  final List<StoryRing> stories;
  final int page;
  final bool loadingMore;
  final bool hasMore;

  @override
  List<Object?> get props => [posts, stories, page, loadingMore, hasMore];
}

class SocialFeedFailure extends SocialFeedState {
  SocialFeedFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class SocialFeedCubit extends Cubit<SocialFeedState> {
  SocialFeedCubit(this._repo) : super(SocialFeedInitial());

  final SocialRepository _repo;

  Future<void> refresh() async {
    emit(SocialFeedLoading());
    try {
      final posts = await _repo.feed(page: 1);
      final stories = await _repo.listStoryRings();
      emit(SocialFeedLoaded(
        posts: posts,
        stories: stories,
        page: 1,
        hasMore: posts.length >= 20,
      ));
    } catch (e) {
      emit(SocialFeedFailure(e.toString()));
    }
  }

  Future<void> loadMore() async {
    final s = state;
    if (s is! SocialFeedLoaded || s.loadingMore) return;
    emit(SocialFeedLoaded(
      posts: s.posts,
      stories: s.stories,
      page: s.page,
      loadingMore: true,
      hasMore: s.hasMore,
    ));
    try {
      final next = await _repo.feed(page: s.page + 1);
      if (next.isEmpty) {
        emit(SocialFeedLoaded(
          posts: s.posts,
          stories: s.stories,
          page: s.page,
          loadingMore: false,
          hasMore: false,
        ));
        return;
      }
      emit(SocialFeedLoaded(
        posts: [...s.posts, ...next],
        stories: s.stories,
        page: s.page + 1,
        loadingMore: false,
        hasMore: next.length >= 20,
      ));
    } catch (e) {
      emit(SocialFeedLoaded(
        posts: s.posts,
        stories: s.stories,
        page: s.page,
        loadingMore: false,
        hasMore: s.hasMore,
      ));
    }
  }

  /// Optimistic like toggle; reverts post in list on API failure.
  Future<void> toggleLike(int postId) async {
    final s = state;
    if (s is! SocialFeedLoaded) return;
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

  /// Optimistic bookmark toggle; reverts on failure.
  Future<void> toggleBookmark(int postId) async {
    final s = state;
    if (s is! SocialFeedLoaded) return;
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

  void _replacePostAt(SocialFeedLoaded s, int index, SocialPost post) {
    final next = List<SocialPost>.from(s.posts);
    next[index] = post;
    emit(SocialFeedLoaded(
      posts: next,
      stories: s.stories,
      page: s.page,
      loadingMore: s.loadingMore,
      hasMore: s.hasMore,
    ));
  }
}
