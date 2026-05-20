import 'package:equatable/equatable.dart';

/// Presence snapshot for a chat member (DM peer or group participant).
class MemberPresence extends Equatable {
  const MemberPresence({
    required this.online,
    this.lastSeenAt,
    this.displayName,
  });

  final bool online;
  final DateTime? lastSeenAt;
  final String? displayName;

  @override
  List<Object?> get props => [online, lastSeenAt, displayName];
}
