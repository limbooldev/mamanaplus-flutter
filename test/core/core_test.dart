import 'package:flutter_test/flutter_test.dart';
import 'package:mamana_plus/core/api_config.dart';

void main() {
  test('ApiConfig wsUri uses ws and port for http', () {
    final c = ApiConfig(baseUrl: 'http://localhost:8080');
    expect(c.wsUri.scheme, 'ws');
    expect(c.wsUri.port, 8080);
    expect(c.wsUri.path, '/v1/ws');
  });

  test('ApiConfig wsUri uses wss and explicit 443 for implicit https', () {
    final c = ApiConfig(baseUrl: 'https://mamana.getapi.cloud');
    expect(c.wsUri.scheme, 'wss');
    expect(c.wsUri.port, 443);
    expect(c.wsUri.path, '/v1/ws');
  });
}
