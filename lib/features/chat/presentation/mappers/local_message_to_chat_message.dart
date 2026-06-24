import 'dart:convert';

import 'package:flutter_chat_core/flutter_chat_core.dart';

import '../../../../core/database/app_database.dart';
import '../../conversation_preview.dart';
import '../../media_constants.dart';
import '../widgets/reply_quote.dart';
import '../widgets/thread_media_widgets.dart';

/// Prefix on synthetic ids for outbox rows. Lets the chat list key pending
/// bubbles separately from server messages and lets gesture handlers ignore
/// taps on bubbles that don't yet have a server id.
const String kPendingMessagePrefix = 'pending_';

/// Returns the outbox [localId] when [messageId] is a pending bubble id.
String? pendingLocalIdFromChatMessageId(String messageId) {
  if (!messageId.startsWith(kPendingMessagePrefix)) return null;
  final localId = messageId.substring(kPendingMessagePrefix.length);
  return localId.isEmpty ? null : localId;
}

/// Context for baking reply preview into [Message.metadata] at map time.
class ReplyPreviewMapContext {
  const ReplyPreviewMapContext({
    required this.myUserId,
    required this.apiBaseUrl,
    required this.headerTitle,
    required this.conversationType,
    required this.myDisplayName,
    required this.userNameYou,
    required this.userFallback,
    this.memberDisplayNameFor,
  });

  final int myUserId;
  final String apiBaseUrl;
  final String? headerTitle;
  final String? conversationType;
  final String? myDisplayName;
  final String userNameYou;
  final String Function(String) userFallback;

  /// Group: resolve a member's display name by user id (null → use fallback).
  final String? Function(int userId)? memberDisplayNameFor;
}

Map<String, dynamic> _withMediaCaptionMeta(
  Map<String, dynamic> meta,
  Map<String, dynamic> map,
) {
  final caption = (map['caption'] as String?)?.trim();
  if (caption == null || caption.isEmpty) return meta;
  return {...meta, 'caption': caption};
}

Map<String, dynamic> _withOutboxCaptionMeta(
  Map<String, dynamic> meta,
  String? caption,
) {
  final trimmed = caption?.trim();
  if (trimmed == null || trimmed.isEmpty) return meta;
  return {...meta, 'caption': trimmed};
}

Map<String, dynamic> _mergeReplyPreviewMetadata(
  LocalMessage m,
  List<LocalMessage> allMessages,
  ReplyPreviewMapContext? ctx, {
  Map<String, dynamic>? base,
}) {
  final meta = <String, dynamic>{...?base};
  if (ctx == null) {
    return meta;
  }
  attachReplyPreviewMetadata(
    meta,
    m,
    allMessages,
    myUserId: ctx.myUserId,
    apiBaseUrl: ctx.apiBaseUrl,
    headerTitle: ctx.headerTitle,
    conversationType: ctx.conversationType,
    myDisplayName: ctx.myDisplayName,
    userNameYou: ctx.userNameYou,
    userFallback: ctx.userFallback,
    memberDisplayNameFor: ctx.memberDisplayNameFor,
  );
  return meta;
}

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

Map<String, dynamic> _withSeenMeta(
  Map<String, dynamic> meta, {
  required bool mine,
  required int messageId,
  int Function(int)? seenByCountForOwn,
}) {
  if (!mine || seenByCountForOwn == null) return meta;
  final count = seenByCountForOwn(messageId);
  if (count <= 0) return meta;
  return {...meta, 'seenByCount': count};
}

/// Converts local rows (newest-first) to [Message] list in **chronological** order
/// (oldest → newest) for [InMemoryChatController] + default [ChatAnimatedList].
List<Message> mapLocalMessagesToChatMessages(
  List<LocalMessage> newestFirst, {
  required int myUserId,
  required bool Function(int messageId) readReceiptForOwn,
  int Function(int messageId)? seenByCountForOwn,
  bool Function(int messageId)? isSeenByEveryoneForOwn,
  String? conversationType,
  required String apiBaseUrl,
  ReplyPreviewMapContext? replyPreview,
}) {
  return newestFirst.reversed.map((m) {
    final mine = m.senderId == myUserId;
    final id = '${m.id}';
    final authorId = '${m.senderId}';
    final replyTo =
        m.replyToMessageId != null ? '${m.replyToMessageId}' : null;
    var meta = _mergeReplyPreviewMetadata(
      m,
      newestFirst,
      replyPreview,
    );
    meta = _withSeenMeta(
      meta,
      mine: mine,
      messageId: m.id,
      seenByCountForOwn: seenByCountForOwn,
    );
    final MessageStatus? status;
    if (mine) {
      final isPrivate = conversationType == 'private';
      final isGroup = conversationType == 'group';
      final seenByEveryone = isSeenByEveryoneForOwn?.call(m.id) ?? false;
      final seen = readReceiptForOwn(m.id) ||
          (isPrivate && m.receiptReadAt != null) ||
          (isGroup && seenByEveryone);
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

    if (normalizeContentType(m.contentType) == kMamanaGifContentType) {
      try {
        final map = jsonDecode(m.body) as Map<String, dynamic>;
        final url = map['url'] as String? ?? '';
        final preview = map['preview_url'] as String? ?? url;
        final kind = map['kind'] as String? ?? 'gif';
        final w = (map['width'] as num?)?.toInt() ?? 0;
        final h = (map['height'] as num?)?.toInt() ?? 0;
        return Message.custom(
          id: id,
          authorId: authorId,
          createdAt: m.createdAt,
          replyToMessageId: replyTo,
          status: status,
          metadata: {
            'mamanaGifUrl': url,
            'mamanaGifPreviewUrl': preview,
            'mamanaGifKind': kind,
            if (w > 0) 'mamanaGifWidth': w,
            if (h > 0) 'mamanaGifHeight': h,
            ...meta,
          },
        );
      } catch (_) {
        return Message.text(
          id: id,
          authorId: authorId,
          text: '(gif)',
          createdAt: m.createdAt,
          replyToMessageId: replyTo,
          status: status,
          metadata: meta.isEmpty ? null : meta,
        );
      }
    }

    if (normalizeContentType(m.contentType) == kMamanaStickerContentType) {
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
        metadata: {
          'mamanaStickerEmoji': emoji,
          if (sid != null) 'mamanaStickerId': sid,
          ...meta,
        },
      );
    }

    if (normalizeContentType(m.contentType) == kMamanaMediaContentType) {
      try {
        final map = jsonDecode(m.body) as Map<String, dynamic>;
        final key = map['object_key'] as String? ?? '';
        final kind = map['kind'] as String? ?? 'image';
        final durMs = (map['duration_ms'] as num?)?.toInt() ?? 0;
        final mediaMeta = _withMediaCaptionMeta(meta, map);
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
              metadata: mediaMeta.isEmpty ? null : mediaMeta,
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
              metadata: mediaMeta.isEmpty ? null : mediaMeta,
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
              metadata: mediaMeta.isEmpty ? null : mediaMeta,
            );
        }
      } catch (_) {
        final downloadUrl = m.body.trim();
        final key = parseObjectKeyFromMediaDownloadUrl(downloadUrl);
        if (key != null) {
          return Message.image(
            id: id,
            authorId: authorId,
            source: downloadUrl,
            createdAt: m.createdAt,
            replyToMessageId: replyTo,
            status: status,
            metadata: meta.isEmpty ? null : meta,
          );
        }
        return Message.text(
          id: id,
          authorId: authorId,
          text: m.body.isEmpty ? '(media)' : m.body,
          createdAt: m.createdAt,
          replyToMessageId: replyTo,
          status: status,
          metadata: meta.isEmpty ? null : meta,
        );
      }
    }

    final downloadKey = parseObjectKeyFromMediaDownloadUrl(m.body.trim());
    if (downloadKey != null) {
      return Message.image(
        id: id,
        authorId: authorId,
        source: m.body.trim(),
        createdAt: m.createdAt,
        replyToMessageId: replyTo,
        status: status,
        metadata: meta.isEmpty ? null : meta,
      );
    }

    if (_looksLikeImageUrl(m)) {
      return Message.image(
        id: id,
        authorId: authorId,
        source: m.body.trim(),
        createdAt: m.createdAt,
        replyToMessageId: replyTo,
        status: status,
        metadata: meta.isEmpty ? null : meta,
      );
    }

    if (m.storyMediaId != null) {
      return Message.custom(
        id: id,
        authorId: authorId,
        createdAt: m.createdAt,
        replyToMessageId: replyTo,
        status: status,
        metadata: {
          'mamanaStoryReply': true,
          'story_media_id': m.storyMediaId,
          'story_reply_text': m.body,
          ...meta,
        },
      );
    }

    final isEdited = m.editedAt != null;
    final textMeta = <String, dynamic>{
      if (isEdited) 'mamanaIsEdited': true,
      ...meta,
    };
    return Message.text(
      id: id,
      authorId: authorId,
      text: m.body.isEmpty ? '(empty)' : m.body,
      createdAt: m.createdAt,
      replyToMessageId: replyTo,
      status: status,
      metadata: textMeta.isEmpty ? null : textMeta,
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
  List<LocalMessage> allMessages = const [],
  ReplyPreviewMapContext? replyPreview,
}) {
  return outbox.map((row) {
    final id = '$kPendingMessagePrefix${row.localId}';
    final authorId = '$myUserId';
    final replyTo =
        row.replyToMessageId != null ? '${row.replyToMessageId}' : null;
    const status = MessageStatus.sending;
    final pendingAsLocal = LocalMessage(
      id: -1,
      conversationId: row.conversationId,
      senderId: myUserId,
      body: row.body,
      contentType: row.contentType,
      replyToMessageId: row.replyToMessageId,
      createdAt: row.createdAt,
    );
    final meta = _mergeReplyPreviewMetadata(
      pendingAsLocal,
      allMessages,
      replyPreview,
    );

    if (row.contentType == kMamanaGifContentType) {
      try {
        final map = jsonDecode(row.body) as Map<String, dynamic>;
        final url = map['url'] as String? ?? '';
        final preview = map['preview_url'] as String? ?? url;
        final kind = map['kind'] as String? ?? 'gif';
        final w = (map['width'] as num?)?.toInt() ?? 0;
        final h = (map['height'] as num?)?.toInt() ?? 0;
        return Message.custom(
          id: id,
          authorId: authorId,
          createdAt: row.createdAt,
          replyToMessageId: replyTo,
          status: status,
          metadata: {
            'mamanaGifUrl': url,
            'mamanaGifPreviewUrl': preview,
            'mamanaGifKind': kind,
            if (w > 0) 'mamanaGifWidth': w,
            if (h > 0) 'mamanaGifHeight': h,
            ...meta,
          },
        );
      } catch (_) {
        return Message.text(
          id: id,
          authorId: authorId,
          text: '(gif)',
          createdAt: row.createdAt,
          replyToMessageId: replyTo,
          status: status,
          metadata: meta.isEmpty ? null : meta,
        );
      }
    }

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
        metadata: {
          'mamanaStickerEmoji': emoji,
          if (sid != null) 'mamanaStickerId': sid,
          ...meta,
        },
      );
    }

    final mediaPath = row.mediaPath;
    if (mediaPath != null && mediaPath.isNotEmpty) {
      final source = 'file://$mediaPath';
      final durMs = row.mediaDurationMs ?? 0;
      var mediaMeta = _withOutboxCaptionMeta(meta, row.mediaCaption);
      if (row.lastErrorAt != null && row.attempts > 0) {
        mediaMeta = {...mediaMeta, 'pendingFailed': true};
      }
      switch (row.mediaKind) {
        case 'video':
          return Message.video(
            id: id,
            authorId: authorId,
            source: source,
            createdAt: row.createdAt,
            replyToMessageId: replyTo,
            status: status,
            metadata: mediaMeta.isEmpty ? null : mediaMeta,
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
            metadata: mediaMeta.isEmpty ? null : mediaMeta,
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
            metadata: mediaMeta.isEmpty ? null : mediaMeta,
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
      metadata: meta.isEmpty ? null : meta,
    );
  }).toList();
}
