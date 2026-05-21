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

class InboxState extends Equatable {
  const InboxState({
    this.items = const [],
    this.loading = false,
    this.error,
  });

  final List<LocalConversation> items;
  final bool loading;
  final String? error;

  InboxState copyWith({
    List<LocalConversation>? items,
    bool? loading,
    String? error,
  }) =>
      InboxState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        error: error,
      );

  @override
  List<Object?> get props => [items, loading, error];
}

class InboxCubit extends Cubit<InboxState> {
  InboxCubit(this._repo, {this.myUserId}) : super(const InboxState()) {
    _socketSub = _repo.socket.events.listen((event) {
      final type = event['type'] as String?;
      if (type == 'new_message') {
        _maybeAckDelivered(event);
        _scheduleQuietRefresh();
      } else if (type == 'message_edited') {
        _scheduleQuietRefresh();
      }
    });
    // Flush all outbox rows across all conversations when the socket reconnects.
    // This covers messages sent while offline in conversations not currently open.
    _reconnectSub = _repo.socket.connected.listen((_) {
      unawaited(_repo.flushAllOutbox());
    });
  }

  final ChatRepository _repo;

  /// Used to detect own messages (no ack needed) and avoid spamming the WS.
  /// Null when the cubit is created before login resolves; ack is then skipped
  /// (the per-thread cubit acks anyway when the user opens the conversation).
  final int? myUserId;
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  StreamSubscription<void>? _reconnectSub;
  Timer? _quietRefreshDebounce;

  void _maybeAckDelivered(Map<String, dynamic> event) {
    final me = myUserId;
    if (me == null) return;
    final payload = event['payload'];
    if (payload is! Map<String, dynamic>) return;
    final cid = _jsonInt(payload['conversation_id']);
    final msg = payload['message'];
    if (cid == null || msg is! Map<String, dynamic>) return;
    final senderId = _jsonInt(msg['sender_id']);
    final mid = _jsonInt(msg['id']);
    if (mid == null || senderId == null || senderId == me) return;
    _repo.socket.sendDeliveredAck(cid, [mid]);
  }

  void _scheduleQuietRefresh() {
    if (isClosed) return;
    _quietRefreshDebounce?.cancel();
    _quietRefreshDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(refreshQuiet());
    });
  }

  /// Sync conversation list from API without toggling loading (WebSocket, return from thread).
  Future<void> refreshQuiet() async {
    if (isClosed) return;
    try {
      await _repo.syncConversationsFromRemote();
      if (isClosed) return;
      final local = await _repo.loadConversationsLocal();
      if (isClosed) return;
      emit(state.copyWith(items: local));
    } catch (_) {}
  }

  Future<void> refresh() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      await _repo.flushAllOutbox();
      await _repo.syncConversationsFromRemote();
      final local = await _repo.loadConversationsLocal();
      emit(InboxState(items: local, loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _quietRefreshDebounce?.cancel();
    _socketSub?.cancel();
    _reconnectSub?.cancel();
    return super.close();
  }
}
