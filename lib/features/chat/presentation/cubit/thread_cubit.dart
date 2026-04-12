import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mime/mime.dart';

import '../../../../core/database/app_database.dart';
import '../../data/chat_repository.dart';
import '../../media_constants.dart';

int? _jsonInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

String? _peerDisplayNameFromPeerJson(String? peerJson) {
  if (peerJson == null) return null;
  try {
    final m = jsonDecode(peerJson) as Map<String, dynamic>;
    return (m['display_name'] as String?)?.trim();
  } catch (_) {
    return null;
  }
}

String? _peerDisplayNameFromPeerField(dynamic peer) {
  if (peer is! Map) return null;
  return (peer['display_name'] as String?)?.trim();
}

int? _peerUserIdFromPeerField(dynamic peer) {
  if (peer is! Map) return null;
  final id = peer['id'];
  if (id is int) return id;
  if (id is num) return id.toInt();
  return null;
}

int? _peerUserIdFromPeerJson(String? peerJson) {
  if (peerJson == null) return null;
  try {
    final m = jsonDecode(peerJson) as Map<String, dynamic>;
    final id = m['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return null;
  } catch (_) {
    return null;
  }
}

class ThreadState extends Equatable {
  const ThreadState({
    this.messages = const [],
    this.loading = false,
    this.sending = false,
    this.error,
    this.typingUserIds = const {},
    this.replyTo,
    this.readCursorByUserId = const {},
    this.headerTitle,
    this.dmPeerUserId,
    this.messageSearchQuery,
  });

  final List<LocalMessage> messages;
  final bool loading;
  final bool sending;
  final String? error;
  final Set<int> typingUserIds;
  final LocalMessage? replyTo;

  /// Other members' cumulative read cursor (`receipt_update.message_id`), by user id.
  final Map<int, int> readCursorByUserId;

  /// App bar title for private (peer name) or group (title); null → fallback `Thread #id`.
  final String? headerTitle;

  /// Private DM: other participant's user id (for block-from-thread, etc.).
  final int? dmPeerUserId;

  /// Group in-thread search (server `q`); null when inactive.
  final String? messageSearchQuery;

  ThreadState copyWith({
    List<LocalMessage>? messages,
    bool? loading,
    bool? sending,
    String? error,
    Set<int>? typingUserIds,
    LocalMessage? replyTo,
    Map<int, int>? readCursorByUserId,
    String? headerTitle,
    int? dmPeerUserId,
    String? messageSearchQuery,
    bool clearMessageSearch = false,
  }) =>
      ThreadState(
        messages: messages ?? this.messages,
        loading: loading ?? this.loading,
        sending: sending ?? this.sending,
        error: error,
        typingUserIds: typingUserIds ?? this.typingUserIds,
        replyTo: replyTo,
        readCursorByUserId: readCursorByUserId ?? this.readCursorByUserId,
        headerTitle: headerTitle ?? this.headerTitle,
        dmPeerUserId: dmPeerUserId ?? this.dmPeerUserId,
        messageSearchQuery:
            clearMessageSearch ? null : (messageSearchQuery ?? this.messageSearchQuery),
      );

  /// Private DM: max peer read cursor from `receipt_update` — double-check when read up to [messageId].
  bool readReceiptForOwnMessage(int messageId, String? conversationType) {
    if (conversationType != 'private') return false;
    if (readCursorByUserId.isEmpty) return false;
    final peerMax = readCursorByUserId.values.reduce(
      (a, b) => a >= b ? a : b,
    );
    return peerMax >= messageId;
  }

  @override
  List<Object?> get props => [
        messages,
        loading,
        sending,
        error,
        typingUserIds,
        replyTo,
        readCursorByUserId,
        headerTitle,
        dmPeerUserId,
        messageSearchQuery,
      ];
}

class ThreadCubit extends Cubit<ThreadState> {
  ThreadCubit(
    this._repo,
    this.conversationId,
    this.myUserId, {
    this.conversationType,
  }) : super(const ThreadState());

  final ChatRepository _repo;
  final int conversationId;
  final int myUserId;
  final String? conversationType;
  StreamSubscription<Map<String, dynamic>>? _sub;

  /// Route extra and/or local inbox cache (`private` / `group`).
  String? _resolvedConversationType;

  String? get effectiveConversationType =>
      _resolvedConversationType ?? conversationType;

  Future<void> init() async {
    _resolvedConversationType =
        conversationType ?? await _repo.conversationTypeLocal(conversationId);
    Map<String, dynamic>? prefetchedConv;
    if (_resolvedConversationType == null) {
      try {
        prefetchedConv = await _repo.fetchConversation(conversationId);
        _resolvedConversationType = prefetchedConv['type'] as String?;
      } catch (_) {}
    }
    emit(state.copyWith(loading: true));
    unawaited(_hydrateHeader(prefetched: prefetchedConv));
    unawaited(_resolveDmPeerUserId(prefetched: prefetchedConv));
    await _reloadMessagesFromRemote();

    _sub = _repo.socket.events.listen((event) async {
      final type = event['type'] as String?;
      final payload = event['payload'];
      if (type == 'new_message' && payload is Map<String, dynamic>) {
        final cid = _jsonInt(payload['conversation_id']);
        if (cid != conversationId) return;
        final msg = payload['message'] as Map<String, dynamic>?;
        if (msg == null) return;
        if (state.messageSearchQuery != null) {
          await _reloadMessagesFromRemote();
        } else {
          // Write first, then read — avoids race between async cache and reload.
          await _repo.cacheMessages(conversationId, [msg]);
          await _reloadLocal();
        }
        // Mark new message as read immediately (user is in the thread).
        final msgId = _jsonInt(msg['id']);
        if (msgId != null) {
          unawaited(_repo.markRead(conversationId, msgId));
        }
      } else if (type == 'typing' && payload is Map<String, dynamic>) {
        final cid = _jsonInt(payload['conversation_id']);
        final uid = _jsonInt(payload['user_id']);
        final typing = payload['typing'] as bool? ?? false;
        if (cid != conversationId || uid == null || uid == myUserId) return;
        final next = Set<int>.from(state.typingUserIds);
        if (typing) {
          next.add(uid);
        } else {
          next.remove(uid);
        }
        emit(state.copyWith(typingUserIds: next));
      } else if (type == 'receipt_update' && payload is Map<String, dynamic>) {
        final cid = _jsonInt(payload['conversation_id']);
        if (cid != conversationId) return;
        final uid = _jsonInt(payload['user_id']);
        final mid = _jsonInt(payload['message_id']);
        if (uid == null || mid == null || uid == myUserId) return;
        final prev = state.readCursorByUserId[uid] ?? 0;
        final v = mid > prev ? mid : prev;
        final newCursor = {...state.readCursorByUserId, uid: v};
        // Load fresh messages first, then emit ONCE with both cursor + messages.
        // Previously two separate emits (cursor, then reload) caused two concurrent
        // setMessages calls that raced and clobbered each other.
        final local = await _repo.loadMessagesLocal(conversationId);
        emit(state.copyWith(
          readCursorByUserId: newCursor,
          messages: local,
        ));
      }
    });
  }

  Future<void> _resolveDmPeerUserId({Map<String, dynamic>? prefetched}) async {
    if (effectiveConversationType != 'private') return;
    if (state.dmPeerUserId != null) return;
    final fromPrefetch = prefetched != null
        ? _peerUserIdFromPeerField(prefetched['peer'])
        : null;
    if (fromPrefetch != null) {
      emit(state.copyWith(dmPeerUserId: fromPrefetch));
      return;
    }
    final local = await _repo.loadConversationLocal(conversationId);
    final fromJson = _peerUserIdFromPeerJson(local?.peerJson);
    if (fromJson != null) {
      emit(state.copyWith(dmPeerUserId: fromJson));
      return;
    }
    try {
      final raw = prefetched ?? await _repo.fetchConversation(conversationId);
      final id = _peerUserIdFromPeerField(raw['peer']);
      if (id != null) {
        await _repo.upsertLocalConversationFromDto(raw);
        emit(state.copyWith(dmPeerUserId: id));
      }
    } catch (_) {}
  }

  /// Resolves app bar title from local cache or `GET /v1/conversations/{id}`.
  Future<void> _hydrateHeader({Map<String, dynamic>? prefetched}) async {
    final local = await _repo.loadConversationLocal(conversationId);
    final type = _resolvedConversationType ?? local?.type;

    if (type == 'group') {
      final t = local?.title?.trim();
      if (t != null && t.isNotEmpty) {
        emit(state.copyWith(headerTitle: t));
      }
      return;
    }

    if (type != 'private') return;

    var name = _peerDisplayNameFromPeerJson(local?.peerJson);
    if ((name == null || name.isEmpty) && prefetched != null) {
      name = _peerDisplayNameFromPeerField(prefetched['peer']);
      if (name != null && name.isNotEmpty) {
        await _repo.upsertLocalConversationFromDto(prefetched);
      }
    }
    if (name == null || name.isEmpty) {
      try {
        final raw = prefetched ?? await _repo.fetchConversation(conversationId);
        await _repo.upsertLocalConversationFromDto(raw);
        name = _peerDisplayNameFromPeerField(raw['peer']);
      } catch (_) {}
    }
    if (name != null && name.isNotEmpty) {
      emit(state.copyWith(headerTitle: name));
    }
  }

  Future<void> _reloadLocal() async {
    final local = await _repo.loadMessagesLocal(conversationId);
    emit(state.copyWith(messages: local));
  }

  Future<void> _reloadMessagesFromRemote() async {
    try {
      final data = await _repo.fetchMessages(
        conversationId,
        q: state.messageSearchQuery,
      );
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      await _repo.cacheMessages(conversationId, items);
      final local = await _repo.loadMessagesLocal(conversationId);
      emit(state.copyWith(messages: local, loading: false));
      if (local.isNotEmpty) {
        await _repo.markRead(conversationId, local.first.id);
      }
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  /// Server-side substring search (text/plain only); pass null or short string to clear.
  Future<void> setMessageSearchQuery(String? raw) async {
    final q = raw?.trim();
    final norm = (q == null || q.length < 2) ? null : q;
    emit(state.copyWith(loading: true, error: null, clearMessageSearch: norm == null, messageSearchQuery: norm));
    await _reloadMessagesFromRemote();
  }

  void setReplyTo(LocalMessage? m) => emit(state.copyWith(replyTo: m));

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;
    emit(state.copyWith(sending: true, error: null));
    try {
      await _repo.sendMessage(
        conversationId,
        body: text.trim(),
        replyToMessageId: state.replyTo?.id,
      );
      emit(state.copyWith(sending: false, replyTo: null));
      final data = await _repo.fetchMessages(conversationId, q: state.messageSearchQuery);
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      await _repo.cacheMessages(conversationId, items);
      await _reloadLocal();
    } catch (e) {
      try {
        await _repo.enqueuePendingSend(
          localId: '${conversationId}_${DateTime.now().microsecondsSinceEpoch}',
          conversationId: conversationId,
          body: text.trim(),
          replyToMessageId: state.replyTo?.id,
        );
      } catch (_) {}
      emit(state.copyWith(sending: false, error: e.toString()));
    }
  }

  /// [kind] is `image`, `video`, or `voice` (matches backend JSON).
  Future<void> sendMediaFile({
    required String path,
    required String kind,
    int? durationMs,
  }) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final mime = lookupMimeType(path) ?? 'application/octet-stream';
    emit(state.copyWith(sending: true, error: null));
    try {
      await _repo.uploadAndSendMediaMessage(
        conversationId: conversationId,
        bytes: bytes,
        mimeType: mime,
        kind: kind,
        durationMs: durationMs,
        replyToMessageId: state.replyTo?.id,
      );
      emit(state.copyWith(sending: false, replyTo: null));
      final data = await _repo.fetchMessages(conversationId, q: state.messageSearchQuery);
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      await _repo.cacheMessages(conversationId, items);
      await _reloadLocal();
    } catch (e) {
      emit(state.copyWith(sending: false, error: e.toString()));
    }
  }

  Future<void> sendSticker({required String stickerId, required String emoji}) async {
    emit(state.copyWith(sending: true, error: null));
    try {
      final body = jsonEncode({'sticker_id': stickerId, 'emoji': emoji});
      await _repo.sendMessage(
        conversationId,
        body: body,
        contentType: kMamanaStickerContentType,
        replyToMessageId: state.replyTo?.id,
      );
      emit(state.copyWith(sending: false, replyTo: null));
      final data = await _repo.fetchMessages(conversationId, q: state.messageSearchQuery);
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      await _repo.cacheMessages(conversationId, items);
      await _reloadLocal();
    } catch (e) {
      emit(state.copyWith(sending: false, error: e.toString()));
    }
  }

  Future<void> editMessage(int messageId, String newBody) async {
    if (newBody.trim().isEmpty) return;
    try {
      await _repo.editMessage(conversationId, messageId, body: newBody.trim());
      await _reloadLocal();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> deleteMessage(int messageId, {bool forEveryone = false}) async {
    try {
      await _repo.deleteMessage(
        conversationId,
        messageId,
        scope: forEveryone ? 'for_everyone' : 'for_me',
      );
      await _reloadLocal();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> flushOutbox() async {
    await _repo.flushPendingSends(conversationId);
    await _reloadLocal();
  }

  void onTyping(bool v) => unawaited(_repo.typing(conversationId, v));

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
