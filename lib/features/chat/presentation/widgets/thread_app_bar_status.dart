import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mamana_plus/l10n/app_localizations.dart';

import '../../../../core/formatting/last_seen_time.dart';
import '../../../../shared/ui/ui.dart';
import '../../domain/member_presence.dart';
import 'typing_dots.dart';

/// Subtitle under the thread AppBar title: typing, online, or last seen.
class ThreadAppBarStatus extends StatelessWidget {
  const ThreadAppBarStatus({
    super.key,
    required this.isGroup,
    required this.typingUserIds,
    required this.myUserId,
    this.dmPeerUserId,
    this.peerOnline,
    this.peerLastSeenAt,
    this.memberPresence = const {},
    this.subtitleColor,
  });

  final bool isGroup;
  final Set<int> typingUserIds;
  final int myUserId;
  final int? dmPeerUserId;
  final bool? peerOnline;
  final DateTime? peerLastSeenAt;
  final Map<int, MemberPresence> memberPresence;
  final Color? subtitleColor;

  Set<int> get _othersTyping =>
      typingUserIds.where((id) => id != myUserId).toSet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = subtitleColor ?? AppColors.subtitleLight;
    final style = GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: color,
      height: 1.2,
    );

    if (isGroup) {
      final typing = _othersTyping.toList();
      if (typing.isNotEmpty) {
        final label = _groupTypingLabel(l10n, typing);
        return _typingRow(style, color, label);
      }
      final members = memberPresence.length;
      if (members > 0) {
        final online =
            memberPresence.values.where((p) => p.online).length;
        return Text(
          l10n.chatStatusMembersOnline(members, online),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      }
      return const SizedBox.shrink();
    }

    // Private DM
    final peerId = dmPeerUserId;
    if (peerId != null && _othersTyping.contains(peerId)) {
      return _typingRow(style, color, l10n.chatStatusTyping);
    }
    if (peerOnline == true) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            l10n.chatStatusOnline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ],
      );
    }
    if (peerLastSeenAt != null) {
      final time = formatLastSeenTime(peerLastSeenAt!);
      return Text(
        l10n.chatStatusLastSeen(time),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return const SizedBox.shrink();
  }

  String _groupTypingLabel(AppLocalizations l10n, List<int> typing) {
    if (typing.length == 1) {
      final id = typing.first;
      final name = memberPresence[id]?.displayName?.trim();
      if (name != null && name.isNotEmpty) {
        return l10n.chatStatusOneTyping(name);
      }
      return l10n.chatStatusTyping;
    }
    return l10n.chatStatusManyTyping(typing.length);
  }

  Widget _typingRow(TextStyle style, Color dotColor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: 4),
        TypingDots(size: 5, color: dotColor, spacing: 2),
      ],
    );
  }
}
