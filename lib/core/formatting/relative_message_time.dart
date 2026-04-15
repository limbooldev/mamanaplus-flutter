import 'package:intl/intl.dart';

/// Calendar date at local midnight (ignores time-of-day).
DateTime _dateOnlyLocal(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Monday 00:00 local of the ISO week containing [date] (Mon=first day).
DateTime _mondayOfWeekLocal(DateTime date) {
  final d = _dateOnlyLocal(date);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

/// Compact timestamp for chat lists, previews, and similar UI.
///
/// Rules (relative to [now], default `DateTime.now()`, all in local time):
/// 1. Same calendar day → time only (locale-aware, e.g. `3:45 PM`).
/// 2. Before today but same ISO calendar week → short weekday (e.g. `Tue`).
/// 3. Same calendar year, not covered above → month + day (e.g. `Apr 16`).
/// 4. Earlier calendar year → `dd.MM.yyyy` (e.g. `21.05.2025`).
String formatRelativeMessageTime(
  DateTime message, {
  DateTime? now,
  String? locale,
}) {
  final ref = (now ?? DateTime.now()).toLocal();
  final msg = message.toLocal();
  final refDay = _dateOnlyLocal(ref);
  final msgDay = _dateOnlyLocal(msg);
  final loc = locale ?? Intl.defaultLocale ?? 'en';

  if (msgDay == refDay) {
    return DateFormat.jm(loc).format(msg);
  }

  final sameWeek =
      _mondayOfWeekLocal(msgDay) == _mondayOfWeekLocal(refDay);
  if (msgDay.isBefore(refDay) && sameWeek) {
    return DateFormat('EEE', loc).format(msg);
  }

  if (msg.year == ref.year) {
    return DateFormat.MMMd(loc).format(msg);
  }

  return DateFormat('dd.MM.yyyy', loc).format(msg);
}
