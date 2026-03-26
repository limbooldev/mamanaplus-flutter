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

  Future<Map<String, dynamic>> listConversations() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/conversations');
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
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/conversations/$conversationId/messages',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> sendMessage(
    int conversationId, {
    required String body,
    int? replyToMessageId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/conversations/$conversationId/messages',
      data: {
        'body': body,
        if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      },
    );
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
}
