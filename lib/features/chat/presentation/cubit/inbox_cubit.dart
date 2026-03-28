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
  InboxCubit(this._repo) : super(const InboxState());

  final ChatRepository _repo;

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
}
