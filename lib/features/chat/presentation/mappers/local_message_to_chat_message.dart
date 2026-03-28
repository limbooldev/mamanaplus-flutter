import 'package:flutter_chat_core/flutter_chat_core.dart';

import '../../../../core/database/app_database.dart';

bool _looksLikeImageUrl(LocalMessage m) {
  if (!m.contentType.toLowerCase().startsWith('image/')) return false;
  final u = Uri.tryParse(m.body.trim());
  return u != null && (u.isScheme('http') || u.isScheme('https'));
}

/// Converts local rows (newest-first) to [Message] list in **chronological** order
/// (oldest → newest) for [InMemoryChatController] + default [ChatAnimatedList].
List<Message> mapLocalMessagesToChatMessages(
  List<LocalMessage> newestFirst, {
  required int myUserId,
  required bool Function(int messageId) readReceiptForOwn,
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
