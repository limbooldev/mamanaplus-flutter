import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kProfileMode, kReleaseMode;

/// Backend base URL and derived WebSocket URL.
///
/// Override with `--dart-define=API_BASE_URL=https://api.example.com`
///
/// When unset, **release** and **profile** builds use the deployed backend;
/// **debug** uses the local emulator defaults below.
///
/// **Release discipline:** bump [expectedBackendContractTag] when adopting a
/// backend OpenAPI / behavior release the app was verified against.
class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
  });

  final String baseUrl;

  /// Human-readable contract pin (align with backend tag or release notes).
  static const String expectedBackendContractTag = 'social-v1-2026-04';

  /// Default dev URL when [API_BASE_URL] is unset:
  /// - **Android emulator:** `http://10.0.2.2:8080` (host loopback).
  /// - **iOS simulator / desktop:** `http://127.0.0.1:8080`.
  static const String _productionBaseUrl = 'https://mamana.getapi.cloud';

  static ApiConfig fromEnvironment() {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    final String base;
    if (fromDefine.isNotEmpty) {
      base = fromDefine;
    } else if (kReleaseMode || kProfileMode) {
      base = _productionBaseUrl;
    } else {
      base = _productionBaseUrl;
    }
    return ApiConfig(baseUrl: base.replaceAll(RegExp(r'/$'), ''));
  }

  static String _defaultDevBaseUrl() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://127.0.0.1:8080';
  }

  /// Chat WebSocket endpoint derived from [baseUrl].
  ///
  /// Returned as a [Uri] (not a string) so the socket layer keeps a non-zero
  /// port: a `wss://host/path` string re-parsed on some SDKs yields
  /// [Uri.port] == 0 and the client dials `:0`.
  Uri get wsUri {
    final u = Uri.parse(baseUrl);
    final scheme = u.scheme == 'https' ? 'wss' : 'ws';
    final path = u.path.endsWith('/') ? '${u.path}v1/ws' : '${u.path}/v1/ws';
    final int port;
    if (u.hasPort && u.port != 0) {
      port = u.port;
    } else if (scheme == 'wss') {
      port = 443;
    } else {
      port = 80;
    }
    return Uri(
      scheme: scheme,
      host: u.host,
      port: port,
      path: path,
      queryParameters: u.queryParameters.isEmpty ? null : u.queryParameters,
    );
  }
}
