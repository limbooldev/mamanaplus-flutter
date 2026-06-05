import 'package:intl/intl.dart';

/// Calendar date at local midnight (ignores time-of-day).
DateTime dateOnlyLocal(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Monday 00:00 local of the ISO week containing [date] (Mon=first day).
DateTime mondayOfWeekLocal(DateTime date) {
  final d = dateOnlyLocal(date);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

/// Whether [a] and [b] fall on the same local calendar day.
bool isSameCalendarDay(DateTime a, DateTime b) {
  return dateOnlyLocal(a) == dateOnlyLocal(b);
}

/// WhatsApp-style day label for chat date dividers.
///
/// Rules (relative to [now], default `DateTime.now()`, all in local time):
/// 1. Same calendar day → [todayLabel].
/// 2. Previous calendar day → [yesterdayLabel].
/// 3. Same ISO week (Mon–Sun), not today/yesterday → full weekday (e.g. Wednesday).
/// 4. Otherwise → `MMM d, yyyy` (e.g. May 29, 2026).
String formatChatDayLabel(
  DateTime date, {
  required String todayLabel,
  required String yesterdayLabel,
  DateTime? now,
  String? locale,
}) {
  final ref = (now ?? DateTime.now()).toLocal();
  final msg = date.toLocal();
  final refDay = dateOnlyLocal(ref);
  final msgDay = dateOnlyLocal(msg);
  final loc = locale ?? Intl.defaultLocale ?? 'en';

  if (msgDay == refDay) {
    return todayLabel;
  }

  if (msgDay == refDay.subtract(const Duration(days: 1))) {
    return yesterdayLabel;
  }

  if (mondayOfWeekLocal(msgDay) == mondayOfWeekLocal(refDay)) {
    return DateFormat('EEEE', loc).format(msg);
  }

  return DateFormat('MMM d, yyyy', loc).format(msg);
}
