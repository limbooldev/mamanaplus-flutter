/// Realtime WebSocket connection lifecycle (see `ConnectionManager`).
enum ConnectionStatus {
  idle,
  connecting,
  connected,
  reconnecting,
  suspended,
  disconnected,
}

/// Snapshot exposed on [ConnectionManager.stateStream].
class ConnectionState {
  const ConnectionState({
    required this.status,
    this.lastDisconnectReason,
    this.reconnectAttempt = 0,
    this.nextRetryAt,
  });

  final ConnectionStatus status;
  final String? lastDisconnectReason;
  final int reconnectAttempt;
  final DateTime? nextRetryAt;

  ConnectionState copyWith({
    ConnectionStatus? status,
    String? lastDisconnectReason,
    int? reconnectAttempt,
    DateTime? nextRetryAt,
    bool clearNextRetryAt = false,
  }) {
    return ConnectionState(
      status: status ?? this.status,
      lastDisconnectReason: lastDisconnectReason ?? this.lastDisconnectReason,
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
      nextRetryAt: clearNextRetryAt ? null : (nextRetryAt ?? this.nextRetryAt),
    );
  }
}

/// Provides access tokens for WebSocket upgrade; [forceRefresh] runs Dio refresh.
typedef AccessTokenProvider = Future<String?> Function({bool forceRefresh});
