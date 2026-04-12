import 'dart:typed_data';

import 'package:dio/dio.dart';

/// REST calls matching [mamanaplus-backend/api/openapi.yaml].
class ChatRemoteDataSource {
  ChatRemoteDataSource(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/register',
      data: {
        'email': email,
        'password': password,
        'display_name': displayName,
      },
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/login',
      data: {'email': email, 'password': password},
    );
    return res.data!;
  }

  /// Returns the authenticated user's profile: id, email, display_name, created_at.
  Future<Map<String, dynamic>> fetchMe() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/me');
    return res.data!;
  }

  Future<Map<String, dynamic>> listConversations() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/conversations');
    return res.data!;
  }

  Future<Map<String, dynamic>> getConversation(int conversationId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/conversations/$conversationId',
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> createPrivateDm(int peerUserId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/conversations',
      data: {'peer_user_id': peerUserId},
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> listMessages(
    int conversationId, {
    String? cursor,
    int limit = 50,
    String? q,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/conversations/$conversationId/messages',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
        if (q != null && q.trim().length >= 2) 'q': q.trim(),
      },
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> listStickers() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/stickers');
    return res.data!;
  }

  Future<Map<String, dynamic>> sendMessage(
    int conversationId, {
    required String body,
    int? replyToMessageId,
    String contentType = 'text/plain',
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/conversations/$conversationId/messages',
      data: {
        'body': body,
        'content_type': contentType,
        if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      },
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> editMessage(
    int conversationId,
    int messageId, {
    required String body,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/v1/conversations/$conversationId/messages/$messageId',
      data: {'body': body},
    );
    return res.data!;
  }

  Future<void> deleteMessage(
    int conversationId,
    int messageId, {
    String scope = 'for_me',
  }) async {
    await _dio.delete<void>(
      '/v1/conversations/$conversationId/messages/$messageId',
      data: {'scope': scope},
    );
  }

  Future<Map<String, dynamic>> getGroup(int conversationId) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/groups/$conversationId');
    return res.data!;
  }

  /// `DELETE /v1/groups/{id}` — leave a group conversation.
  Future<void> leaveGroup(int conversationId) async {
    await _dio.delete<void>('/v1/groups/$conversationId');
  }

  Future<void> removeGroupMember(int groupId, int userId) async {
    await _dio.delete<void>(
      '/v1/groups/$groupId/members',
      queryParameters: {'user_id': userId},
    );
  }

  Future<void> banGroupMember(int groupId, int userId) async {
    await _dio.post<void>('/v1/groups/$groupId/members/$userId/ban');
  }

  Future<void> unbanGroupMember(int groupId, int userId) async {
    await _dio.delete<void>('/v1/groups/$groupId/members/$userId/ban');
  }

  Future<Map<String, dynamic>> listGroupBans(int groupId) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/groups/$groupId/bans');
    return res.data!;
  }

  Future<void> markRead(int conversationId, int lastReadMessageId) async {
    await _dio.post<void>(
      '/v1/conversations/$conversationId/read',
      data: {'last_read_message_id': lastReadMessageId},
    );
  }

  Future<void> sendTyping(int conversationId, bool typing) async {
    await _dio.post<void>(
      '/v1/conversations/$conversationId/typing',
      data: {'typing': typing},
    );
  }

  Future<void> blockUser(int userId) async {
    await _dio.post<void>('/v1/users/$userId/block');
  }

  Future<void> unblockUser(int userId) async {
    await _dio.delete<void>('/v1/users/$userId/block');
  }

  /// Directory search for pickers. Server requires [q] length ≥ 2 (after trim).
  Future<Map<String, dynamic>> searchUsers({
    required String q,
    int limit = 20,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/users/search',
      queryParameters: {'q': q, 'limit': limit},
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> createGroup({
    required String title,
    List<int> memberIds = const [],
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/groups',
      data: {'title': title, 'member_ids': memberIds},
    );
    return res.data!;
  }

  Future<void> registerPushDevice({
    required String platform,
    required String token,
    String? deviceId,
  }) async {
    await _dio.post<void>(
      '/v1/push/devices',
      data: {
        'platform': platform,
        'token': token,
        if (deviceId != null) 'device_id': deviceId,
      },
    );
  }

  // --- Public Groups ---

  Future<Map<String, dynamic>> listPublicGroups({
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/public-groups',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return res.data!;
  }

  Future<void> joinPublicGroup(int groupId) async {
    await _dio.post<void>('/v1/public-groups/$groupId/join');
  }

  Future<void> leavePublicGroup(int groupId) async {
    await _dio.delete<void>('/v1/public-groups/$groupId/leave');
  }

  Future<Map<String, dynamic>> presignMedia({
    required String contentType,
    required int byteSize,
    required int conversationId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/media/presign',
      data: {
        'content_type': contentType,
        'byte_size': byteSize,
        'conversation_id': conversationId,
      },
    );
    return res.data!;
  }

  /// PUT bytes to [uploadUrl] (S3/GCS presigned or local API upload URL).
  ///
  /// Uses a bare [Dio] so absolute S3/GCS URLs are not rewritten. For **local**
  /// storage the server requires [bearerToken] on `PUT /v1/media/upload/...`.
  /// Do not pass [bearerToken] for presigned cloud URLs (signature may not include it).
  Future<void> uploadMediaPut({
    required String uploadUrl,
    required Map<String, String> headers,
    required List<int> bytes,
    String? bearerToken,
  }) async {
    final dio = Dio(
      BaseOptions(
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
    final h = Map<String, String>.from(headers);
    final ct = h.remove('Content-Type') ?? h.remove('content-type');
    if (bearerToken != null && bearerToken.isNotEmpty) {
      h['Authorization'] = 'Bearer $bearerToken';
    }
    await dio.put<dynamic>(
      uploadUrl,
      data: Uint8List.fromList(bytes),
      options: Options(
        headers: h,
        contentType: ct,
      ),
    );
  }

  Future<void> completeMediaUpload({required String objectKey}) async {
    await _dio.post<void>(
      '/v1/media/complete',
      data: {'object_key': objectKey},
    );
  }
}
