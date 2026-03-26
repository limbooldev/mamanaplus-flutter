/// Backend base URL and derived WebSocket URL.
///
/// Override with `--dart-define=API_BASE_URL=https://api.example.com`
class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
  });

  final String baseUrl;

  /// Android emulator → host machine (default). iOS simulator: `http://127.0.0.1:8080`.
  static ApiConfig fromEnvironment() {
    const base = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8080',
    );
    return ApiConfig(baseUrl: base.replaceAll(RegExp(r'/$'), ''));
  }

  String get wsUrl {
    final u = Uri.parse(baseUrl);
    final scheme = u.scheme == 'https' ? 'wss' : 'ws';
    return u.replace(scheme: scheme, path: '${u.path}/v1/ws').toString();
  }
}
