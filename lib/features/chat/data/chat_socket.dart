import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';

const int _maxBackoffSeconds = 30;

/// WebSocket client for chat events (`api/websocket.md`).
///
/// Uses a token provider so reconnects pick up rotated access tokens. Applies
/// exponential backoff after [onDone] / [onError] until [disconnect].
class ChatSocket {
  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  String? _wsUrl;
  Future<String?> Function()? _tokenProvider;
  Timer? _reconnectTimer;
  int _reconnectDelaySeconds = 1;
  bool _manualDisconnect = false;

  Stream<Map<String, dynamic>> get events => _controller.stream;

  /// Opens a connection; repeats after disconnect using [accessTokenProvider] for a fresh bearer.
  void connect(
    String wsUrl,
    Future<String?> Function() accessTokenProvider,
  ) {
    _manualDisconnect = false;
    _wsUrl = wsUrl;
    _tokenProvider = accessTokenProvider;
    _reconnectDelaySeconds = 1;
    _cancelReconnectTimer();
    unawaited(_establish());
  }

  Future<void> _establish() async {
    final url = _wsUrl;
    final provider = _tokenProvider;
    if (url == null || provider == null || _manualDisconnect) {
      return;
    }

    final token = await provider();
    if (token == null || token.isEmpty) {
      _scheduleReconnect();
      return;
    }

    await _tearDownChannel();

    try {
      _channel = IOWebSocketChannel.connect(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      _reconnectDelaySeconds = 1;
      _sub = _channel!.stream.listen(
        _onMessage,
        onError: (_, __) => _onSocketTerminated(),
        onDone: _onSocketTerminated,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    if (raw is String) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _controller.add(map);
      } catch (_) {}
    }
  }

  void _onSocketTerminated() {
    if (_manualDisconnect) return;
    unawaited(() async {
      await _tearDownChannel();
      if (_manualDisconnect) return;
      _scheduleReconnect();
    }());
  }

  void _scheduleReconnect() {
    if (_manualDisconnect) return;
    _cancelReconnectTimer();
    final wait = _reconnectDelaySeconds;
    _reconnectTimer = Timer(Duration(seconds: wait), () {
      _reconnectTimer = null;
      if (_manualDisconnect) return;
      _reconnectDelaySeconds =
          (_reconnectDelaySeconds * 2).clamp(1, _maxBackoffSeconds);
      unawaited(_establish());
    });
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  Future<void> _tearDownChannel() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void sendTyping(int conversationId, bool typing) {
    final ch = _channel;
    if (ch == null) return;
    final payload = jsonEncode({
      'type': 'typing',
      'payload': {'conversation_id': conversationId, 'typing': typing},
    });
    try {
      ch.sink.add(payload);
    } catch (_) {}
  }

  /// Stops reconnecting and closes the socket (e.g. logout).
  void disconnect() {
    _manualDisconnect = true;
    _cancelReconnectTimer();
    _wsUrl = null;
    _tokenProvider = null;
    unawaited(_tearDownChannel());
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
