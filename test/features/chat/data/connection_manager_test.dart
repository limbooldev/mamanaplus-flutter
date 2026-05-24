import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mamana_plus/core/jwt_utils.dart';
import 'package:mamana_plus/features/chat/data/connection_manager.dart';
import 'package:mamana_plus/features/chat/data/connection_state.dart';

int backoffWithJitter(int baseSeconds, Random rng) {
  return baseSeconds + rng.nextInt(baseSeconds ~/ 2 + 1);
}

void main() {
  group('backoffWithJitter', () {
    test('is capped and non-negative', () {
      final rng = Random(1);
      for (var base = 1; base <= 30; base *= 2) {
        final wait = backoffWithJitter(base, rng);
        expect(wait, greaterThanOrEqualTo(base));
        expect(wait, lessThanOrEqualTo(base + (base ~/ 2) + 1));
      }
    });
  });

  group('jwtNeedsRefresh', () {
    test('returns true for expired token', () {
      final exp = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      final payload = _b64Url(_jsonPayload(exp));
      final token = 'hdr.$payload.sig';
      expect(jwtNeedsRefresh(token), isTrue);
    });

    test('returns false for valid token', () {
      final exp = DateTime.now().toUtc().add(const Duration(hours: 1));
      final payload = _b64Url(_jsonPayload(exp));
      final token = 'hdr.$payload.sig';
      expect(jwtNeedsRefresh(token), isFalse);
    });
  });

  group('ConnectionManager', () {
    test('starts disconnected', () {
      final m = ConnectionManager();
      expect(m.isConnected, isFalse);
      expect(m.state.status, ConnectionStatus.idle);
      m.dispose();
    });
  });
}

String _jsonPayload(DateTime exp) {
  final sec = exp.millisecondsSinceEpoch ~/ 1000;
  return '{"exp":$sec}';
}

String _b64Url(String json) {
  return base64Url.encode(utf8.encode(json)).replaceAll('=', '');
}
