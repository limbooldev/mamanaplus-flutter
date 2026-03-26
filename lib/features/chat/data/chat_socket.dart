import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';

/// WebSocket client for chat events (`api/websocket.md`).
class ChatSocket {
  IOWebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _controller.stream;

  void connect(String wsUrl, String accessToken) {
    disconnect();
    _channel = IOWebSocketChannel.connect(
      Uri.parse(wsUrl),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    _sub = _channel!.stream.listen(
      (dynamic raw) {
        if (raw is String) {
          try {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            _controller.add(map);
          } catch (_) {}
        }
      },
      onError: (_) {},
      onDone: () {},
    );
  }

  void sendTyping(int conversationId, bool typing) {
    final payload = jsonEncode({
      'type': 'typing',
      'payload': {'conversation_id': conversationId, 'typing': typing},
    });
    _channel?.sink.add(payload);
  }

  void disconnect() {
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
