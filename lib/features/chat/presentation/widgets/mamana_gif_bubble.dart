import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

import 'message_status_icon.dart';

/// Renders a Giphy GIF or sticker URL inside a chat bubble.
class MamanaGifBubble extends StatelessWidget {
  const MamanaGifBubble({
    super.key,
    required this.url,
    required this.previewUrl,
    required this.isSentByMe,
    this.width,
    this.height,
    this.maxWidth = 280,
    this.onTap,
    this.time,
    this.status,
    this.showStatus = false,
    this.footerTextStyle,
    this.onStatusTap,
    this.senderNameHeader,
  });

  final String url;
  final String previewUrl;
  final bool isSentByMe;
  final int? width;
  final int? height;
  final double maxWidth;
  final VoidCallback? onTap;
  final DateTime? time;
  final MessageStatus? status;
  final bool showStatus;
  final TextStyle? footerTextStyle;
  final VoidCallback? onStatusTap;
  final Widget? senderNameHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubble = isSentByMe
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHigh;

    double displayW = maxWidth;
    double displayH = maxWidth * 0.56;
    if (width != null && height != null && width! > 0 && height! > 0) {
      final aspect = width! / height!;
      displayW = maxWidth;
      displayH = maxWidth / aspect;
      if (displayH > maxWidth * 1.2) {
        displayH = maxWidth * 1.2;
        displayW = displayH * aspect;
      }
    }

    final imageUrl = url.isNotEmpty ? url : previewUrl;
    final fg = isSentByMe
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;
    final footerStyle = footerTextStyle ??
        theme.textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.85));

    return Align(
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          constraints: BoxConstraints(maxWidth: maxWidth),
          decoration: BoxDecoration(
            color: bubble,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (senderNameHeader != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: senderNameHeader!,
                ),
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: senderNameHeader != null
                      ? Radius.zero
                      : const Radius.circular(12),
                  bottom: const Radius.circular(12),
                ),
                child: SizedBox(
                  width: displayW,
                  height: displayH,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      if (previewUrl.isNotEmpty && previewUrl != imageUrl) {
                        return Image.network(previewUrl, fit: BoxFit.contain);
                      }
                      return const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) =>
                        const Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                child: CustomTimeAndStatus(
                  time: time,
                  status: status,
                  showStatus: showStatus,
                  textStyle: footerStyle,
                  onStatusTap: onStatusTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
