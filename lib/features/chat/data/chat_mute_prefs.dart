import 'package:shared_preferences/shared_preferences.dart';

/// Local-only per-conversation mute (product-aligned with push prefs; server may extend later).
class ChatMutePrefs {
  ChatMutePrefs(this._p);

  final SharedPreferences _p;

  static String _key(int conversationId) => 'chat_mute_$conversationId';

  bool isMuted(int conversationId) => _p.getBool(_key(conversationId)) ?? false;

  Future<void> setMuted(int conversationId, bool muted) async {
    if (muted) {
      await _p.setBool(_key(conversationId), true);
    } else {
      await _p.remove(_key(conversationId));
    }
  }
}
