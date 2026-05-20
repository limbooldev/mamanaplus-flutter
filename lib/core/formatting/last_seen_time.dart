/// Short relative phrase for "last seen" subtitles (e.g. `5m ago`, `Yesterday`).
String formatLastSeenTime(DateTime lastSeen, {DateTime? now}) {
  final ref = (now ?? DateTime.now()).toLocal();
  final at = lastSeen.toLocal();
  final d = ref.difference(at);
  if (d.isNegative || d.inSeconds < 45) {
    return 'just now';
  }
  if (d.inMinutes < 60) {
    return '${d.inMinutes}m ago';
  }
  if (d.inHours < 24) {
    return '${d.inHours}h ago';
  }
  if (d.inDays < 7) {
    return '${d.inDays}d ago';
  }
  if (d.inDays < 365) {
    return '${(d.inDays / 7).floor()}w ago';
  }
  return '${(d.inDays / 365).floor()}y ago';
}
