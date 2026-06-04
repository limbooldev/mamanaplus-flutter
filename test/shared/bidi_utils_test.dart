import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mamana_plus/shared/ui/ui.dart';

void main() {
  group('textDirectionFor', () {
    test('detects RTL for Arabic text', () {
      expect(textDirectionFor('مرحبا'), TextDirection.rtl);
    });

    test('detects RTL for Farsi text', () {
      expect(textDirectionFor('سلام'), TextDirection.rtl);
    });

    test('detects LTR for English text', () {
      expect(textDirectionFor('Hello'), TextDirection.ltr);
    });

    test('returns null for empty text', () {
      expect(textDirectionFor(''), isNull);
      expect(textDirectionFor('   '), isNull);
    });
  });
}
