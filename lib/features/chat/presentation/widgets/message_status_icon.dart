import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:mamana_plus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// WhatsApp-style read indicator. Sits on its own (not in [AppColors]) so the
/// colour choice is local to the chat status icon and doesn't leak into other
/// surfaces.
const Color kSeenColor = Color(0xFF34B7F1);

/// Renders our four-state status icon next to the timestamp inside a bubble:
///
/// * [MessageStatus.sending] — clock (Pending)
/// * [MessageStatus.sent] — single check
/// * [MessageStatus.delivered] — double check (`baseColor`)
/// * [MessageStatus.seen] — double check ([kSeenColor])
/// * [MessageStatus.error] — error outline
///
/// `flutter_chat_ui` ships its own [TimeAndStatus] but its `getIconForStatus`
/// helper renders [MessageStatus.sent] and [MessageStatus.delivered] with the
/// same single check, which is exactly the distinction the product wants.
class MessageStatusIcon extends StatelessWidget {
  const MessageStatusIcon({
    super.key,
    required this.status,
    required this.baseColor,
    this.seenColor = kSeenColor,
    this.size = 14,
  });

  final MessageStatus status;
  final Color baseColor;
  final Color seenColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return Icon(Icons.access_time_rounded, size: size, color: baseColor);
      case MessageStatus.sent:
        return Icon(Icons.check_rounded, size: size, color: baseColor);
      case MessageStatus.delivered:
        return Icon(Icons.done_all_rounded, size: size, color: baseColor);
      case MessageStatus.seen:
        return Icon(Icons.done_all_rounded, size: size, color: seenColor);
      case MessageStatus.error:
        return Icon(
          Icons.error_outline_rounded,
          size: size,
          color: Theme.of(context).colorScheme.error,
        );
    }
  }
}

/// Drop-in replacement for `flutter_chat_ui`'s [TimeAndStatus] that renders the
/// time alongside our [MessageStatusIcon]. Mirrors the library's row layout so
/// it slots into existing bubble builders unchanged.
class CustomTimeAndStatus extends StatelessWidget {
  const CustomTimeAndStatus({
    super.key,
    required this.time,
    this.status,
    this.showTime = true,
    this.showStatus = true,
    this.isEdited = false,
    this.textStyle,
    this.onStatusTap,
  });

  final DateTime? time;
  final MessageStatus? status;
  final bool showTime;
  final bool showStatus;
  final bool isEdited;
  final TextStyle? textStyle;
  /// When set, the status icon becomes tappable (e.g. group read-receipt list).
  final VoidCallback? onStatusTap;

  @override
  Widget build(BuildContext context) {
    // Use the library's ambient DateFormat so chat formatting stays consistent
    // with the rest of `flutter_chat_ui`.
    final timeFormat = context.watch<DateFormat>();
    final color =
        textStyle?.color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    final l10n = AppLocalizations.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isEdited && l10n != null)
          Text('${l10n.messageEdited} · ', style: textStyle),
        if (showTime && time != null)
          Text(timeFormat.format(time!.toLocal()), style: textStyle),
        if (showStatus && status != null) ...[
          const SizedBox(width: 4),
          if (onStatusTap != null)
            GestureDetector(
              onTap: onStatusTap,
              behavior: HitTestBehavior.opaque,
              child: MessageStatusIcon(status: status!, baseColor: color),
            )
          else
            MessageStatusIcon(status: status!, baseColor: color),
        ],
      ],
    );
  }
}
