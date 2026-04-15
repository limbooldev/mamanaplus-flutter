import 'package:flutter_test/flutter_test.dart';
import 'package:mamana_plus/core/formatting/relative_message_time.dart';

void main() {
  group('formatRelativeMessageTime', () {
    test('same calendar day shows time only', () {
      final now = DateTime(2026, 4, 14, 15, 30);
      final msg = DateTime(2026, 4, 14, 9, 5);
      final s = formatRelativeMessageTime(
        msg,
        now: now,
        locale: 'en_US',
      );
      expect(s, isNot(contains('2026')));
      expect(s, isNot(contains('Apr')));
      expect(s, isNot(contains('Mon')));
    });

    test('earlier this week shows short weekday', () {
      // Wednesday ref, Monday same week
      final now = DateTime(2026, 4, 15, 12, 0);
      final msg = DateTime(2026, 4, 13, 10, 0);
      final s = formatRelativeMessageTime(
        msg,
        now: now,
        locale: 'en_US',
      );
      expect(s.toLowerCase(), contains('mon'));
    });

    test('same year but not this week shows month and day', () {
      final now = DateTime(2026, 4, 14, 12, 0);
      final msg = DateTime(2026, 3, 1, 8, 0);
      final s = formatRelativeMessageTime(
        msg,
        now: now,
        locale: 'en_US',
      );
      expect(s, contains('Mar'));
      expect(s, contains('1'));
    });

    test('previous year shows dd.MM.yyyy', () {
      final now = DateTime(2026, 4, 14, 12, 0);
      final msg = DateTime(2025, 5, 21, 8, 0);
      final s = formatRelativeMessageTime(
        msg,
        now: now,
        locale: 'en_US',
      );
      expect(s, '21.05.2025');
    });
  });
}
