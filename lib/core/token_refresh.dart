import 'package:dio/dio.dart';

import 'api_config.dart';
import 'token_storage.dart';

/// Single-flight refresh shared by Dio and the WebSocket connection manager.
Future<bool>? _refreshInProgress;

Future<bool> refreshAccessToken({
  required ApiConfig config,
  required TokenStorage tokens,
  void Function(String accessToken)? onAccessTokenRefreshed,
}) {
  final existing = _refreshInProgress;
  if (existing != null) return existing;
  final f = _doRefresh(config, tokens, onAccessTokenRefreshed).whenComplete(() {
    _refreshInProgress = null;
  });
  _refreshInProgress = f;
  return f;
}

Future<bool> _doRefresh(
  ApiConfig config,
  TokenStorage tokens,
  void Function(String accessToken)? onAccessTokenRefreshed,
) async {
  final refresh = await tokens.getRefreshToken();
  if (refresh == null || refresh.isEmpty) return false;
  try {
    final plain = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
    );
    final res = await plain.post<Map<String, dynamic>>(
      '/v1/auth/refresh',
      data: {'refresh_token': refresh},
    );
    final data = res.data;
    if (data == null) return false;
    final access = data['access_token'] as String?;
    final next = data['refresh_token'] as String?;
    if (access == null || next == null) return false;
    await tokens.saveTokens(access: access, refresh: next);
    onAccessTokenRefreshed?.call(access);
    return true;
  } catch (_) {
    return false;
  }
}
