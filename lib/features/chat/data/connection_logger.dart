import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Structured, security-safe logging for WebSocket lifecycle.
class ConnectionLogger {
  void info(String event, {Map<String, Object?> fields = const {}}) {
    final line = _format(event, fields);
    if (kDebugMode) debugPrint(line);
    _breadcrumb(line);
  }

  void warn(String event, {Map<String, Object?> fields = const {}}) {
    info(event, fields: {...fields, 'level': 'warn'});
  }

  void error(
    String event, {
    Map<String, Object?> fields = const {},
    Object? err,
  }) {
    info(event, fields: {...fields, 'level': 'error', if (err != null) 'err': '$err'});
  }

  /// SHA-256 fingerprint (first 8 hex chars) — never log full JWT.
  static String? tokenFingerprint(String? token) {
    if (token == null || token.isEmpty) return null;
    final digest = sha256.convert(utf8.encode(token));
    return digest.toString().substring(0, 8);
  }

  void _breadcrumb(String line) {
    if (Firebase.apps.isEmpty) return;
    try {
      FirebaseCrashlytics.instance.log(line);
    } catch (_) {}
  }

  String _format(String event, Map<String, Object?> fields) {
    if (fields.isEmpty) return '[ws] $event';
    final parts = fields.entries.map((e) => '${e.key}=${e.value}').join(' ');
    return '[ws] $event $parts';
  }
}
