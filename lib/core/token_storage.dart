import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

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
  static const _kDevice = 'device_install_id';

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

  /// Stable id for push device registration (M5).
  Future<String> getOrCreateDeviceId() async {
    try {
      final existing = await _s.read(key: _kDevice).timeout(_storageOpTimeout);
      if (existing != null && existing.isNotEmpty) return existing;
      final id = const Uuid().v4();
      await _s.write(key: _kDevice, value: id).timeout(_storageOpTimeout);
      return id;
    } catch (_) {
      return const Uuid().v4();
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
