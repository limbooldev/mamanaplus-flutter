import 'dart:convert';

import 'package:flutter_chat_core/flutter_chat_core.dart';

import '../../../../core/database/app_database.dart';
import '../../media_constants.dart';

bool _looksLikeImageUrl(LocalMessage m) {
  if (!m.contentType.toLowerCase().startsWith('image/')) return false;
  final u = Uri.tryParse(m.body.trim());
  return u != null && (u.isScheme('http') || u.isScheme('https'));
}

String _mediaDownloadUrl(String apiBaseUrl, String objectKey) {
  final base = apiBaseUrl.endsWith('/')
      ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
      : apiBaseUrl;
  return '$base/v1/media/download?object_key=${Uri.encodeComponent(objectKey)}';
}

/// Converts local rows (newest-first) to [Message] list in **chronological** order
/// (oldest → newest) for [InMemoryChatController] + default [ChatAnimatedList].
List<Message> mapLocalMessagesToChatMessages(
  List<LocalMessage> newestFirst, {
  required int myUserId,
  required bool Function(int messageId) readReceiptForOwn,
  required String apiBaseUrl,
}) {
  return newestFirst.reversed.map((m) {
    final mine = m.senderId == myUserId;
    final id = '${m.id}';
    final authorId = '${m.senderId}';
    final replyTo =
        m.replyToMessageId != null ? '${m.replyToMessageId}' : null;
    final MessageStatus? status;
    if (mine) {
      final seen = readReceiptForOwn(m.id) || m.receiptReadAt != null;
      if (seen) {
        status = MessageStatus.seen;
      } else if (m.receiptDeliveredAt != null) {
        status = MessageStatus.delivered;
      } else {
        status = MessageStatus.sent;
      }
    } else {
      status = null;
    }

    if (m.contentType == kMamanaStickerContentType) {
      var emoji = '💬';
      String? sid;
      try {
        final map = jsonDecode(m.body) as Map<String, dynamic>;
        emoji = map['emoji'] as String? ?? emoji;
        sid = map['sticker_id'] as String?;
      } catch (_) {}
      return Message.custom(
        id: id,
        authorId: authorId,
        createdAt: m.createdAt,
        replyToMessageId: replyTo,
        status: status,
        metadata: <String, dynamic>{
          'mamanaStickerEmoji': emoji,
          if (sid != null) 'mamanaStickerId': sid,
        },
      );
    }

    if (m.contentType == kMamanaMediaContentType) {
      try {
        final map = jsonDecode(m.body) as Map<String, dynamic>;
        final key = map['object_key'] as String? ?? '';
        final kind = map['kind'] as String? ?? 'image';
        final durMs = (map['duration_ms'] as num?)?.toInt() ?? 0;
        final url = _mediaDownloadUrl(apiBaseUrl, key);
        switch (kind) {
          case 'video':
            return Message.video(
              id: id,
              authorId: authorId,
              source: url,
              createdAt: m.createdAt,
              replyToMessageId: replyTo,
              status: status,
            );
          case 'voice':
            return Message.audio(
              id: id,
              authorId: authorId,
              source: url,
              duration: Duration(milliseconds: durMs > 0 ? durMs : 1),
              createdAt: m.createdAt,
              replyToMessageId: replyTo,
              status: status,
            );
          case 'sticker':
          case 'image':
          default:
            return Message.image(
              id: id,
              authorId: authorId,
              source: url,
              createdAt: m.createdAt,
              replyToMessageId: replyTo,
              status: status,
            );
        }
      } catch (_) {
        return Message.text(
          id: id,
          authorId: authorId,
          text: m.body.isEmpty ? '(media)' : m.body,
          createdAt: m.createdAt,
          replyToMessageId: replyTo,
          status: status,
        );
      }
    }

    if (_looksLikeImageUrl(m)) {
      return Message.image(
        id: id,
        authorId: authorId,
        source: m.body.trim(),
        createdAt: m.createdAt,
        replyToMessageId: replyTo,
        status: status,
      );
    }

    if (m.storyMediaId != null) {
      return Message.custom(
        id: id,
        authorId: authorId,
        createdAt: m.createdAt,
        replyToMessageId: replyTo,
        status: status,
        metadata: <String, dynamic>{
          'mamanaStoryReply': true,
          'story_media_id': m.storyMediaId,
          'story_reply_text': m.body,
        },
      );
    }

    return Message.text(
      id: id,
      authorId: authorId,
      text: m.body.isEmpty ? '(empty)' : m.body,
      createdAt: m.createdAt,
      replyToMessageId: replyTo,
      status: status,
    );
  }).toList();
}
