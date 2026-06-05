import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/ui/ui.dart';

/// Centered day label pill for chat thread date dividers.
class ChatDayLabelChip extends StatelessWidget {
  const ChatDayLabelChip({
    super.key,
    required this.label,
    this.compact = false,
  });

  final String label;

  /// When true, omits vertical list spacing (for sticky overlay).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.surfaceDark.withValues(alpha: 0.92)
        : AppColors.surfaceLight.withValues(alpha: 0.92);
    final fg = isDark ? AppColors.onBackgroundDark : AppColors.subtitleLight;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 0 : 8),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
