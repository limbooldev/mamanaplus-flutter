import 'dart:convert';

/// Seconds since epoch from JWT `exp`, or null if unparsable.
int? jwtExpiresAtEpochSeconds(String token) {
  final parts = token.split('.');
  if (parts.length < 2) return null;
  try {
    var payload = parts[1];
    final pad = payload.length % 4;
    if (pad > 0) payload += '=' * (4 - pad);
    final json = utf8.decode(base64Url.decode(payload));
    final map = jsonDecode(json) as Map<String, dynamic>;
    final exp = map['exp'];
    if (exp is int) return exp;
    if (exp is num) return exp.toInt();
  } catch (_) {}
  return null;
}

/// True when [token] is missing, expired, or expires within [skew].
bool jwtNeedsRefresh(
  String? token, {
  Duration skew = const Duration(seconds: 30),
}) {
  if (token == null || token.isEmpty) return true;
  final exp = jwtExpiresAtEpochSeconds(token);
  if (exp == null) return false;
  final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  return DateTime.now().toUtc().isAfter(expiresAt.subtract(skew));
}
