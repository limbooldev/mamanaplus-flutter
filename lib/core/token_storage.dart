import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const Duration _storageOpTimeout = Duration(seconds: 6);

/// Persists access + refresh tokens (not passwords).
///
/// Reads time out so a stuck platform channel cannot block startup or Dio.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _s = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  Future<void> saveTokens({required String access, required String refresh}) async {
    try {
      await _s.write(key: _kAccess, value: access).timeout(_storageOpTimeout);
      await _s.write(key: _kRefresh, value: refresh).timeout(_storageOpTimeout);
    } catch (_) {}
  }

  Future<String?> getAccessToken() async {
    try {
      return await _s.read(key: _kAccess).timeout(
            _storageOpTimeout,
            onTimeout: () => null,
          );
    } catch (_) {
      return null;
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      return await _s.read(key: _kRefresh).timeout(
            _storageOpTimeout,
            onTimeout: () => null,
          );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await Future.wait([
        _s.delete(key: _kAccess),
        _s.delete(key: _kRefresh),
      ]).timeout(_storageOpTimeout);
    } catch (_) {}
  }
}
