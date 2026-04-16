import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

/// Backend base URL and derived WebSocket URL.
///
/// Override with `--dart-define=API_BASE_URL=https://api.example.com`
///
/// **Release discipline:** bump [expectedBackendContractTag] when adopting a
/// backend OpenAPI / behavior release the app was verified against.
class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
  });

  final String baseUrl;

  /// Human-readable contract pin (align with backend tag or release notes).
  static const String expectedBackendContractTag = 'messaging-parity-2026-04';

  /// Default dev URL when [API_BASE_URL] is unset:
  /// - **Android emulator:** `http://10.0.2.2:8080` (host loopback).
  /// - **iOS simulator / desktop:** `http://127.0.0.1:8080`.
  static ApiConfig fromEnvironment() {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    final base = fromDefine.isNotEmpty ? fromDefine : _defaultDevBaseUrl();
    return ApiConfig(baseUrl: base.replaceAll(RegExp(r'/$'), ''));
  }

  static String _defaultDevBaseUrl() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://127.0.0.1:8080';
  }

  String get wsUrl {
    final u = Uri.parse(baseUrl);
    final scheme = u.scheme == 'https' ? 'wss' : 'ws';
    return u.replace(scheme: scheme, path: '${u.path}/v1/ws').toString();
  }
}
