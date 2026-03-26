import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import 'chat_remote_datasource.dart';
import 'chat_socket.dart';

/// Coordinates REST, WebSocket, and local Drift cache.
class ChatRepository {
  ChatRepository({
    required ChatRemoteDataSource remote,
    required AppDatabase db,
    required ChatSocket socket,
  })  : _remote = remote,
        _db = db,
        _socket = socket;

  final ChatRemoteDataSource _remote;
  final AppDatabase _db;
  final ChatSocket _socket;

  ChatSocket get socket => _socket;

  AppDatabase get database => _db;

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

  Future<Map<String, dynamic>> fetchMessages(int conversationId, {String? cursor}) =>
      _remote.listMessages(conversationId, cursor: cursor);

  Future<Map<String, dynamic>> sendMessage(
    int conversationId, {
    required String body,
    int? replyToMessageId,
  }) =>
      _remote.sendMessage(conversationId, body: body, replyToMessageId: replyToMessageId);

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
      await _remote.registerPushDevice(platform: platform, token: token);
    } catch (_) {}
  }

  Future<void> blockUser(int userId) => _remote.blockUser(userId);

  Future<void> unblockUser(int userId) => _remote.unblockUser(userId);
}
