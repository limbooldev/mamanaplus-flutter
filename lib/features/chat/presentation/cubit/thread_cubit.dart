import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/database/app_database.dart';
import '../../data/chat_repository.dart';

class ThreadState extends Equatable {
  const ThreadState({
    this.messages = const [],
    this.loading = false,
    this.sending = false,
    this.error,
    this.typingUserIds = const {},
    this.replyTo,
  });

  final List<LocalMessage> messages;
  final bool loading;
  final bool sending;
  final String? error;
  final Set<int> typingUserIds;
  final LocalMessage? replyTo;

  ThreadState copyWith({
    List<LocalMessage>? messages,
    bool? loading,
    bool? sending,
    String? error,
    Set<int>? typingUserIds,
    LocalMessage? replyTo,
  }) =>
      ThreadState(
        messages: messages ?? this.messages,
        loading: loading ?? this.loading,
        sending: sending ?? this.sending,
        error: error,
        typingUserIds: typingUserIds ?? this.typingUserIds,
        replyTo: replyTo,
      );

  @override
  List<Object?> get props => [messages, loading, sending, error, typingUserIds, replyTo];
}

class ThreadCubit extends Cubit<ThreadState> {
  ThreadCubit(
    this._repo,
    this.conversationId,
    this.myUserId,
  ) : super(const ThreadState());

  final ChatRepository _repo;
  final int conversationId;
  final int myUserId;
  StreamSubscription<Map<String, dynamic>>? _sub;

  Future<void> init() async {
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

    _sub = _repo.socket.events.listen((event) {
      final type = event['type'] as String?;
      final payload = event['payload'];
      if (type == 'new_message' && payload is Map<String, dynamic>) {
        final cid = (payload['conversation_id'] as num?)?.toInt();
        if (cid != conversationId) return;
        final msg = payload['message'] as Map<String, dynamic>?;
        if (msg == null) return;
        _repo.cacheMessages(conversationId, [msg]);
        _reloadLocal();
      } else if (type == 'typing' && payload is Map<String, dynamic>) {
        final cid = (payload['conversation_id'] as num?)?.toInt();
        final uid = (payload['user_id'] as num?)?.toInt();
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
        final cid = (payload['conversation_id'] as num?)?.toInt();
        if (cid != conversationId) return;
        _reloadLocal();
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
