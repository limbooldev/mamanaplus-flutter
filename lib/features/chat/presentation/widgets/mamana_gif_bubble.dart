import 'package:flutter/material.dart';

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
  });

  final String url;
  final String previewUrl;
  final bool isSentByMe;
  final int? width;
  final int? height;
  final double maxWidth;
  final VoidCallback? onTap;

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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
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
        ),
      ),
    );
  }
}
