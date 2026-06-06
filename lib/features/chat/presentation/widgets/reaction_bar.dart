import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../cubit/thread_cubit.dart';

/// Displays a row of grouped emoji reaction chips below a message bubble.
///
/// Each chip shows the emoji and the count of users who reacted with it.
/// The chip is highlighted if [myUserId] is among the reactors.
/// Tapping a chip calls [onToggle] to add or remove the current user's reaction.
class ReactionBar extends StatelessWidget {
  const ReactionBar({
    super.key,
    required this.reactions,
    required this.myUserId,
    required this.isSentByMe,
    required this.onToggle,
  });

  final List<MessageReaction> reactions;
  final int myUserId;
  final bool isSentByMe;
  final void Function(String emoji) onToggle;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    // Group reactions by emoji, preserving insertion order.
    final groups = <String, List<MessageReaction>>{};
    for (final r in reactions) {
      if (r.emoji.isNotEmpty) {
        (groups[r.emoji] ??= []).add(r);
      }
    }
    if (groups.isEmpty) return const SizedBox.shrink();

    final chips = groups.entries.map((entry) {
      final emoji = entry.key;
      final reactors = entry.value;
      final isMine = reactors.any((r) => r.userId == myUserId);
      return _ReactionChip(
        emoji: emoji,
        count: reactors.length,
        isMine: isMine,
        onTap: () {
          HapticFeedback.selectionClick();
          onToggle(emoji);
        },
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Align(
        alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: isSentByMe ? WrapAlignment.end : WrapAlignment.start,
          children: chips,
        ),
      ),
    );
  }
}

class _ReactionChip extends StatefulWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.isMine,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool isMine;
  final VoidCallback onTap;

  @override
  State<_ReactionChip> createState() => _ReactionChipState();
}

class _ReactionChipState extends State<_ReactionChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    await _ctrl.reverse();
    await _ctrl.forward();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bgColor = widget.isMine
        ? cs.primary.withValues(alpha: 0.15)
        : cs.surfaceContainerHighest;
    final borderColor = widget.isMine
        ? cs.primary.withValues(alpha: 0.6)
        : cs.outlineVariant;

    return ScaleTransition(
      scale: _ctrl,
      child: GestureDetector(
        onTap: _onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 15)),
              if (widget.count > 1) ...[
                const SizedBox(width: 4),
                Text(
                  '${widget.count}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: widget.isMine ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
