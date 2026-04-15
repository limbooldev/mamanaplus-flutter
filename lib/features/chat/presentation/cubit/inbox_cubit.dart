import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/database/app_database.dart';
import '../../data/chat_repository.dart';

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
  InboxCubit(this._repo) : super(const InboxState()) {
    _socketSub = _repo.socket.events.listen((event) {
      final type = event['type'] as String?;
      if (type != 'new_message') return;
      _scheduleQuietRefresh();
    });
  }

  final ChatRepository _repo;
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  Timer? _quietRefreshDebounce;

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
    return super.close();
  }
}
