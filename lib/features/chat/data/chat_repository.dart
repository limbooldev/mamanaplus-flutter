import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/api_config.dart';
import '../../../core/database/app_database.dart';
import '../../../core/token_refresh.dart';
import '../../../core/token_storage.dart';
import '../conversation_preview.dart';
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
    ApiConfig? config,
    void Function(String accessToken)? onAccessTokenRefreshed,
  }) : _remote = remote,
       _db = db,
       _socket = socket,
       _tokens = tokens,
       _config = config,
       _onAccessTokenRefreshed = onAccessTokenRefreshed {
    _reconnectSub = _socket.connected.listen((_) {
      unawaited(flushAllOutbox());
    });
  }

  final ChatRemoteDataSource _remote;
  final AppDatabase _db;
  final ChatSocket _socket;
  final TokenStorage? _tokens;
  final ApiConfig? _config;
  final void Function(String accessToken)? _onAccessTokenRefreshed;

  /// Pokes a `conversationId` whenever a row in [MessageOutbox] is inserted,
  /// updated, or removed. Cubits subscribe to drive optimistic UI updates.
  final StreamController<int> _outboxChangesCtrl =
      StreamController<int>.broadcast();

  Stream<int> get outboxChangedFor => _outboxChangesCtrl.stream;

  /// Prevents the same outbox row from being delivered twice when reconnect
  /// triggers concurrent flushes and an in-flight optimistic send overlaps.
  final Set<String> _outboxSendInFlight = {};

  StreamSubscription<void>? _reconnectSub;

  ChatSocket get socket => _socket;

  AppDatabase get database => _db;

  /// Latest access token from secure storage (for media that must not use a stale snapshot).
  Future<String?> getFreshAccessToken() async {
    final t = _tokens;
    if (t == null) return null;
    return t.getAccessToken();
  }

  /// Opens WebSocket using [TokenStorage]; refresh via Dio on demand.
  void connectRealtime(Uri wsUri) {
    final t = _tokens;
    if (t == null) return;
    final cfg = _config;
    _socket.connect(wsUri, ({bool forceRefresh = false}) async {
      if (forceRefresh && cfg != null) {
        await refreshAccessToken(
          config: cfg,
          tokens: t,
          onAccessTokenRefreshed: _onAccessTokenRefreshed,
        );
      }
      return t.getAccessToken();
    });
  }

  /// After Dio rotates the access token without a full reconnect.
  void notifyRealtimeTokenRotated() => _socket.notifyTokenRotated();

  /// Returns the authenticated user's profile from `GET /v1/me`.
  /// Keys: id, email, display_name, created_at.
  Future<Map<String, dynamic>> fetchMe() => _remote.fetchMe();

  /// Inserts a text/sticker outbox row. Used by [sendTextOptimistic] and the
  /// existing offline-fallback path on the cubit.
  Future<void> enqueuePendingSend({
    required String localId,
    required int conversationId,
    required String body,
    int? replyToMessageId,
    String contentType = 'text/plain',
    int? storyMediaId,
  }) async {
    await _db
        .into(_db.messageOutbox)
        .insert(
          MessageOutboxCompanion.insert(
            localId: localId,
            conversationId: conversationId,
            body: body,
            replyToMessageId: Value(replyToMessageId),
            createdAt: DateTime.now(),
            contentType: Value(contentType),
            storyMediaId: Value(storyMediaId),
          ),
        );
    _outboxChangesCtrl.add(conversationId);
  }

  /// Inserts a media outbox row carrying the local file path. The body stays
  /// empty until the upload completes and the media JSON is built.
  Future<void> enqueuePendingMediaSend({
    required String localId,
    required int conversationId,
    required String mediaPath,
    required String mediaMime,
    required String mediaKind,
    int? mediaDurationMs,
    int? replyToMessageId,
    String? caption,
  }) async {
    await _db
        .into(_db.messageOutbox)
        .insert(
          MessageOutboxCompanion.insert(
            localId: localId,
            conversationId: conversationId,
            body: '',
            replyToMessageId: Value(replyToMessageId),
            createdAt: DateTime.now(),
            contentType: const Value(kMamanaMediaContentType),
            mediaPath: Value(mediaPath),
            mediaMime: Value(mediaMime),
            mediaKind: Value(mediaKind),
            mediaDurationMs: Value(mediaDurationMs),
            mediaCaption: Value(caption),
          ),
        );
    _outboxChangesCtrl.add(conversationId);
  }

  /// Loads pending rows for [conversationId], oldest first.
  Future<List<MessageOutboxData>> loadOutboxLocal(int conversationId) {
    return (_db.select(_db.messageOutbox)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Optimistic text/sticker send. Inserts the outbox row first so the bubble
  /// appears with a clock icon, then attempts the REST call. On success the
  /// row is replaced by a [LocalMessage]; on failure it stays for later flush.
  Future<void> sendTextOptimistic({
    required String localId,
    required int conversationId,
    required String body,
    int? replyToMessageId,
    String contentType = 'text/plain',
    int? storyMediaId,
  }) async {
    await enqueuePendingSend(
      localId: localId,
      conversationId: conversationId,
      body: body,
      replyToMessageId: replyToMessageId,
      contentType: contentType,
      storyMediaId: storyMediaId,
    );
    final row = await _loadOutboxRow(localId);
    if (row != null) await _deliverOutboxRow(row);
  }

  /// Optimistic media send. Inserts the outbox row first (renders the bubble
  /// with the local file under a clock icon), then runs the existing
  /// presign + PUT + send chain. The row is removed on success.
  Future<void> sendMediaOptimistic({
    required String localId,
    required int conversationId,
    required String path,
    required String mime,
    required String kind,
    int? durationMs,
    int? replyToMessageId,
    String? caption,
  }) async {
    await enqueuePendingMediaSend(
      localId: localId,
      conversationId: conversationId,
      mediaPath: path,
      mediaMime: mime,
      mediaKind: kind,
      mediaDurationMs: durationMs,
      replyToMessageId: replyToMessageId,
      caption: caption,
    );
    final row = await _loadOutboxRow(localId);
    if (row != null) await _deliverOutboxRow(row);
  }

  Future<void> _deleteOutbox(String localId, int conversationId) async {
    await (_db.delete(
      _db.messageOutbox,
    )..where((t) => t.localId.equals(localId))).go();
    _outboxChangesCtrl.add(conversationId);
  }

  /// Removes a queued outbox row (e.g. user cancels an unsent message offline).
  Future<void> cancelPendingSend({
    required String localId,
    required int conversationId,
  }) async {
    final row = await (_db.select(_db.messageOutbox)
          ..where((t) => t.localId.equals(localId)))
        .getSingleOrNull();
    if (row == null) return;
    final mediaPath = row.mediaPath;
    await _deleteOutbox(localId, conversationId);
    if (mediaPath != null && mediaPath.isNotEmpty) {
      try {
        final file = File(mediaPath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  Future<void> _markOutboxFailed(String localId, int conversationId) async {
    final row = await (_db.select(_db.messageOutbox)
          ..where((t) => t.localId.equals(localId)))
        .getSingleOrNull();
    if (row == null) return;
    await (_db.update(_db.messageOutbox)
          ..where((t) => t.localId.equals(localId)))
        .write(MessageOutboxCompanion(
      attempts: Value(row.attempts + 1),
      lastErrorAt: Value(DateTime.now()),
    ));
    _outboxChangesCtrl.add(conversationId);
  }

  /// Updates the per-message `delivered_at` from a `receipt_update` WS event.
  /// Preserves all other fields (avoids the `insertOrReplace` null overwrite
  /// that [cacheMessages] would do).
  Future<void> applyDeliveredReceipt({
    required int conversationId,
    required int messageId,
    required DateTime deliveredAt,
  }) async {
    await (_db.update(_db.localMessages)
          ..where((t) => t.id.equals(messageId)))
        .write(LocalMessagesCompanion(
      receiptDeliveredAt: Value(deliveredAt),
    ));
  }

  /// Updates per-message `read_at` from a `receipt_update` WS event.
  Future<void> applyReadReceipt({
    required int conversationId,
    required int messageId,
    required DateTime readAt,
  }) async {
    await (_db.update(_db.localMessages)
          ..where((t) => t.id.equals(messageId)))
        .write(LocalMessagesCompanion(
      receiptReadAt: Value(readAt),
    ));
  }

  Future<void> flushPendingSends(int conversationId) async {
    final rows = await (_db.select(
      _db.messageOutbox,
    )..where((t) => t.conversationId.equals(conversationId))).get();
    for (final row in rows) {
      await _deliverOutboxRow(row);
    }
  }

  /// Sends all queued outbox rows (any conversation). Call after reconnect / inbox refresh.
  Future<void> flushAllOutbox() async {
    final rows = await _db.select(_db.messageOutbox).get();
    for (final row in rows) {
      await _deliverOutboxRow(row);
    }
  }

  Future<MessageOutboxData?> _loadOutboxRow(String localId) {
    return (_db.select(_db.messageOutbox)
          ..where((t) => t.localId.equals(localId)))
        .getSingleOrNull();
  }

  bool _tryBeginOutboxSend(String localId) {
    if (_outboxSendInFlight.contains(localId)) return false;
    _outboxSendInFlight.add(localId);
    return true;
  }

  void _endOutboxSend(String localId) {
    _outboxSendInFlight.remove(localId);
  }

  /// Single delivery path for optimistic sends and reconnect flushes.
  Future<void> _deliverOutboxRow(MessageOutboxData row) async {
    if (!_tryBeginOutboxSend(row.localId)) return;
    try {
      final current = await _loadOutboxRow(row.localId);
      if (current == null) return;

      final isMedia =
          current.mediaPath != null && current.mediaPath!.isNotEmpty;
      if (isMedia) {
        final file = File(current.mediaPath!);
        if (!file.existsSync()) {
          // Media file is gone (e.g. cache cleared); drop the row to avoid an
          // unending retry loop.
          await _deleteOutbox(current.localId, current.conversationId);
          return;
        }
        final bytes = await file.readAsBytes();
        await _uploadAndSendMediaFromBytes(
          conversationId: current.conversationId,
          bytes: bytes,
          mimeType: current.mediaMime ?? 'application/octet-stream',
          kind: current.mediaKind ?? 'image',
          durationMs: current.mediaDurationMs,
          replyToMessageId: current.replyToMessageId,
          caption: current.mediaCaption,
        );
      } else {
        final m = await _remote.sendMessage(
          current.conversationId,
          body: current.body,
          replyToMessageId: current.replyToMessageId,
          storyMediaId: current.storyMediaId,
          contentType: current.contentType,
        );
        await cacheMessages(current.conversationId, [m]);
      }
      await _deleteOutbox(current.localId, current.conversationId);
    } catch (_) {
      await _markOutboxFailed(row.localId, row.conversationId);
    } finally {
      _endOutboxSend(row.localId);
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
        final preview = decodeConversationListPreview(
          m['last_message_preview'] as String?,
        );
        final previewText = encodeConversationListPreview(preview);
        final lastAtRaw = m['last_message_at'] as String?;
        final lastAt = DateTime.tryParse(lastAtRaw ?? '');
        final unread = _parseUnreadCount(m);
        b.insert(
          _db.localConversations,
          LocalConversationsCompanion.insert(
            id: Value(id),
            type: type,
            title: Value(title),
            peerJson: Value(peerJson),
            lastMessagePreview: Value(previewText.isEmpty ? null : previewText),
            lastMessageAt: Value(lastAt),
            unreadCount: Value(unread),
            updatedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
    await _reconcileConversationPreviewsFromLocalMessages();
  }

  Future<void> cacheMessages(
    int conversationId,
    List<Map<String, dynamic>> items,
  ) async {
    if (items.isEmpty) return;
    // Read existing rows so we can preserve newer receipt timestamps if the
    // incoming payload is missing them. Without this, an `insertOrReplace`
    // arriving from `POST /messages` (no receipt block) would clobber a
    // `delivered_at`/`read_at` that previously arrived via WS receipt_update.
    final ids = items
        .map((m) => (m['id'] as num).toInt())
        .toList(growable: false);
    final existing = await (_db.select(_db.localMessages)
          ..where((t) => t.id.isIn(ids)))
        .get();
    final existingById = {for (final row in existing) row.id: row};

    await _db.batch((b) {
      for (final m in items) {
        final id = (m['id'] as num).toInt();
        final senderId = (m['sender_id'] as num).toInt();
        final body = m['body'] as String? ?? '';
        final ct = normalizeContentType(m['content_type'] as String?);
        final reply = m['reply_to_message_id'];
        final storyMid = m['story_media_id'];
        final created =
            DateTime.tryParse(m['created_at'] as String? ?? '') ??
            DateTime.now();
        DateTime? editedAt =
            DateTime.tryParse(m['edited_at'] as String? ?? '');
        DateTime? recDel;
        DateTime? recRead;
        final receipt = m['receipt'];
        if (receipt is Map<String, dynamic>) {
          recDel = DateTime.tryParse(receipt['delivered_at'] as String? ?? '');
          recRead = DateTime.tryParse(receipt['read_at'] as String? ?? '');
        }
        // Preserve existing receipt timestamps when the new payload omits them
        // or carries an older value.
        final prev = existingById[id];
        if (prev != null) {
          editedAt ??= prev.editedAt;
          if (recDel == null ||
              (prev.receiptDeliveredAt != null &&
                  prev.receiptDeliveredAt!.isAfter(recDel))) {
            recDel = prev.receiptDeliveredAt;
          }
          if (recRead == null ||
              (prev.receiptReadAt != null &&
                  prev.receiptReadAt!.isAfter(recRead))) {
            recRead = prev.receiptReadAt;
          }
        }
        b.insert(
          _db.localMessages,
          LocalMessagesCompanion.insert(
            id: Value(id),
            conversationId: conversationId,
            senderId: senderId,
            body: body,
            contentType: Value(ct),
            replyToMessageId: Value(
              reply == null ? null : (reply as num).toInt(),
            ),
            storyMediaId: Value(
              storyMid == null ? null : (storyMid as num).toInt(),
            ),
            createdAt: created,
            editedAt: Value(editedAt),
            receiptDeliveredAt: Value(recDel),
            receiptReadAt: Value(recRead),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
    await _touchConversationPreviewFromMessages(conversationId, items);
  }

  /// Updates inbox preview from the newest message in [items] (e.g. after send/WS).
  Future<void> _touchConversationPreviewFromMessages(
    int conversationId,
    List<Map<String, dynamic>> items,
  ) async {
    if (items.isEmpty) return;
    Map<String, dynamic>? newest;
    DateTime? newestAt;
    for (final m in items) {
      final created =
          DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now();
      if (newestAt == null || created.isAfter(newestAt)) {
        newestAt = created;
        newest = m;
      }
    }
    if (newest == null) return;
    final body = newest['body'] as String? ?? '';
    final ct = newest['content_type'] as String? ?? 'text/plain';
    final storyMid = newest['story_media_id'];
    final storyId = storyMid == null ? null : (storyMid as num).toInt();
    final preview = conversationPreviewForMessage(
      body: body,
      contentType: ct,
      storyMediaId: storyId,
    );
    final previewText = encodeConversationListPreview(preview);
    await (_db.update(_db.localConversations)
          ..where((t) => t.id.equals(conversationId)))
        .write(
      LocalConversationsCompanion(
        lastMessagePreview: Value(previewText),
        lastMessageAt: Value(newestAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<LocalMessage>> loadMessagesLocal(int conversationId) {
    return (_db.select(_db.localMessages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Latest cached row per conversation (newest [LocalMessage.createdAt] wins).
  Future<Map<int, LocalMessage>> _loadLatestMessageByConversation(
    Iterable<int> conversationIds,
  ) async {
    final ids = conversationIds.toList(growable: false);
    if (ids.isEmpty) return const {};
    final rows = await (_db.select(_db.localMessages)
          ..where((t) => t.conversationId.isIn(ids))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    final out = <int, LocalMessage>{};
    for (final row in rows) {
      out.putIfAbsent(row.conversationId, () => row);
    }
    return out;
  }

  /// Rebuilds inbox previews from cached message bodies so media captions keep
  /// their image/video icon even when the API `last_message_preview` is plain text.
  Future<void> _reconcileConversationPreviewsFromLocalMessages() async {
    final convs = await (_db.select(_db.localConversations)).get();
    if (convs.isEmpty) return;
    final latestByConv = await _loadLatestMessageByConversation(
      convs.map((c) => c.id),
    );
    for (final c in convs) {
      final latest = latestByConv[c.id];
      if (latest == null) continue;
      final convAt = c.lastMessageAt;
      if (convAt != null && latest.createdAt.isBefore(convAt)) continue;

      final computed = conversationPreviewForMessage(
        body: latest.body,
        contentType: latest.contentType,
        storyMediaId: latest.storyMediaId,
      );
      final encoded = encodeConversationListPreview(computed);
      if (encoded == (c.lastMessagePreview ?? '')) continue;

      await (_db.update(_db.localConversations)
            ..where((t) => t.id.equals(c.id)))
          .write(
        LocalConversationsCompanion(
          lastMessagePreview: Value(encoded),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<List<LocalConversation>> loadConversationsLocal() async {
    await _reconcileConversationPreviewsFromLocalMessages();
    return (_db.select(
      _db.localConversations,
    )..orderBy([
        (t) => OrderingTerm(
          expression: t.lastMessageAt,
          mode: OrderingMode.desc,
          nulls: NullsOrder.last,
        ),
        (t) => OrderingTerm.desc(t.updatedAt),
      ])).get();
  }

  /// Single cached conversation row, if present.
  Future<LocalConversation?> loadConversationLocal(int conversationId) {
    return (_db.select(
      _db.localConversations,
    )..where((t) => t.id.equals(conversationId))).getSingleOrNull();
  }

  /// Upsert one conversation row from a `GET/POST .../conversations` DTO (e.g. after fetch).
  Future<void> upsertLocalConversationFromDto(Map<String, dynamic> m) async {
    final id = (m['id'] as num).toInt();
    final type = m['type'] as String? ?? 'private';
    final title = m['title'] as String?;
    String? peerJson;
    if (m['peer'] != null) {
      peerJson = jsonEncode(m['peer']);
    }
    final preview = decodeConversationListPreview(
      m['last_message_preview'] as String?,
    );
    final previewText = encodeConversationListPreview(preview);
    final lastAtRaw = m['last_message_at'] as String?;
    final lastAt = DateTime.tryParse(lastAtRaw ?? '');
    final unread = _parseUnreadCount(m);
    await _db
        .into(_db.localConversations)
        .insert(
          LocalConversationsCompanion.insert(
            id: Value(id),
            type: type,
            title: Value(title),
            peerJson: Value(peerJson),
            lastMessagePreview: Value(previewText.isEmpty ? null : previewText),
            lastMessageAt: Value(lastAt),
            unreadCount: Value(unread),
            updatedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Cached `type` from last inbox sync (`private` / `group`), if known.
  Future<String?> conversationTypeLocal(int conversationId) async {
    final row = await (_db.select(
      _db.localConversations,
    )..where((t) => t.id.equals(conversationId))).getSingleOrNull();
    return row?.type;
  }

  Future<Map<String, dynamic>> fetchMessages(
    int conversationId, {
    String? cursor,
    String? q,
    String direction = 'older',
  }) =>
      _remote.listMessages(
        conversationId,
        cursor: cursor,
        q: q,
        direction: direction,
      );

  /// Gap-fill after reconnect: messages newer than the latest cached row.
  Future<void> syncNewerMessages(int conversationId) async {
    final local = await loadMessagesLocal(conversationId);
    if (local.isEmpty) {
      final data = await fetchMessages(conversationId);
      final items = (data['items'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      if (items.isNotEmpty) await cacheMessages(conversationId, items);
      return;
    }
    final cursor = local.first.id.toString();
    final data = await fetchMessages(
      conversationId,
      cursor: cursor,
      direction: 'newer',
    );
    final items = (data['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    if (items.isNotEmpty) await cacheMessages(conversationId, items);
  }

  Future<List<Map<String, dynamic>>> listStickers() async {
    final data = await _remote.listStickers();
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> fetchConversation(int conversationId) =>
      _remote.getConversation(conversationId);

  Future<Map<String, dynamic>> sendMessage(
    int conversationId, {
    required String body,
    int? replyToMessageId,
    int? storyMediaId,
    String contentType = 'text/plain',
  }) =>
      _remote.sendMessage(
        conversationId,
        body: body,
        replyToMessageId: replyToMessageId,
        storyMediaId: storyMediaId,
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
    await (_db.delete(
      _db.localMessages,
    )..where((t) => t.id.equals(messageId))).go();
  }

  Future<Map<String, dynamic>> getGroup(int conversationId) =>
      _remote.getGroup(conversationId);

  /// Leaves the group on the server and clears local cache for [conversationId].
  Future<void> leaveGroup(int conversationId) async {
    await _remote.leaveGroup(conversationId);
    await (_db.delete(
      _db.localMessages,
    )..where((t) => t.conversationId.equals(conversationId))).go();
    await (_db.delete(
      _db.messageOutbox,
    )..where((t) => t.conversationId.equals(conversationId))).go();
    await (_db.delete(
      _db.localConversations,
    )..where((t) => t.id.equals(conversationId))).go();
  }

  Future<void> addGroupMember(int groupId, int userId) =>
      _remote.addGroupMember(groupId, userId);

  Future<Map<String, dynamic>> patchGroup(
    int groupId, {
    String? title,
    String? avatarMediaKey,
  }) async {
    final data = await _remote.patchGroup(
      groupId,
      title: title,
      avatarMediaKey: avatarMediaKey,
    );
    final conv = data['conversation'] as Map<String, dynamic>?;
    if (conv != null) {
      await upsertLocalConversationFromDto(conv);
    }
    return data;
  }

  /// Upload a group avatar image; returns the object key for [patchGroup].
  Future<String> uploadGroupAvatarBytes({
    required int conversationId,
    required List<int> bytes,
    required String mimeType,
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
    return objectKey;
  }

  Future<void> removeGroupMember(int groupId, int userId) =>
      _remote.removeGroupMember(groupId, userId);

  Future<void> banGroupMember(int groupId, int userId) =>
      _remote.banGroupMember(groupId, userId);

  Future<void> unbanGroupMember(int groupId, int userId) =>
      _remote.unbanGroupMember(groupId, userId);

  Future<List<Map<String, dynamic>>> listGroupBans(int groupId) async {
    final data = await _remote.listGroupBans(groupId);
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Caches voice bytes under the app temp dir so [just_audio] can play from `file://`
  /// (avoids iOS issues with streaming authenticated URLs).
  Future<File> downloadVoiceToCache(String objectKey) async {
    return downloadMediaToCache(objectKey, fallbackExtension: 'm4a');
  }

  /// Caches image bytes locally so [Image.file] can render reliably with auth-backed
  /// downloads (same rationale as [downloadVoiceToCache]).
  Future<File> downloadImageToCache(String objectKey) async {
    final ext = p.extension(objectKey);
    final fallback = ext.isNotEmpty ? ext.replaceFirst('.', '') : 'jpg';
    return downloadMediaToCache(objectKey, fallbackExtension: fallback);
  }

  /// Downloads a media object to the temp cache dir, reusing an existing file when present.
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
    final bytes = await _remote.downloadMediaBytes(objectKey: objectKey);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Presign → upload → optional complete (S3/GCS) → send `application/vnd.mamana.media+json` message.
  Future<Map<String, dynamic>> uploadAndSendMediaMessage({
    required int conversationId,
    required List<int> bytes,
    required String mimeType,
    required String kind,
    int? durationMs,
    int? replyToMessageId,
    String? caption,
  }) =>
      _uploadAndSendMediaFromBytes(
        conversationId: conversationId,
        bytes: bytes,
        mimeType: mimeType,
        kind: kind,
        durationMs: durationMs,
        replyToMessageId: replyToMessageId,
        caption: caption,
      );

  Future<Map<String, dynamic>> _uploadAndSendMediaFromBytes({
    required int conversationId,
    required List<int> bytes,
    required String mimeType,
    required String kind,
    int? durationMs,
    int? replyToMessageId,
    String? caption,
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
      if (caption != null && caption.trim().isNotEmpty) 'caption': caption.trim(),
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

  Future<List<Map<String, dynamic>>> fetchMessageReceipts(
    int conversationId,
    int messageId,
  ) =>
      _remote.fetchMessageReceipts(conversationId, messageId);

  Future<void> typing(int conversationId, bool typing) async {
    try {
      await _remote.sendTyping(conversationId, typing);
    } catch (_) {}
    _socket.sendTyping(conversationId, typing);
  }

  Future<Map<String, dynamic>> createDm(int peerUserId) =>
      _remote.createPrivateDm(peerUserId);

  Future<Map<String, dynamic>> createGroup(String title, List<int> memberIds) =>
      _remote.createGroup(title: title, memberIds: memberIds);

  Future<void> registerPush({
    required String token,
    String platform = 'fcm',
  }) async {
    try {
      final deviceId = _tokens != null
          ? await _tokens.getOrCreateDeviceId()
          : null;
      await _remote.registerPushDevice(
        platform: platform,
        token: token,
        deviceId: deviceId,
      );
    } catch (_) {}
  }

  Future<void> unregisterPush() async {
    try {
      final deviceId = _tokens != null
          ? await _tokens.getOrCreateDeviceId()
          : null;
      await _remote.deletePushDevice(deviceId: deviceId);
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

  Future<void> leavePublicGroup(int groupId) =>
      _remote.leavePublicGroup(groupId);

  // --- Message Reactions ---

  Future<Map<String, dynamic>> addReaction(
    int conversationId,
    int messageId, {
    required String emoji,
  }) => _remote.addReaction(conversationId, messageId, emoji: emoji);

  Future<void> removeReaction(
    int conversationId,
    int messageId, {
    required String emoji,
  }) => _remote.removeReaction(conversationId, messageId, emoji: emoji);

  void dispose() {
    _reconnectSub?.cancel();
    _outboxChangesCtrl.close();
  }
}

int _parseUnreadCount(Map<String, dynamic> m) {
  final v = m['unread_count'];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return 0;
}
