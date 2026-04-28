import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/social_repository.dart';
import '../../domain/social_models.dart';

sealed class SocialPostState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SocialPostInitial extends SocialPostState {}

class SocialPostLoading extends SocialPostState {}

class SocialPostReady extends SocialPostState {
  SocialPostReady({
    required this.post,
    required this.comments,
    required this.commentPage,
    this.commentsDone = false,
    this.likers = const [],
  });

  final SocialPost post;
  final List<SocialComment> comments;
  final int commentPage;
  final bool commentsDone;
  final List<SocialUserBrief> likers;

  SocialPostReady copyWith({
    SocialPost? post,
    List<SocialComment>? comments,
    int? commentPage,
    bool? commentsDone,
    List<SocialUserBrief>? likers,
  }) {
    return SocialPostReady(
      post: post ?? this.post,
      comments: comments ?? this.comments,
      commentPage: commentPage ?? this.commentPage,
      commentsDone: commentsDone ?? this.commentsDone,
      likers: likers ?? this.likers,
    );
  }

  @override
  List<Object?> get props =>
      [post, comments, commentPage, commentsDone, likers];
}

class SocialPostFailure extends SocialPostState {
  SocialPostFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class SocialPostCubit extends Cubit<SocialPostState> {
  SocialPostCubit(this._repo, this.postId) : super(SocialPostInitial()) {
    load();
  }

  final SocialRepository _repo;
  final int postId;

  Future<void> load() async {
    emit(SocialPostLoading());
    try {
      final post = await _repo.getPost(postId);
      final comments = await _repo.listComments(postId, page: 1);
      emit(SocialPostReady(
        post: post,
        comments: comments,
        commentPage: 1,
        commentsDone: comments.length < 30,
      ));
    } catch (e) {
      emit(SocialPostFailure(e.toString()));
    }
  }

  Future<void> loadMoreComments() async {
    final s = state;
    if (s is! SocialPostReady || s.commentsDone) return;
    final next = await _repo.listComments(postId, page: s.commentPage + 1);
    emit(s.copyWith(
      comments: [...s.comments, ...next],
      commentPage: s.commentPage + 1,
      commentsDone: next.length < 30,
    ));
  }

  Future<void> toggleLike() async {
    final s = state;
    if (s is! SocialPostReady) return;
    final p = s.post;
    try {
      if (p.likedByViewer) {
        await _repo.unlikePost(postId);
        emit(s.copyWith(
          post: SocialPost(
            id: p.id,
            authorId: p.authorId,
            authorName: p.authorName,
            title: p.title,
            content: p.content,
            postType: p.postType,
            mediaUrl: p.mediaUrl,
            thumbnailUrl: p.thumbnailUrl,
            likeCount: (p.likeCount - 1).clamp(0, 1 << 30),
            commentCount: p.commentCount,
            likedByViewer: false,
            bookmarked: p.bookmarked,
            createdAt: p.createdAt,
          ),
        ));
      } else {
        await _repo.likePost(postId);
        emit(s.copyWith(
          post: SocialPost(
            id: p.id,
            authorId: p.authorId,
            authorName: p.authorName,
            title: p.title,
            content: p.content,
            postType: p.postType,
            mediaUrl: p.mediaUrl,
            thumbnailUrl: p.thumbnailUrl,
            likeCount: p.likeCount + 1,
            commentCount: p.commentCount,
            likedByViewer: true,
            bookmarked: p.bookmarked,
            createdAt: p.createdAt,
          ),
        ));
      }
    } catch (_) {
      await load();
    }
  }

  Future<void> toggleBookmark() async {
    final s = state;
    if (s is! SocialPostReady) return;
    final p = s.post;
    try {
      if (p.bookmarked) {
        await _repo.unbookmarkPost(postId);
      } else {
        await _repo.bookmarkPost(postId);
      }
      emit(s.copyWith(
        post: SocialPost(
          id: p.id,
          authorId: p.authorId,
          authorName: p.authorName,
          title: p.title,
          content: p.content,
          postType: p.postType,
          mediaUrl: p.mediaUrl,
          thumbnailUrl: p.thumbnailUrl,
          likeCount: p.likeCount,
          commentCount: p.commentCount,
          likedByViewer: p.likedByViewer,
          bookmarked: !p.bookmarked,
          createdAt: p.createdAt,
        ),
      ));
    } catch (_) {
      await load();
    }
  }

  Future<void> submitComment(String body, {int? parentId}) async {
    final s = state;
    if (s is! SocialPostReady) return;
    await _repo.addComment(postId, body, parentId: parentId);
    final comments = await _repo.listComments(postId, page: 1);
    final post = await _repo.getPost(postId);
    emit(s.copyWith(comments: comments, post: post, commentPage: 1, commentsDone: comments.length < 30));
  }

  Future<void> loadLikers() async {
    final s = state;
    if (s is! SocialPostReady) return;
    final likers = await _repo.postLikers(postId, page: 1);
    emit(s.copyWith(likers: likers));
  }

  Future<void> reportPost() => _repo.reportPost(postId);

  Future<void> reportComment(int commentId) =>
      _repo.reportComment(commentId);
}
