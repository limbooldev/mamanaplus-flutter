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
  final _connectedCtrl = StreamController<void>.broadcast();

  Uri? _wsUri;
  Future<String?> Function()? _tokenProvider;
  Timer? _reconnectTimer;
  int _reconnectDelaySeconds = 1;
  bool _manualDisconnect = false;

  Stream<Map<String, dynamic>> get events => _controller.stream;

  /// Fires once each time a WebSocket connection is successfully established.
  /// Subscribers (e.g. [ThreadCubit]) use this to flush pending outbox rows.
  Stream<void> get connected => _connectedCtrl.stream;

  /// Opens a connection; repeats after disconnect using [accessTokenProvider] for a fresh bearer.
  void connect(
    Uri wsUri,
    Future<String?> Function() accessTokenProvider,
  ) {
    _manualDisconnect = false;
    _wsUri = wsUri;
    _tokenProvider = accessTokenProvider;
    _reconnectDelaySeconds = 1;
    _cancelReconnectTimer();
    unawaited(_establish());
  }

  Future<void> _establish() async {
    final uri = _wsUri;
    final provider = _tokenProvider;
    if (uri == null || provider == null || _manualDisconnect) {
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
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      _reconnectDelaySeconds = 1;
      _sub = _channel!.stream.listen(
        _onMessage,
        onError: (_, __) => _onSocketTerminated(),
        onDone: _onSocketTerminated,
      );
      if (!_connectedCtrl.isClosed) _connectedCtrl.add(null);
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

  /// Acknowledges that [messageIds] reached this device. The server flips each
  /// message's `delivered_at` and emits `receipt_update` to its sender so the
  /// sender's bubble can flip from Sent to Delivered in real time.
  void sendDeliveredAck(int conversationId, List<int> messageIds) {
    final ch = _channel;
    if (ch == null || messageIds.isEmpty) return;
    final payload = jsonEncode({
      'type': 'receipt:delivered',
      'payload': {
        'conversation_id': conversationId,
        'message_ids': messageIds,
      },
    });
    try {
      ch.sink.add(payload);
    } catch (_) {}
  }

  /// Stops reconnecting and closes the socket (e.g. logout).
  void disconnect() {
    _manualDisconnect = true;
    _cancelReconnectTimer();
    _wsUri = null;
    _tokenProvider = null;
    unawaited(_tearDownChannel());
  }

  void dispose() {
    disconnect();
    _controller.close();
    _connectedCtrl.close();
  }
}
