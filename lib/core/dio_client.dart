import 'package:dio/dio.dart';

import 'api_config.dart';
import 'token_storage.dart';

bool _isPublicAuthPath(String path) {
  return path.endsWith('/v1/auth/login') ||
      path.endsWith('/v1/auth/register') ||
      path.endsWith('/v1/auth/refresh');
}

/// Configured Dio with auth + refresh on 401.
Dio createDio({
  required ApiConfig config,
  required TokenStorage tokens,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final path = options.uri.path;
        if (!_isPublicAuthPath(path)) {
          final t = await tokens.getAccessToken();
          if (t != null && t.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $t';
          }
        }
        handler.next(options);
      },
      onError: (err, handler) async {
        if (err.response?.statusCode == 401) {
          final path = err.requestOptions.uri.path;
          if (_isPublicAuthPath(path)) {
            handler.next(err);
            return;
          }
          final refreshed = await _tryRefresh(config, tokens);
          if (refreshed) {
            final opts = err.requestOptions;
            final t = await tokens.getAccessToken();
            opts.headers['Authorization'] = 'Bearer $t';
            final clone = await dio.fetch(opts);
            return handler.resolve(clone);
          }
          await tokens.clear();
        }
        handler.next(err);
      },
    ),
  );

  return dio;
}

Future<bool> _tryRefresh(ApiConfig config, TokenStorage tokens) async {
  final refresh = await tokens.getRefreshToken();
  if (refresh == null || refresh.isEmpty) return false;
  try {
    final plain = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: const Duration(seconds: 15),
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
    return true;
  } catch (_) {
    return false;
  }
}
