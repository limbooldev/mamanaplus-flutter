import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';

const int _maxBackoffSeconds = 30;

/// Heartbeat cadence. The backend (`internal/httpapi/ws_handler.go`) closes the
/// connection if it doesn't see traffic for 60 s, so pinging every 25 s gives
/// enough margin while also letting the client detect a half-open socket
/// promptly when the OS suspends the app and silently drops the TCP flow.
const Duration _wsPingInterval = Duration(seconds: 25);

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
  bool _connecting = false;
  // True while the app is backgrounded. Differs from [_manualDisconnect] in
  // that we keep [_wsUri] / [_tokenProvider] around so [resume] can reconnect
  // without the caller re-supplying them. While suspended we skip reconnect
  // scheduling so we don't burn battery retrying from the background.
  bool _suspended = false;

  Stream<Map<String, dynamic>> get events => _controller.stream;

  /// Fires once each time a WebSocket connection is successfully established.
  /// Subscribers (e.g. [ThreadCubit]) use this to flush pending outbox rows
  /// and re-fetch any messages missed while the socket was down.
  Stream<void> get connected => _connectedCtrl.stream;

  /// True while a live underlying WebSocket exists. Does NOT guarantee the peer
  /// is reachable — half-open sockets only show up here as connected until the
  /// next ping fails. Use [ensureConnected] from lifecycle handlers to force a
  /// fresh connect attempt rather than relying solely on this flag.
  bool get isConnected => _channel != null;

  /// Opens a connection; repeats after disconnect using [accessTokenProvider] for a fresh bearer.
  void connect(
    Uri wsUri,
    Future<String?> Function() accessTokenProvider,
  ) {
    _manualDisconnect = false;
    _suspended = false;
    _wsUri = wsUri;
    _tokenProvider = accessTokenProvider;
    _reconnectDelaySeconds = 1;
    _cancelReconnectTimer();
    unawaited(_establish());
  }

  Future<void> _establish() async {
    final uri = _wsUri;
    final provider = _tokenProvider;
    if (uri == null || provider == null || _manualDisconnect || _suspended) {
      return;
    }
    // Guard against overlapping connect attempts (e.g. lifecycle resume firing
    // while a scheduled reconnect timer already started one). Without this,
    // we could end up with two live channels and double-deliver every event.
    if (_connecting) return;
    _connecting = true;

    try {
      final token = await provider();
      if (token == null || token.isEmpty) {
        _scheduleReconnect();
        return;
      }

      await _tearDownChannel();
      if (_manualDisconnect || _suspended) return;

      try {
        _channel = IOWebSocketChannel.connect(
          uri,
          headers: {'Authorization': 'Bearer $token'},
          pingInterval: _wsPingInterval,
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
    } finally {
      _connecting = false;
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
      if (_manualDisconnect || _suspended) return;
      _scheduleReconnect();
    }());
  }

  void _scheduleReconnect() {
    if (_manualDisconnect || _suspended) return;
    _cancelReconnectTimer();
    final wait = _reconnectDelaySeconds;
    _reconnectTimer = Timer(Duration(seconds: wait), () {
      _reconnectTimer = null;
      if (_manualDisconnect || _suspended) return;
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

  /// Forces an immediate reconnect attempt if the socket is currently down or
  /// a backoff timer is pending. Safe to call when the socket is already up —
  /// in that case it's a no-op. No-op while [suspend]ed (use [resume] instead).
  void ensureConnected() {
    if (_manualDisconnect || _suspended) return;
    if (_wsUri == null || _tokenProvider == null) return;
    if (_channel != null) return;
    _cancelReconnectTimer();
    _reconnectDelaySeconds = 1;
    unawaited(_establish());
  }

  /// Tears down the live socket and stops reconnecting WITHOUT clearing the
  /// stored URI/token provider, so [resume] can reconnect without the caller
  /// re-supplying them. Use from `AppLifecycleState.paused`.
  ///
  /// Why this matters: a backgrounded app can't reliably process WebSocket
  /// events anyway, but keeping the connection registered on the backend has
  /// two bad side-effects: (1) presence shows the user as "Online" when they
  /// aren't, and (2) any in-memory [ThreadCubit] keeps receiving `new_message`
  /// frames and auto-acks them as read, so the sender sees seen-checkmarks
  /// before the user actually saw the message. Suspending forces the server
  /// to fall back to FCM push for delivery (see
  /// `internal/httpapi/push_notify.go#deliverNewMessagePush`).
  void suspend() {
    if (_manualDisconnect) return;
    if (_suspended) return;
    _suspended = true;
    _cancelReconnectTimer();
    unawaited(_tearDownChannel());
  }

  /// Clears the suspension flag and immediately attempts to reconnect. Pair
  /// with [suspend] on `AppLifecycleState.resumed`. Safe to call when not
  /// currently suspended — it's a no-op in that case.
  void resume() {
    if (_manualDisconnect) return;
    if (!_suspended) return;
    _suspended = false;
    _reconnectDelaySeconds = 1;
    if (_wsUri != null && _tokenProvider != null && _channel == null) {
      unawaited(_establish());
    }
  }

  /// Stops reconnecting and closes the socket (e.g. logout).
  void disconnect() {
    _manualDisconnect = true;
    _suspended = false;
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
