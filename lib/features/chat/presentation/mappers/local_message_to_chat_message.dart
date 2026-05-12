import 'dart:convert';

import 'package:flutter_chat_core/flutter_chat_core.dart';

import '../../../../core/database/app_database.dart';
import '../../media_constants.dart';

/// Prefix on synthetic ids for outbox rows. Lets the chat list key pending
/// bubbles separately from server messages and lets gesture handlers ignore
/// taps on bubbles that don't yet have a server id.
const String kPendingMessagePrefix = 'pending_';

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

/// Maps outbox rows to chat messages with [MessageStatus.sending].
///
/// Pending media bubbles point at the local file (`file://...`) so the user
/// sees their own attachment immediately while the upload + send is running.
/// Once the server returns the message, the row is removed from the outbox
/// and the server's [LocalMessage] takes its place (with status Sent).
List<Message> mapPendingOutboxToChatMessages(
  List<MessageOutboxData> outbox, {
  required int myUserId,
}) {
  return outbox.map((row) {
    final id = '$kPendingMessagePrefix${row.localId}';
    final authorId = '$myUserId';
    final replyTo =
        row.replyToMessageId != null ? '${row.replyToMessageId}' : null;
    const status = MessageStatus.sending;

    if (row.contentType == kMamanaStickerContentType) {
      var emoji = '💬';
      String? sid;
      try {
        final map = jsonDecode(row.body) as Map<String, dynamic>;
        emoji = map['emoji'] as String? ?? emoji;
        sid = map['sticker_id'] as String?;
      } catch (_) {}
      return Message.custom(
        id: id,
        authorId: authorId,
        createdAt: row.createdAt,
        replyToMessageId: replyTo,
        status: status,
        metadata: <String, dynamic>{
          'mamanaStickerEmoji': emoji,
          if (sid != null) 'mamanaStickerId': sid,
        },
      );
    }

    final mediaPath = row.mediaPath;
    if (mediaPath != null && mediaPath.isNotEmpty) {
      final source = 'file://$mediaPath';
      final durMs = row.mediaDurationMs ?? 0;
      switch (row.mediaKind) {
        case 'video':
          return Message.video(
            id: id,
            authorId: authorId,
            source: source,
            createdAt: row.createdAt,
            replyToMessageId: replyTo,
            status: status,
          );
        case 'voice':
          return Message.audio(
            id: id,
            authorId: authorId,
            source: source,
            duration: Duration(milliseconds: durMs > 0 ? durMs : 1),
            createdAt: row.createdAt,
            replyToMessageId: replyTo,
            status: status,
          );
        case 'sticker':
        case 'image':
        default:
          return Message.image(
            id: id,
            authorId: authorId,
            source: source,
            createdAt: row.createdAt,
            replyToMessageId: replyTo,
            status: status,
          );
      }
    }

    return Message.text(
      id: id,
      authorId: authorId,
      text: row.body.isEmpty ? '(empty)' : row.body,
      createdAt: row.createdAt,
      replyToMessageId: replyTo,
      status: status,
    );
  }).toList();
}
