import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The six quick-react emojis shown in the floating picker row.
const List<String> kQuickReactEmojis = ['❤️', '😂', '😮', '😢', '🙏', '👍'];

/// A WhatsApp/Telegram-style emoji reaction picker displayed as a full-screen
/// overlay when the user long-presses a message.
///
/// Shows:
/// - A blurred, dimmed backdrop (tap to dismiss)
/// - A floating pill of [kQuickReactEmojis] above or below the message position
/// - A rounded action card with contextual options (reply, copy, edit, delete…)
///
/// Usage:
/// ```dart
/// final picked = await showEmojiReactionPicker(
///   context: context,
///   messagePosition: rect,
///   isSentByMe: true,
///   actions: [
///     ReactionPickerAction(label: 'Reply', icon: Icons.reply_rounded, value: 'reply'),
///   ],
///   currentReactions: state.reactions[messageId] ?? [],
///   myUserId: myUserId,
/// );
/// if (picked is String) { /* action value */ }
/// if (picked is _EmojiPick) { /* emoji toggle */ }
/// ```
Future<Object?> showEmojiReactionPicker({
  required BuildContext context,
  required Rect messagePosition,
  required bool isSentByMe,
  required List<ReactionPickerAction> actions,
  required List<String> currentUserEmojis,
}) {
  return Navigator.of(context, rootNavigator: true).push<Object?>(
    _EmojiPickerRoute(
      messagePosition: messagePosition,
      isSentByMe: isSentByMe,
      actions: actions,
      currentUserEmojis: currentUserEmojis,
    ),
  );
}

/// An action item shown in the bottom card of the picker.
class ReactionPickerAction {
  const ReactionPickerAction({
    required this.label,
    required this.icon,
    required this.value,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final String value;
  final bool isDestructive;
}

/// Internal route — slides in instantly (no animation on the overlay itself;
/// the individual widgets animate independently).
class _EmojiPickerRoute extends PopupRoute<Object?> {
  _EmojiPickerRoute({
    required this.messagePosition,
    required this.isSentByMe,
    required this.actions,
    required this.currentUserEmojis,
  });

  final Rect messagePosition;
  final bool isSentByMe;
  final List<ReactionPickerAction> actions;
  final List<String> currentUserEmojis;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _EmojiPickerOverlay(
      animation: animation,
      messagePosition: messagePosition,
      isSentByMe: isSentByMe,
      actions: actions,
      currentUserEmojis: currentUserEmojis,
    );
  }
}

class _EmojiPickerOverlay extends StatelessWidget {
  const _EmojiPickerOverlay({
    required this.animation,
    required this.messagePosition,
    required this.isSentByMe,
    required this.actions,
    required this.currentUserEmojis,
  });

  final Animation<double> animation;
  final Rect messagePosition;
  final bool isSentByMe;
  final List<ReactionPickerAction> actions;
  final List<String> currentUserEmojis;

  static const double _pillHeight = 56.0;
  static const double _pillPad = 8.0;
  static const double _gap = 6.0;
  static const double _actionCardMinWidth = 200.0;
  static const double _actionCardMaxWidth = 280.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final screenW = mq.size.width;
    final safeTop = mq.padding.top;

    // Decide whether the emoji pill fits above the bubble.
    final spaceAbove = messagePosition.top - safeTop;
    final pillAbove = spaceAbove >= _pillHeight + _gap * 2;

    final pillTop = pillAbove
        ? messagePosition.top - _pillHeight - _gap
        : messagePosition.bottom + _gap;

    // Clamp horizontally so pill never clips screen edges.
    final pillW = kQuickReactEmojis.length * (_pillHeight - _pillPad * 2 + 4) +
        _pillPad * 2 +
        16;
    double pillLeft = isSentByMe
        ? messagePosition.right - pillW
        : messagePosition.left;
    pillLeft = pillLeft.clamp(8.0, screenW - pillW - 8.0);

    // Action card below (or above) the bubble.
    final cardBelow = messagePosition.bottom + _gap * 2 + 48 < screenH;
    const cardW = _actionCardMaxWidth;
    double cardLeft = isSentByMe ? messagePosition.right - cardW : messagePosition.left;
    cardLeft = cardLeft.clamp(8.0, screenW - cardW - 8.0);
    final cardTop = cardBelow
        ? (pillAbove ? messagePosition.bottom + _gap : pillTop + _pillHeight + _gap)
        : messagePosition.top - (actions.length * 52.0 + 16) - _gap;

    return FadeTransition(
      opacity: animation,
      child: Stack(
        children: [
          // Blurred backdrop — tap to dismiss.
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),

          // Emoji pill.
          Positioned(
            left: pillLeft,
            top: pillTop.clamp(safeTop + 4, screenH - _pillHeight - 8),
            child: ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
              child: _EmojiPill(
                currentUserEmojis: currentUserEmojis,
                onEmojiTap: (emoji) {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop(_EmojiPick(emoji));
                },
              ),
            ),
          ),

          // Action card.
          Positioned(
            left: cardLeft,
            top: cardTop.clamp(safeTop + 4, screenH - (actions.length * 52.0 + 24) - 8),
            width: cardW.clamp(_actionCardMinWidth, _actionCardMaxWidth),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.15),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
              child: _ActionCard(
                actions: actions,
                onAction: (value) => Navigator.of(context).pop(value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The rounded pill that shows the 6 emoji buttons.
class _EmojiPill extends StatelessWidget {
  const _EmojiPill({
    required this.currentUserEmojis,
    required this.onEmojiTap,
  });

  final List<String> currentUserEmojis;
  final void Function(String emoji) onEmojiTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(32),
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: kQuickReactEmojis.map((emoji) {
            final selected = currentUserEmojis.contains(emoji);
            return _EmojiButton(
              emoji: emoji,
              selected: selected,
              onTap: () => onEmojiTap(emoji),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _EmojiButton extends StatefulWidget {
  const _EmojiButton({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_EmojiButton> createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<_EmojiButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.85,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _ctrl;
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
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.selected
                ? theme.colorScheme.primary.withValues(alpha: 0.18)
                : Colors.transparent,
          ),
          child: Center(
            child: Text(
              widget.emoji,
              style: TextStyle(
                fontSize: widget.selected ? 26 : 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The rounded card that shows action list items (Reply, Copy, Edit…).
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.actions, required this.onAction});

  final List<ReactionPickerAction> actions;
  final void Function(String value) onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surfaceContainerHigh,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(actions.length, (i) {
            final action = actions[i];
            final color = action.isDestructive
                ? theme.colorScheme.error
                : theme.colorScheme.onSurface;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: theme.dividerColor.withValues(alpha: 0.5),
                    indent: 16,
                    endIndent: 16,
                  ),
                InkWell(
                  onTap: () => onAction(action.value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(action.icon, size: 20, color: color),
                        const SizedBox(width: 12),
                        Text(
                          action.label,
                          style: theme.textTheme.bodyMedium?.copyWith(color: color),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Token returned when the user picks an emoji (vs. an action string).
class _EmojiPick {
  const _EmojiPick(this.emoji);
  final String emoji;
}

/// Helper to check if a picker result is an emoji pick.
bool isEmojiPick(Object? result) => result is _EmojiPick;

/// Extract the emoji from a picker result (call only after [isEmojiPick]).
String emojiFromPick(Object result) => (result as _EmojiPick).emoji;
