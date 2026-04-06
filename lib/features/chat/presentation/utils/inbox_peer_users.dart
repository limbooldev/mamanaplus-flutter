import 'dart:convert';

import '../../../../core/database/app_database.dart';

/// DM peer parsed from cached conversation [peer] JSON.
class InboxPeerUser {
  const InboxPeerUser({required this.id, required this.displayName});

  final int id;
  final String displayName;
}

/// De-duplicated DM peers from local inbox rows (private conversations only).
List<InboxPeerUser> dmPeersFromConversations(
  List<LocalConversation> items, {
  Set<int> excludeUserIds = const {},
}) {
  final seen = <int>{};
  final out = <InboxPeerUser>[];
  for (final c in items) {
    if (c.type != 'private' || c.peerJson == null) continue;
    try {
      final m = jsonDecode(c.peerJson!) as Map<String, dynamic>;
      final id = (m['id'] as num?)?.toInt();
      if (id == null || excludeUserIds.contains(id) || seen.contains(id)) {
        continue;
      }
      seen.add(id);
      final name = (m['display_name'] as String?)?.trim() ?? '';
      out.add(InboxPeerUser(id: id, displayName: name));
    } catch (_) {}
  }
  return out;
}

List<InboxPeerUser> filterPeersByQuery(List<InboxPeerUser> peers, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return peers;
  return peers.where((p) {
    return p.displayName.toLowerCase().contains(q) || p.id.toString().contains(q);
  }).toList();
}
