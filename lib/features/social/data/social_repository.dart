import 'package:dio/dio.dart';

import '../domain/social_models.dart';

/// v1 social REST ([mamanaplus-backend] `/v1/social/*`, `/v1/users/*` social actions).
class SocialRepository {
  SocialRepository(this._dio);

  final Dio _dio;

  List<T> _items<T>(Map<String, dynamic> data, T Function(Map<String, dynamic>) f) {
    final raw = data['items'];
    if (raw is! List) return [];
    return raw.map((e) => f(e as Map<String, dynamic>)).toList();
  }

  Future<List<SocialPost>> feed({int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/social/feed',
      queryParameters: {'page': page},
    );
    return _items(res.data ?? {}, SocialPost.fromJson);
  }

  Future<List<SocialPost>> explore({int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/social/explore',
      queryParameters: {'page': page},
    );
    return _items(res.data ?? {}, SocialPost.fromJson);
  }

  Future<SocialPost> getPost(int id) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/social/posts/$id');
    return SocialPost.fromJson(res.data!);
  }

  Future<List<SocialComment>> listComments(int postId, {int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/social/posts/$postId/comments',
      queryParameters: {'page': page},
    );
    return _items(res.data ?? {}, SocialComment.fromJson);
  }

  Future<int> addComment(int postId, String body, {int? parentId}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/social/posts/$postId/comments',
      data: {'body': body, if (parentId != null) 'parent_id': parentId},
    );
    return (res.data?['id'] as num).toInt();
  }

  Future<void> likePost(int postId) =>
      _dio.post<void>('/v1/social/posts/$postId/like');

  Future<void> unlikePost(int postId) =>
      _dio.delete<void>('/v1/social/posts/$postId/like');

  Future<void> bookmarkPost(int postId) =>
      _dio.post<void>('/v1/social/posts/$postId/bookmark');

  Future<void> unbookmarkPost(int postId) =>
      _dio.delete<void>('/v1/social/posts/$postId/bookmark');

  Future<void> reportPost(int postId) =>
      _dio.post<void>('/v1/social/posts/$postId/report');

  Future<void> reportComment(int commentId) => _dio.post<void>(
        '/v1/social/comments/$commentId/report',
      );

  Future<List<SocialUserBrief>> postLikers(int postId, {int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/social/posts/$postId/likes',
      queryParameters: {'page': page},
    );
    return _items(res.data ?? {}, SocialUserBrief.fromJson);
  }

  Future<void> followUser(int userId) =>
      _dio.post<void>('/v1/users/$userId/follow');

  Future<void> unfollowUser(int userId) =>
      _dio.delete<void>('/v1/users/$userId/follow');

  Future<bool> followStatus(int userId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/users/$userId/follow-status',
    );
    return res.data?['following'] == true;
  }

  Future<List<SocialUserBrief>> followers(int userId, {int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/users/$userId/followers',
      queryParameters: {'page': page},
    );
    return _items(res.data ?? {}, SocialUserBrief.fromJson);
  }

  Future<List<SocialUserBrief>> following(int userId, {int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/users/$userId/following',
      queryParameters: {'page': page},
    );
    return _items(res.data ?? {}, SocialUserBrief.fromJson);
  }

  Future<List<SocialUserBrief>> discoveryTop({int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/social/discovery/top',
      queryParameters: {'page': page},
    );
    return _items(res.data ?? {}, SocialUserBrief.fromJson);
  }

  Future<List<SocialUserBrief>> discoveryLatest({int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/social/discovery/latest',
      queryParameters: {'page': page},
    );
    return _items(res.data ?? {}, SocialUserBrief.fromJson);
  }

  Future<void> hideUserContent(int userId) =>
      _dio.post<void>('/v1/users/$userId/hide-content');

  Future<void> unhideUserContent(int userId) =>
      _dio.delete<void>('/v1/users/$userId/hide-content');

  Future<List<SocialUserBrief>> hiddenUsers({int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/social/hidden-users',
      queryParameters: {'page': page},
    );
    return _items(res.data ?? {}, SocialUserBrief.fromJson);
  }

  Future<void> approveUserProfile(int userId) =>
      _dio.post<void>('/v1/users/$userId/approve-profile');

  Future<int> createPost({
    required String title,
    required String content,
    required String postType,
    String? mediaUrl,
    String? thumbnailUrl,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/social/posts',
      data: {
        'title': title,
        'content': content,
        'post_type': postType,
        if (mediaUrl != null && mediaUrl.isNotEmpty) 'media_url': mediaUrl,
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
          'thumbnail_url': thumbnailUrl,
      },
    );
    return (res.data?['id'] as num).toInt();
  }

  Future<void> updatePost(
    int id, {
    required String title,
    required String content,
    required String postType,
    String? mediaUrl,
    String? thumbnailUrl,
  }) =>
      _dio.put<void>(
        '/v1/social/posts/$id',
        data: {
          'title': title,
          'content': content,
          'post_type': postType,
          if (mediaUrl != null) 'media_url': mediaUrl,
          if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
        },
      );

  Future<void> deletePost(int id) => _dio.delete<void>('/v1/social/posts/$id');

  Future<List<StoryRing>> listStoryRings() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/social/stories');
    return _items(res.data ?? {}, StoryRing.fromJson);
  }

  Future<List<StoryMedia>> listStoryMedia(int storyId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/social/stories/$storyId/media',
    );
    return _items(res.data ?? {}, StoryMedia.fromJson);
  }

  Future<Map<String, int>> addStoryMedia(String mediaUrl) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/social/stories/media',
      data: {'media_url': mediaUrl},
    );
    return {
      'story_id': (res.data?['story_id'] as num).toInt(),
      'media_id': (res.data?['media_id'] as num).toInt(),
    };
  }

  Future<void> deleteStoryMedia(int mediaId) =>
      _dio.delete<void>('/v1/social/stories/media/$mediaId');

  Future<void> markStorySeen(List<int> mediaIds) => _dio.post<void>(
        '/v1/social/stories/seen',
        data: {'media_ids': mediaIds},
      );

  Future<void> reportStory(int storyId) => _dio.post<void>(
        '/v1/social/stories/report',
        data: {'story_id': storyId},
      );
}
