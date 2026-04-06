import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/token_storage.dart';
import '../media_constants.dart';
import 'chat_remote_datasource.dart';
import 'chat_socket.dart';

/// Coordinates REST, WebSocket, and local Drift cache.
class ChatRepository {
  ChatRepository({
    required ChatRemoteDataSource remote,
    required AppDatabase db,
    required ChatSocket socket,
    TokenStorage? tokens,
  })  : _remote = remote,
        _db = db,
        _socket = socket,
        _tokens = tokens;

  final ChatRemoteDataSource _remote;
  final AppDatabase _db;
  final ChatSocket _socket;
  final TokenStorage? _tokens;

  ChatSocket get socket => _socket;

  AppDatabase get database => _db;

  /// Opens WebSocket using [TokenStorage] for fresh tokens on each connect/reconnect.
  void connectRealtime(String wsUrl) {
    final t = _tokens;
    if (t == null) return;
    _socket.connect(wsUrl, t.getAccessToken);
  }

  /// Returns the authenticated user's profile from `GET /v1/me`.
  /// Keys: id, email, display_name, created_at.
  Future<Map<String, dynamic>> fetchMe() => _remote.fetchMe();

  Future<void> enqueuePendingSend({
    required String localId,
    required int conversationId,
    required String body,
    int? replyToMessageId,
  }) async {
    await _db.into(_db.messageOutbox).insert(
          MessageOutboxCompanion.insert(
            localId: localId,
            conversationId: conversationId,
            body: body,
            replyToMessageId: Value(replyToMessageId),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> flushPendingSends(int conversationId) async {
    final rows = await (_db.select(_db.messageOutbox)
          ..where((t) => t.conversationId.equals(conversationId)))
        .get();
    for (final row in rows) {
      try {
        await _remote.sendMessage(
          conversationId,
          body: row.body,
          replyToMessageId: row.replyToMessageId,
        );
        await (_db.delete(_db.messageOutbox)..where((t) => t.localId.equals(row.localId))).go();
      } catch (_) {}
    }
  }

  /// Sends all queued outbox rows (any conversation). Call after reconnect / inbox refresh.
  Future<void> flushAllOutbox() async {
    final rows = await _db.select(_db.messageOutbox).get();
    for (final row in rows) {
      try {
        await _remote.sendMessage(
          row.conversationId,
          body: row.body,
          replyToMessageId: row.replyToMessageId,
        );
        await (_db.delete(_db.messageOutbox)..where((t) => t.localId.equals(row.localId))).go();
      } catch (_) {}
    }
  }

  Future<void> syncConversationsFromRemote() async {
    final data = await _remote.listConversations();
    final items = data['items'] as List<dynamic>? ?? [];
    await _db.batch((b) {
      for (final raw in items) {
        final m = raw as Map<String, dynamic>;
        final id = (m['id'] as num).toInt();
        final type = m['type'] as String? ?? 'private';
        final title = m['title'] as String?;
        String? peerJson;
        if (m['peer'] != null) {
          peerJson = jsonEncode(m['peer']);
        }
        b.insert(
          _db.localConversations,
          LocalConversationsCompanion.insert(
            id: Value(id),
            type: type,
            title: Value(title),
            peerJson: Value(peerJson),
            updatedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> cacheMessages(int conversationId, List<Map<String, dynamic>> items) async {
    await _db.batch((b) {
      for (final m in items) {
        final id = (m['id'] as num).toInt();
        final senderId = (m['sender_id'] as num).toInt();
        final body = m['body'] as String? ?? '';
        final ct = m['content_type'] as String? ?? 'text/plain';
        final reply = m['reply_to_message_id'];
        final created = DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now();
        DateTime? recDel;
        DateTime? recRead;
        final receipt = m['receipt'];
        if (receipt is Map<String, dynamic>) {
          recDel = DateTime.tryParse(receipt['delivered_at'] as String? ?? '');
          recRead = DateTime.tryParse(receipt['read_at'] as String? ?? '');
        }
        b.insert(
          _db.localMessages,
          LocalMessagesCompanion.insert(
            id: Value(id),
            conversationId: conversationId,
            senderId: senderId,
            body: body,
            contentType: Value(ct),
            replyToMessageId: Value(reply == null ? null : (reply as num).toInt()),
            createdAt: created,
            receiptDeliveredAt: Value(recDel),
            receiptReadAt: Value(recRead),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<List<LocalMessage>> loadMessagesLocal(int conversationId) {
    return (_db.select(_db.localMessages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<List<LocalConversation>> loadConversationsLocal() {
    return (_db.select(_db.localConversations)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// Cached `type` from last inbox sync (`private` / `group`), if known.
  Future<String?> conversationTypeLocal(int conversationId) async {
    final row = await (_db.select(_db.localConversations)
          ..where((t) => t.id.equals(conversationId)))
        .getSingleOrNull();
    return row?.type;
  }

  Future<Map<String, dynamic>> fetchMessages(int conversationId, {String? cursor}) =>
      _remote.listMessages(conversationId, cursor: cursor);

  Future<Map<String, dynamic>> fetchConversation(int conversationId) =>
      _remote.getConversation(conversationId);

  Future<Map<String, dynamic>> sendMessage(
    int conversationId, {
    required String body,
    int? replyToMessageId,
    String contentType = 'text/plain',
  }) =>
      _remote.sendMessage(
        conversationId,
        body: body,
        replyToMessageId: replyToMessageId,
        contentType: contentType,
      );

  Future<Map<String, dynamic>> editMessage(
    int conversationId,
    int messageId, {
    required String body,
  }) async {
    final m = await _remote.editMessage(conversationId, messageId, body: body);
    await cacheMessages(conversationId, [m]);
    return m;
  }

  Future<void> deleteMessage(
    int conversationId,
    int messageId, {
    String scope = 'for_me',
  }) async {
    await _remote.deleteMessage(conversationId, messageId, scope: scope);
    await (_db.delete(_db.localMessages)..where((t) => t.id.equals(messageId))).go();
  }

  Future<Map<String, dynamic>> getGroup(int conversationId) =>
      _remote.getGroup(conversationId);

  /// Presign → upload → optional complete (S3/GCS) → send `application/vnd.mamana.media+json` message.
  Future<Map<String, dynamic>> uploadAndSendMediaMessage({
    required int conversationId,
    required List<int> bytes,
    required String mimeType,
    required String kind,
    int? durationMs,
    int? replyToMessageId,
  }) async {
    final presign = await _remote.presignMedia(
      contentType: mimeType,
      byteSize: bytes.length,
      conversationId: conversationId,
    );
    final uploadUrl = presign['upload_url'] as String;
    final headers = Map<String, String>.from(
      (presign['headers'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ??
          const <String, String>{},
    );
    final objectKey = presign['object_key'] as String;
    final isLocal = presign.containsKey('upload_token');
    final access = isLocal ? await _tokens?.getAccessToken() : null;
    if (isLocal && (access == null || access.isEmpty)) {
      throw StateError('Not authenticated: cannot upload media');
    }
    await _remote.uploadMediaPut(
      uploadUrl: uploadUrl,
      headers: headers,
      bytes: bytes,
      bearerToken: access,
    );
    if (!isLocal) {
      await _remote.completeMediaUpload(objectKey: objectKey);
    }
    final body = jsonEncode({
      'object_key': objectKey,
      'mime': mimeType,
      'kind': kind,
      if (durationMs != null && durationMs > 0) 'duration_ms': durationMs,
    });
    final m = await sendMessage(
      conversationId,
      body: body,
      contentType: kMamanaMediaContentType,
      replyToMessageId: replyToMessageId,
    );
    await cacheMessages(conversationId, [m]);
    return m;
  }

  Future<void> markRead(int conversationId, int lastReadMessageId) =>
      _remote.markRead(conversationId, lastReadMessageId);

  Future<void> typing(int conversationId, bool typing) async {
    await _remote.sendTyping(conversationId, typing);
    _socket.sendTyping(conversationId, typing);
  }

  Future<Map<String, dynamic>> createDm(int peerUserId) => _remote.createPrivateDm(peerUserId);

  Future<Map<String, dynamic>> createGroup(String title, List<int> memberIds) =>
      _remote.createGroup(title: title, memberIds: memberIds);

  Future<void> registerPush({required String token, String platform = 'fcm'}) async {
    try {
      final deviceId = _tokens != null ? await _tokens.getOrCreateDeviceId() : null;
      await _remote.registerPushDevice(
        platform: platform,
        token: token,
        deviceId: deviceId,
      );
    } catch (_) {}
  }

  Future<void> blockUser(int userId) => _remote.blockUser(userId);

  Future<void> unblockUser(int userId) => _remote.unblockUser(userId);

  /// Returns users from `GET /v1/users/search` (id + display_name).
  Future<List<Map<String, dynamic>>> searchUsersDirectory(
    String q, {
    int limit = 20,
  }) async {
    final data = await _remote.searchUsers(q: q, limit: limit);
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // --- Public Groups ---

  Future<List<Map<String, dynamic>>> listPublicGroups({
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _remote.listPublicGroups(limit: limit, offset: offset);
    return (data['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<void> joinPublicGroup(int groupId) => _remote.joinPublicGroup(groupId);

  Future<void> leavePublicGroup(int groupId) => _remote.leavePublicGroup(groupId);
}
