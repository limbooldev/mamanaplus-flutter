import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/database/app_database.dart';
import '../../data/chat_repository.dart';

int? _jsonInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
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
  });

  final List<LocalMessage> messages;
  final bool loading;
  final bool sending;
  final String? error;
  final Set<int> typingUserIds;
  final LocalMessage? replyTo;

  /// Other members' cumulative read cursor (`receipt_update.message_id`), by user id.
  final Map<int, int> readCursorByUserId;

  ThreadState copyWith({
    List<LocalMessage>? messages,
    bool? loading,
    bool? sending,
    String? error,
    Set<int>? typingUserIds,
    LocalMessage? replyTo,
    Map<int, int>? readCursorByUserId,
  }) =>
      ThreadState(
        messages: messages ?? this.messages,
        loading: loading ?? this.loading,
        sending: sending ?? this.sending,
        error: error,
        typingUserIds: typingUserIds ?? this.typingUserIds,
        replyTo: replyTo,
        readCursorByUserId: readCursorByUserId ?? this.readCursorByUserId,
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
  List<Object?> get props =>
      [messages, loading, sending, error, typingUserIds, replyTo, readCursorByUserId];
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
    if (_resolvedConversationType == null) {
      try {
        final raw = await _repo.fetchConversation(conversationId);
        _resolvedConversationType = raw['type'] as String?;
      } catch (_) {}
    }
    emit(state.copyWith(loading: true));
    try {
      final data = await _repo.fetchMessages(conversationId);
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      await _repo.cacheMessages(conversationId, items);
      final local = await _repo.loadMessagesLocal(conversationId);
      emit(ThreadState(messages: local, loading: false));
      if (local.isNotEmpty) {
        await _repo.markRead(conversationId, local.first.id);
      }
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }

    _sub = _repo.socket.events.listen((event) async {
      final type = event['type'] as String?;
      final payload = event['payload'];
      if (type == 'new_message' && payload is Map<String, dynamic>) {
        final cid = _jsonInt(payload['conversation_id']);
        if (cid != conversationId) return;
        final msg = payload['message'] as Map<String, dynamic>?;
        if (msg == null) return;
        // Write first, then read — avoids race between async cache and reload.
        await _repo.cacheMessages(conversationId, [msg]);
        await _reloadLocal();
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

  Future<void> _reloadLocal() async {
    final local = await _repo.loadMessagesLocal(conversationId);
    emit(state.copyWith(messages: local));
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
      final data = await _repo.fetchMessages(conversationId);
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

  Future<void> sendStubAttachment() async {
    emit(state.copyWith(sending: true, error: null));
    try {
      await _repo.sendStubAttachment(conversationId);
      final data = await _repo.fetchMessages(conversationId);
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      await _repo.cacheMessages(conversationId, items);
      await _reloadLocal();
      emit(state.copyWith(sending: false));
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
