import 'package:dio/dio.dart';

import 'api_config.dart';
import 'token_storage.dart';

/// [RequestOptions.extra] flag: set before retry after refresh to avoid refresh loops.
const String kAuthRetriedExtraKey = 'auth_retried';

bool _isPublicAuthPath(String path) {
  return path.endsWith('/v1/auth/login') ||
      path.endsWith('/v1/auth/register') ||
      path.endsWith('/v1/auth/refresh');
}

/// Single-flight refresh across all [createDio] instances (matches server refresh rotation).
Future<bool>? _refreshInProgress;

Future<bool> _runSingleFlightRefresh(Future<bool> Function() run) {
  final existing = _refreshInProgress;
  if (existing != null) return existing;
  final f = run().whenComplete(() {
    _refreshInProgress = null;
  });
  _refreshInProgress = f;
  return f;
}

/// Configured Dio with auth + refresh on 401.
Dio createDio({
  required ApiConfig config,
  required TokenStorage tokens,
  void Function(String accessToken)? onAccessTokenRefreshed,
  void Function()? onSessionExpired,
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
        if (err.response?.statusCode != 401) {
          handler.next(err);
          return;
        }
        final opts = err.requestOptions;
        final path = opts.uri.path;
        if (_isPublicAuthPath(path)) {
          handler.next(err);
          return;
        }
        if (opts.extra[kAuthRetriedExtraKey] == true) {
          await tokens.clear();
          onSessionExpired?.call();
          handler.next(err);
          return;
        }

        final refreshed = await _runSingleFlightRefresh(
          () => _tryRefresh(
            config,
            tokens,
            onAccessTokenRefreshed,
          ),
        );
        if (refreshed) {
          final t = await tokens.getAccessToken();
          opts.headers['Authorization'] = 'Bearer $t';
          opts.extra[kAuthRetriedExtraKey] = true;
          try {
            final response = await dio.fetch(opts);
            return handler.resolve(response);
          } catch (e) {
            if (e is DioException &&
                e.response?.statusCode == 401 &&
                e.requestOptions.extra[kAuthRetriedExtraKey] == true) {
              await tokens.clear();
              onSessionExpired?.call();
            }
            if (e is DioException) {
              return handler.next(e);
            }
            return handler.next(
              DioException(
                requestOptions: opts,
                error: e,
              ),
            );
          }
        }
        await tokens.clear();
        onSessionExpired?.call();
        handler.next(err);
      },
    ),
  );

  return dio;
}

Future<bool> _tryRefresh(
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
    onAccessTokenRefreshed?.call(access);
    return true;
  } catch (_) {
    return false;
  }
}
