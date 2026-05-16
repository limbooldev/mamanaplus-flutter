import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../media_constants.dart';

/// Short label for the quoted message in a reply bubble.
String previewForLocalMessage(LocalMessage m) {
  if (m.contentType == kMamanaMediaContentType) {
    try {
      final map = jsonDecode(m.body) as Map<String, dynamic>;
      return switch (map['kind'] as String?) {
        'image' => 'Photo',
        'voice' => 'Voice message',
        'video' => 'Video',
        'sticker' => 'Sticker',
        _ => 'Message',
      };
    } catch (_) {
      return 'Message';
    }
  }
  if (m.contentType == kMamanaStickerContentType) {
    try {
      final map = jsonDecode(m.body) as Map<String, dynamic>;
      return map['emoji'] as String? ?? 'Sticker';
    } catch (_) {
      return 'Sticker';
    }
  }
  if (m.storyMediaId != null) {
    return 'Story';
  }
  final t = m.body.trim();
  if (t.isEmpty) {
    return 'Message';
  }
  if (t.length > 80) {
    return '${t.substring(0, 80)}…';
  }
  return t;
}

LocalMessage? findLocalMessage(List<LocalMessage> messages, int id) {
  for (final m in messages) {
    if (m.id == id) {
      return m;
    }
  }
  return null;
}

/// Resolves quoted preview text from [replyToMessageId] and loaded thread messages.
String? replyPreviewForId(String? replyToMessageId, List<LocalMessage> messages) {
  if (replyToMessageId == null || replyToMessageId.isEmpty) {
    return null;
  }
  final id = int.tryParse(replyToMessageId);
  if (id == null) {
    return null;
  }
  final parent = findLocalMessage(messages, id);
  if (parent == null) {
    return 'Message';
  }
  return previewForLocalMessage(parent);
}

/// Quoted strip shown at the top of a reply bubble (Telegram-style).
class ReplyQuote extends StatelessWidget {
  const ReplyQuote({
    super.key,
    required this.preview,
    required this.accentColor,
    required this.textColor,
  });

  final String preview;
  final Color accentColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4, right: 4),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: accentColor, width: 3)),
        color: textColor.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
      ),
      child: Text(
        preview,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor.withValues(alpha: 0.9),
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.25,
        ),
      ),
    );
  }
}
