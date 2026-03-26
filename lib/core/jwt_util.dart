import 'dart:convert';

/// Decodes JWT `sub` (user id) without verifying signature — UI only.
int? parseUserIdFromAccessToken(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    var payload = parts[1];
    final mod = payload.length % 4;
    if (mod > 0) {
      payload += '=' * (4 - mod);
    }
    final json = utf8.decode(base64Url.decode(payload));
    final map = jsonDecode(json) as Map<String, dynamic>;
    final sub = map['sub'];
    if (sub is String) return int.tryParse(sub);
    return null;
  } catch (_) {
    return null;
  }
}
