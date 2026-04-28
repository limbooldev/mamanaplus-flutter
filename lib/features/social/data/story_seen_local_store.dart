import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'social_repository.dart';

/// Persists story media IDs whose `markStorySeen` call failed; retried on feed refresh.
class StorySeenLocalStore {
  StorySeenLocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kPending = 'social_story_seen_pending_v1';

  Set<int> get pending {
    final raw = _prefs.getString(_kPending);
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = (jsonDecode(raw) as List<dynamic>).map((e) => (e as num).toInt());
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  void addPending(Iterable<int> mediaIds) {
    final s = pending..addAll(mediaIds.where((id) => id > 0));
    _prefs.setString(_kPending, jsonEncode(s.toList()..sort()));
  }

  void removePending(Iterable<int> mediaIds) {
    final s = pending..removeAll(mediaIds);
    if (s.isEmpty) {
      _prefs.remove(_kPending);
    } else {
      _prefs.setString(_kPending, jsonEncode(s.toList()..sort()));
    }
  }

  /// Sends pending seen IDs to the server; clears those that succeed.
  Future<void> flushPending(SocialRepository repo) async {
    final ids = pending.toList();
    if (ids.isEmpty) return;
    try {
      await repo.markStorySeen(ids);
      removePending(ids);
    } catch (_) {}
  }
}
