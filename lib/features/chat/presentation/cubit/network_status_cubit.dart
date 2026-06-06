import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/chat_socket.dart';
import '../../data/connection_state.dart';

/// Emits `true` when the device has no network (WebSocket `no_network` disconnect).
class NetworkStatusCubit extends Cubit<bool> {
  NetworkStatusCubit(ChatSocket socket) : super(_isWaitingForNetwork(socket.state)) {
    _sub = socket.stateStream.listen((s) {
      emit(_isWaitingForNetwork(s));
    });
  }

  late final StreamSubscription<ConnectionState> _sub;

  static bool _isWaitingForNetwork(ConnectionState s) =>
      s.status == ConnectionStatus.disconnected &&
      s.lastDisconnectReason == 'no_network';

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
