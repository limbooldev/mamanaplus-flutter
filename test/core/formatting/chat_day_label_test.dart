import 'package:flutter_test/flutter_test.dart';
import 'package:mamana_plus/core/formatting/chat_day_label.dart';

void main() {
  group('isSameCalendarDay', () {
    test('same day different times', () {
      expect(
        isSameCalendarDay(
          DateTime(2026, 5, 29, 8, 0),
          DateTime(2026, 5, 29, 22, 30),
        ),
        isTrue,
      );
    });

    test('different days', () {
      expect(
        isSameCalendarDay(
          DateTime(2026, 5, 28, 23, 59),
          DateTime(2026, 5, 29, 0, 1),
        ),
        isFalse,
      );
    });
  });

  group('formatChatDayLabel', () {
    const today = 'Today';
    const yesterday = 'Yesterday';
    final now = DateTime(2026, 5, 29, 15, 0);

    test('same calendar day shows Today', () {
      expect(
        formatChatDayLabel(
          DateTime(2026, 5, 29, 9, 0),
          todayLabel: today,
          yesterdayLabel: yesterday,
          now: now,
          locale: 'en_US',
        ),
        today,
      );
    });

    test('previous calendar day shows Yesterday', () {
      expect(
        formatChatDayLabel(
          DateTime(2026, 5, 28, 9, 0),
          todayLabel: today,
          yesterdayLabel: yesterday,
          now: now,
          locale: 'en_US',
        ),
        yesterday,
      );
    });

    test('same week earlier day shows weekday name', () {
      // Thursday ref; Monday same week
      final thursday = DateTime(2026, 5, 28, 12, 0);
      final monday = DateTime(2026, 5, 25, 10, 0);
      final s = formatChatDayLabel(
        monday,
        todayLabel: today,
        yesterdayLabel: yesterday,
        now: thursday,
        locale: 'en_US',
      );
      expect(s.toLowerCase(), contains('monday'));
    });

    test('outside current week shows MMM d, yyyy', () {
      final s = formatChatDayLabel(
        DateTime(2026, 4, 10, 8, 0),
        todayLabel: today,
        yesterdayLabel: yesterday,
        now: now,
        locale: 'en_US',
      );
      expect(s, 'Apr 10, 2026');
    });
  });
}
