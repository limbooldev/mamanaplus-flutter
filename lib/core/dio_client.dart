import 'package:dio/dio.dart';

import 'api_config.dart';
import 'token_refresh.dart';
import 'token_storage.dart';

/// [RequestOptions.extra] flag: set before retry after refresh to avoid refresh loops.
const String kAuthRetriedExtraKey = 'auth_retried';

bool _isPublicAuthPath(String path) {
  return path.endsWith('/v1/auth/login') ||
      path.endsWith('/v1/auth/register') ||
      path.endsWith('/v1/auth/refresh');
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
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
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

        final refreshed = await refreshAccessToken(
          config: config,
          tokens: tokens,
          onAccessTokenRefreshed: onAccessTokenRefreshed,
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

