import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/social_repository.dart';
import '../../domain/social_models.dart';

sealed class SocialCommentsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SocialCommentsInitial extends SocialCommentsState {}

class SocialCommentsLoading extends SocialCommentsState {}

class SocialCommentsReady extends SocialCommentsState {
  SocialCommentsReady({
    required this.comments,
    required this.page,
    this.commentsDone = false,
  });

  final List<SocialComment> comments;
  final int page;
  final bool commentsDone;

  SocialCommentsReady copyWith({
    List<SocialComment>? comments,
    int? page,
    bool? commentsDone,
  }) {
    return SocialCommentsReady(
      comments: comments ?? this.comments,
      page: page ?? this.page,
      commentsDone: commentsDone ?? this.commentsDone,
    );
  }

  @override
  List<Object?> get props => [comments, page, commentsDone];
}

class SocialCommentsFailure extends SocialCommentsState {
  SocialCommentsFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class SocialCommentsCubit extends Cubit<SocialCommentsState> {
  SocialCommentsCubit(this._repo, this.postId) : super(SocialCommentsInitial());

  final SocialRepository _repo;
  final int postId;

  Future<void> load() async {
    emit(SocialCommentsLoading());
    try {
      final comments = await _repo.listComments(postId, page: 1);
      emit(SocialCommentsReady(
        comments: comments,
        page: 1,
        commentsDone: comments.length < 30,
      ));
    } catch (e) {
      emit(SocialCommentsFailure(e.toString()));
    }
  }

  Future<void> loadMore() async {
    final s = state;
    if (s is! SocialCommentsReady || s.commentsDone) return;
    final next = await _repo.listComments(postId, page: s.page + 1);
    emit(s.copyWith(
      comments: [...s.comments, ...next],
      page: s.page + 1,
      commentsDone: next.length < 30,
    ));
  }

  Future<void> submitComment(String body) async {
    final s = state;
    if (s is! SocialCommentsReady) return;
    await _repo.addComment(postId, body);
    final comments = await _repo.listComments(postId, page: 1);
    emit(s.copyWith(
      comments: comments,
      page: 1,
      commentsDone: comments.length < 30,
    ));
  }

  Future<void> reportComment(int commentId) =>
      _repo.reportComment(commentId);
}
