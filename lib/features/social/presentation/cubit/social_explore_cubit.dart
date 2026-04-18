import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/social_repository.dart';
import '../../domain/social_models.dart';

sealed class SocialExploreState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SocialExploreInitial extends SocialExploreState {}

class SocialExploreLoading extends SocialExploreState {}

class SocialExploreLoaded extends SocialExploreState {
  SocialExploreLoaded({
    required this.posts,
    required this.page,
    this.loadingMore = false,
    this.hasMore = true,
  });

  final List<SocialPost> posts;
  final int page;
  final bool loadingMore;
  final bool hasMore;

  @override
  List<Object?> get props => [posts, page, loadingMore, hasMore];
}

class SocialExploreFailure extends SocialExploreState {
  SocialExploreFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class SocialExploreCubit extends Cubit<SocialExploreState> {
  SocialExploreCubit(this._repo) : super(SocialExploreInitial());

  final SocialRepository _repo;

  Future<void> refresh() async {
    emit(SocialExploreLoading());
    try {
      final posts = await _repo.explore(page: 1);
      emit(SocialExploreLoaded(
        posts: posts,
        page: 1,
        hasMore: posts.length >= 30,
      ));
    } catch (e) {
      emit(SocialExploreFailure(e.toString()));
    }
  }

  Future<void> loadMore() async {
    final s = state;
    if (s is! SocialExploreLoaded || s.loadingMore) return;
    emit(SocialExploreLoaded(
      posts: s.posts,
      page: s.page,
      loadingMore: true,
      hasMore: s.hasMore,
    ));
    try {
      final next = await _repo.explore(page: s.page + 1);
      if (next.isEmpty) {
        emit(SocialExploreLoaded(
          posts: s.posts,
          page: s.page,
          loadingMore: false,
          hasMore: false,
        ));
        return;
      }
      emit(SocialExploreLoaded(
        posts: [...s.posts, ...next],
        page: s.page + 1,
        loadingMore: false,
        hasMore: next.length >= 30,
      ));
    } catch (_) {
      emit(SocialExploreLoaded(
        posts: s.posts,
        page: s.page,
        loadingMore: false,
        hasMore: s.hasMore,
      ));
    }
  }
}
