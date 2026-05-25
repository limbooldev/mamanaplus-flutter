import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:web_socket_channel/io.dart';

import '../../../core/jwt_utils.dart';
import 'connection_logger.dart';
import 'connection_state.dart';

const int _maxBackoffSeconds = 30;

/// Server read idle timeout (`internal/httpapi/ws_handler.go`); client watchdog
/// matches this so half-open sockets are detected without waiting for OS TCP.
const Duration _livenessTimeout = Duration(seconds: 90);

/// Client ping interval — margin under server 90s idle and server 30s ping.
const Duration _wsPingInterval = Duration(seconds: 25);

/// After server graceful restart (close code 1001), reconnect quickly.
const Duration _serverRestartReconnectDelay = Duration(seconds: 5);

/// WebSocket client for chat events (`api/websocket.md`).
///
/// Serialized action queue, exponential backoff with jitter, proactive token
/// refresh, connectivity awareness, and liveness watchdog.
class ConnectionManager {
  ConnectionManager({
    ConnectionLogger? logger,
    Connectivity? connectivity,
  })  : _logger = logger ?? ConnectionLogger(),
        _connectivity = connectivity ?? Connectivity();

  final ConnectionLogger _logger;
  final Connectivity _connectivity;

  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  final _eventsCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _connectedCtrl = StreamController<void>.broadcast();
  final _stateCtrl = StreamController<ConnectionState>.broadcast();

  Uri? _wsUri;
  AccessTokenProvider? _tokenProvider;

  Timer? _reconnectTimer;
  Timer? _livenessTimer;
  int _reconnectDelaySeconds = 1;
  bool _manualDisconnect = false;
  bool _suspended = false;
  bool _networkAvailable = true;
  bool _connecting = false;
  bool _authRefreshAttemptedThisCycle = false;
  bool _serverRestartPending = false;

  ConnectionState _state = const ConnectionState(status: ConnectionStatus.idle);

  Future<void> _actionChain = Future<void>.value();
  final _rng = Random();

  Stream<Map<String, dynamic>> get events => _eventsCtrl.stream;

  /// Fires once each time a WebSocket connection is successfully established.
  Stream<void> get connected => _connectedCtrl.stream;

  Stream<ConnectionState> get stateStream => _stateCtrl.stream;

  ConnectionState get state => _state;

  bool get isConnected => _channel != null;

  void _emitState(ConnectionState next) {
    _state = next;
    if (!_stateCtrl.isClosed) _stateCtrl.add(next);
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final run = _actionChain.then((_) => action());
    _actionChain = run.then((_) {}, onError: (_) {});
    return run;
  }

  void connect(Uri wsUri, AccessTokenProvider accessTokenProvider) {
    unawaited(_enqueue(() async {
      _manualDisconnect = false;
      _suspended = false;
      _wsUri = wsUri;
      _tokenProvider = accessTokenProvider;
      _reconnectDelaySeconds = 1;
      _cancelReconnectTimer();
      _startConnectivityListener();
      await _establish();
    }));
  }

  void forceReconnect() {
    unawaited(_enqueue(() async {
      if (_manualDisconnect || _suspended) return;
      if (_wsUri == null || _tokenProvider == null) return;
      _cancelReconnectTimer();
      _reconnectDelaySeconds = 1;
      await _tearDownChannel();
      await _establish();
    }));
  }

  void ensureConnected() => forceReconnect();

  void notifyTokenRotated() {
    unawaited(_enqueue(() async {
      if (_manualDisconnect || _suspended) return;
      if (_wsUri == null || _tokenProvider == null) return;
      if (_channel != null && _state.status == ConnectionStatus.connected) {
        return;
      }
      _cancelReconnectTimer();
      _reconnectDelaySeconds = 1;
      await _establish();
    }));
  }

  void suspend() {
    unawaited(_enqueue(() async {
      if (_manualDisconnect) return;
      if (_suspended) return;
      _suspended = true;
      _cancelReconnectTimer();
      _cancelLivenessTimer();
      _emitState(
        _state.copyWith(
          status: ConnectionStatus.suspended,
          clearNextRetryAt: true,
        ),
      );
      await _tearDownChannel();
      _logger.info('suspend');
    }));
  }

  void resume() {
    unawaited(_enqueue(() async {
      if (_manualDisconnect) return;
      if (!_suspended) return;
      _suspended = false;
      _reconnectDelaySeconds = 1;
      _logger.info('resume');
      if (_wsUri != null && _tokenProvider != null) {
        await _tearDownChannel();
        await _establish();
      }
    }));
  }

  void disconnect() {
    unawaited(_enqueue(() async {
      _manualDisconnect = true;
      _suspended = false;
      _cancelReconnectTimer();
      _cancelLivenessTimer();
      await _connectivitySub?.cancel();
      _connectivitySub = null;
      _wsUri = null;
      _tokenProvider = null;
      await _tearDownChannel();
      _emitState(
        const ConnectionState(
          status: ConnectionStatus.disconnected,
          lastDisconnectReason: 'manual',
        ),
      );
      _logger.info('disconnect', fields: {'reason': 'manual'});
    }));
  }

  void dispose() {
    disconnect();
    _eventsCtrl.close();
    _connectedCtrl.close();
    _stateCtrl.close();
  }

  void _startConnectivityListener() {
    if (_connectivitySub != null) return;
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      final wasOffline = !_networkAvailable;
      _networkAvailable = online;
      if (!online) {
        _cancelReconnectTimer();
        _emitState(
          _state.copyWith(
            status: ConnectionStatus.disconnected,
            lastDisconnectReason: 'no_network',
            clearNextRetryAt: true,
          ),
        );
        _logger.info('network_lost');
        return;
      }
      if (wasOffline && !_manualDisconnect && !_suspended) {
        _logger.info('network_restored');
        _reconnectDelaySeconds = 1;
        forceReconnect();
      }
    });
  }

  Future<void> _establish() async {
    final uri = _wsUri;
    final provider = _tokenProvider;
    if (uri == null || provider == null || _manualDisconnect || _suspended) {
      return;
    }
    if (!_networkAvailable) {
      _emitState(
        _state.copyWith(
          status: ConnectionStatus.disconnected,
          lastDisconnectReason: 'no_network',
        ),
      );
      return;
    }
    if (_connecting) return;
    _connecting = true;
    _authRefreshAttemptedThisCycle = false;

    final attempt = _state.reconnectAttempt + 1;
    _emitState(
      ConnectionState(
        status: _state.status == ConnectionStatus.idle
            ? ConnectionStatus.connecting
            : ConnectionStatus.reconnecting,
        reconnectAttempt: attempt,
        lastDisconnectReason: _state.lastDisconnectReason,
      ),
    );

    try {
      var token = await provider();
      if (jwtNeedsRefresh(token)) {
        token = await provider(forceRefresh: true);
      }
      if (token == null || token.isEmpty) {
        _logger.warn('connect_skip', fields: {'reason': 'no_token'});
        _scheduleReconnect('no_token');
        return;
      }

      await _tearDownChannel();
      if (_manualDisconnect || _suspended) return;

      final sw = Stopwatch()..start();
      try {
        _channel = IOWebSocketChannel.connect(
          uri,
          headers: {'Authorization': 'Bearer $token'},
          pingInterval: _wsPingInterval,
        );
        _reconnectDelaySeconds = 1;
        _sub = _channel!.stream.listen(
          _onMessage,
          onError: (e, _) => _onSocketTerminated(reason: 'error', error: e),
          onDone: () => _onSocketTerminated(reason: 'done'),
        );
        _resetLivenessTimer();
        if (!_connectedCtrl.isClosed) _connectedCtrl.add(null);
        _emitState(
          ConnectionState(
            status: ConnectionStatus.connected,
            reconnectAttempt: 0,
          ),
        );
        _logger.info(
          'connected',
          fields: {
            'host': uri.host,
            'ms': sw.elapsedMilliseconds,
            'token_fp': ConnectionLogger.tokenFingerprint(token),
            'attempt': attempt,
          },
        );
      } on WebSocketException catch (e) {
        sw.stop();
        final unauthorized = _isUnauthorized(e);
        _logger.warn(
          'connect_fail',
          fields: {
            'host': uri.host,
            'ms': sw.elapsedMilliseconds,
            'unauthorized': unauthorized,
            'err': '$e',
          },
        );
        if (unauthorized && !_authRefreshAttemptedThisCycle) {
          _authRefreshAttemptedThisCycle = true;
          final refreshed = await provider(forceRefresh: true);
          if (refreshed != null && refreshed.isNotEmpty) {
            await _establish();
            return;
          }
        }
        _scheduleReconnect(unauthorized ? 'unauthorized' : 'upgrade_fail');
      } catch (e) {
        _logger.warn('connect_fail', fields: {'host': uri.host, 'err': '$e'});
        _scheduleReconnect('upgrade_fail');
      }
    } finally {
      _connecting = false;
    }
  }

  bool _isUnauthorized(WebSocketException e) {
    final m = e.message.toLowerCase();
    return m.contains('401') || m.contains('unauthorized');
  }

  void _onMessage(dynamic raw) {
    _resetLivenessTimer();
    if (raw is String) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        if (map['type'] == 'server:restarting') {
          _serverRestartPending = true;
        }
        _eventsCtrl.add(map);
      } catch (e) {
        _logger.warn('parse_fail', fields: {'err': '$e'});
      }
    }
  }

  void _onSocketTerminated({required String reason, Object? error}) {
    if (_manualDisconnect) return;
    unawaited(_enqueue(() async {
      await _tearDownChannel();
      if (_manualDisconnect || _suspended) return;
      _logger.info(
        'terminated',
        fields: {
          'reason': reason,
          if (error != null) 'err': '$error',
        },
      );
      if (_serverRestartPending) {
        _serverRestartPending = false;
        _reconnectDelaySeconds = _serverRestartReconnectDelay.inSeconds;
      }
      _scheduleReconnect(reason);
    }));
  }

  void _scheduleReconnect(String reason) {
    if (_manualDisconnect || _suspended || !_networkAvailable) return;
    _cancelReconnectTimer();
    final base = _reconnectDelaySeconds;
    final jitter = _rng.nextInt(base ~/ 2 + 1);
    final wait = base + jitter;
    final nextAt = DateTime.now().add(Duration(seconds: wait));
    _emitState(
      ConnectionState(
        status: ConnectionStatus.reconnecting,
        lastDisconnectReason: reason,
        reconnectAttempt: _state.reconnectAttempt + 1,
        nextRetryAt: nextAt,
      ),
    );
    _logger.info(
      'reconnect_scheduled',
      fields: {'wait_s': wait, 'reason': reason, 'attempt': _state.reconnectAttempt},
    );
    _reconnectTimer = Timer(Duration(seconds: wait), () {
      _reconnectTimer = null;
      if (_manualDisconnect || _suspended || !_networkAvailable) return;
      _reconnectDelaySeconds =
          (_reconnectDelaySeconds * 2).clamp(1, _maxBackoffSeconds);
      unawaited(_establish());
    });
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _resetLivenessTimer() {
    _cancelLivenessTimer();
    _livenessTimer = Timer(_livenessTimeout, () {
      _logger.warn('liveness_timeout');
      unawaited(_enqueue(() async {
        if (_manualDisconnect || _suspended) return;
        await _tearDownChannel();
        _scheduleReconnect('liveness_timeout');
      }));
    });
  }

  void _cancelLivenessTimer() {
    _livenessTimer?.cancel();
    _livenessTimer = null;
  }

  Future<void> _tearDownChannel() async {
    _cancelLivenessTimer();
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (e) {
      _logger.warn('close_fail', fields: {'err': '$e'});
    }
    _channel = null;
  }

  void sendTyping(int conversationId, bool typing) {
    _sendFrame({
      'type': 'typing',
      'payload': {'conversation_id': conversationId, 'typing': typing},
    });
  }

  void sendDeliveredAck(int conversationId, List<int> messageIds) {
    if (messageIds.isEmpty) return;
    _sendFrame({
      'type': 'receipt:delivered',
      'payload': {
        'conversation_id': conversationId,
        'message_ids': messageIds,
      },
    });
  }

  void _sendFrame(Map<String, dynamic> frame) {
    final ch = _channel;
    if (ch == null) return;
    try {
      ch.sink.add(jsonEncode(frame));
    } catch (e) {
      _logger.warn('send_fail', fields: {'err': '$e'});
    }
  }
}

/// Back-compat alias used by [ChatRepository] and [main].
typedef ChatSocket = ConnectionManager;
