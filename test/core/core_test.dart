import 'package:flutter_test/flutter_test.dart';
import 'package:mamana_plus/core/api_config.dart';

void main() {
  test('ApiConfig wsUrl uses ws for http', () {
    final c = ApiConfig(baseUrl: 'http://localhost:8080');
    expect(c.wsUrl.startsWith('ws://'), isTrue);
    expect(c.wsUrl.contains('/v1/ws'), isTrue);
  });
}
