import 'package:flutter/material.dart';

import 'chat_day_label_chip.dart';

/// Temporary sticky day label shown at the top of the thread while scrolling.
class ThreadStickyDateHeader extends StatelessWidget {
  const ThreadStickyDateHeader({
    super.key,
    required this.visible,
    required this.label,
  });

  final bool visible;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final show = visible && label != null && label!.isNotEmpty;

    return IgnorePointer(
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        offset: show ? Offset.zero : const Offset(0, -1),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: show ? 1 : 0,
          child: Center(
            child: ChatDayLabelChip(
              label: label ?? '',
              compact: true,
            ),
          ),
        ),
      ),
    );
  }
}
