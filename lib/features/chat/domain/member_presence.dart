import 'package:equatable/equatable.dart';

/// Presence snapshot for a chat member (DM peer or group participant).
class MemberPresence extends Equatable {
  const MemberPresence({
    required this.online,
    this.lastSeenAt,
    this.displayName,
    this.avatarMediaKey,
  });

  final bool online;
  final DateTime? lastSeenAt;
  final String? displayName;
  final String? avatarMediaKey;

  @override
  List<Object?> get props => [online, lastSeenAt, displayName, avatarMediaKey];
}
