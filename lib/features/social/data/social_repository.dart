import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../chat/data/chat_remote_datasource.dart';
import '../../../core/jwt_util.dart';
import '../../../core/media/media_upload_processor.dart';
import '../../../core/token_storage.dart';
import '../domain/social_models.dart';

/// v1 social REST ([mamanaplus-backend] `/v1/social/*`, `/v1/users/*` social actions).
class SocialRepository {
  SocialRepository(
    this._dio, {
    required ChatRemoteDataSource mediaApi,
    required TokenStorage tokens,
  })  : _mediaApi = mediaApi,
        _tokens = tokens;

  final Dio _dio;
  final ChatRemoteDataSource _mediaApi;
  final TokenStorage _tokens;

  /// Decodes `sub` from the current access token (UI / ordering only).
  Future<int?> currentUserId() async {
    final t = await _tokens.getAccessToken();
    if (t == null || t.isEmpty) return null;
    return parseUserIdFromAccessToken(t);
  }

  /// Same pipeline as chat: presign → PUT (local needs Bearer) → complete for S3/GCS.
  /// Returns [object_key] to store as `media_url` on the post.
  Future<String> uploadSocialMediaBytes(
    List<int> bytes,
    String contentType, {
    int? durationMs,
  }) async {
    final isVideo = MediaUploadProcessor.isVideoMime(contentType);
    late final String uploadMime;
    late final List<int> uploadBytes;

    if (isVideo) {
      uploadMime = contentType;
      uploadBytes = bytes;
    } else {
      final compressed = await MediaUploadProcessor.compressImageBytes(
        bytes,
        mimeType: contentType,
      );
      uploadMime = MediaUploadProcessor.isCompressibleImageMime(contentType)
          ? compressed.mimeType
          : contentType;
      uploadBytes = MediaUploadProcessor.isCompressibleImageMime(contentType)
          ? compressed.bytes
          : bytes;
    }

    final presign = await _mediaApi.presignMedia(
      contentType: uploadMime,
      byteSize: uploadBytes.length,
      purpose: 'social',
      durationMs: isVideo ? durationMs : null,
    );
    final uploadUrl = presign['upload_url'] as String;
    final headers = Map<String, String>.from(
      (presign['headers'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ??
          const <String, String>{},
    );
    final objectKey = presign['object_key'] as String;
    final isLocal = presign.containsKey('upload_token');
    final access = isLocal ? await _tokens.getAccessToken() : null;
    if (isLocal && (access == null || access.isEmpty)) {
      throw StateError('Not authenticated: cannot upload media');
    }
    await _mediaApi.uploadMediaPut(
      uploadUrl: uploadUrl,
      headers: headers,
      bytes: uploadBytes,
      bearerToken: access,
    );
    if (!isLocal) {
      await _mediaApi.completeMediaUpload(objectKey: objectKey);
    }
    return objectKey;
  }

  /// Compresses, uploads, and attaches a story video slide (max 15s).
  Future<Map<String, int>> uploadStoryVideoFromPath(String path) async {
    final processed = await MediaUploadProcessor.compressVideoForStoryUpload(path);
    final thumbFile = await MediaUploadProcessor.storyVideoThumbnailFile(
      processed.path,
    );
    final thumbBytes = await thumbFile.readAsBytes();
    final thumbKey = await uploadSocialMediaBytes(thumbBytes, 'image/jpeg');
    final bytes = await File(processed.path).readAsBytes();
    final key = await uploadSocialMediaBytes(
      bytes,
      processed.mimeType,
      durationMs: processed.durationMs,
    );
    return addStoryMedia(
      key,
      contentType: processed.mimeType,
      thumbnailUrl: thumbKey,
    );
  }

  /// Uploads a story image slide from a local file path.
  Future<Map<String, int>> uploadStoryImageFromPath(String path) async {
    final bytes = await File(path).readAsBytes();
    final mime = lookupMimeType(path) ?? 'image/jpeg';
    final key = await uploadSocialMediaBytes(bytes, mime);
    return addStoryMedia(key, contentType: mime);
  }

  /// Downloads a media object to the temp cache dir, reusing an existing file when present.
  /// Uses the same `media_cache` folder as chat so object keys are shared on disk.
  Future<File> downloadImageToCache(String objectKey) async {
    final ext = p.extension(objectKey);
    final fallback = ext.isNotEmpty ? ext.replaceFirst('.', '') : 'jpg';
    return downloadMediaToCache(objectKey, fallbackExtension: fallback);
  }

  Future<File> downloadMediaToCache(
    String objectKey, {
    required String fallbackExtension,
  }) async {
    final root = await getTemporaryDirectory();
    final dir = Directory(p.join(root.path, 'media_cache'));
    await dir.create(recursive: true);
    final ext = p.extension(objectKey);
    final suffix = ext.isNotEmpty ? ext : '.$fallbackExtension';
    final safe = objectKey.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File(p.join(dir.path, '$safe$suffix'));
    if (file.existsSync() && file.lengthSync() > 0) {
      return file;
    }
    final bytes = await _mediaApi.downloadMediaBytes(objectKey: objectKey);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  List<T> _items<T>(Map<String, dynamic> data, T Function(Map<String, dynamic>) f) {
    final raw = data['items'];
    if (raw is! List) return [];
    return raw.map((e) => f(e as Map<String, dynamic>)).toList();
  }

  Future<UserProfile> userProfile(int userId) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/users/$userId/profile');
    return UserProfile.fromJson(res.data!);
  }

  Future<List<SocialPost>> userPosts(int userId, {int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/users/$userId/posts',
      queryParameters: {'page': page},
    );
    return _items(res.data ?? {}, SocialPost.fromJson);
  }

  Future<void> reportUser(int userId, {String? reason}) async {
    await _dio.post<void>(
      '/v1/users/$userId/report',
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  /// Updates the signed-in user (`PATCH /v1/me`). Returns the updated profile map.
  Future<Map<String, dynamic>> patchMe({
    String? displayName,
    String? bio,
    String? avatarMediaKey,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['display_name'] = displayName;
    if (bio != null) body['bio'] = bio;
    if (avatarMediaKey != null) body['avatar_media_key'] = avatarMediaKey;
    final res = await _dio.patch<Map<String, dynamic>>('/v1/me', data: body);
    return res.data!;
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
    String title = '',
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
    String title = '',
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

  Future<Map<String, int>> addStoryMedia(
    String mediaUrl, {
    String contentType = 'image/jpeg',
    String? thumbnailUrl,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/social/stories/media',
      data: {
        'media_url': mediaUrl,
        'content_type': contentType,
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
          'thumbnail_url': thumbnailUrl,
      },
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

  /// Owner-only: viewers of one slide.
  Future<List<StoryMediaViewer>> listStoryMediaViewers({
    required int storyId,
    required int mediaId,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/social/stories/$storyId/media/$mediaId/viewers',
    );
    return _items(res.data ?? {}, StoryMediaViewer.fromJson);
  }

  /// Returns max allowed slides when server responds with `story_media_limit`.
  int? parseStoryMediaLimitError(Object e) {
    if (e is! DioException) return null;
    final data = e.response?.data;
    if (data is Map && data['error'] == 'story_media_limit') {
      return (data['max'] as num?)?.toInt();
    }
    return null;
  }
}
