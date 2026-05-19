import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/database/app_database.dart';
import '../../../../shared/ui/ui.dart';
import '../../conversation_preview.dart';
import '../../media_constants.dart';

/// Parsed media envelope from a [LocalMessage] body.
class MediaBodyInfo {
  const MediaBodyInfo({required this.kind, required this.objectKey});

  final String kind;
  final String objectKey;
}

/// Preview model for composer strip and in-bubble quote.
class ReplyPreviewData {
  const ReplyPreviewData({
    required this.authorName,
    required this.subtitle,
    this.thumbnailUrl,
  });

  final String authorName;
  final String subtitle;
  final String? thumbnailUrl;
}

MediaBodyInfo? parseMediaBody(LocalMessage m) {
  if (m.contentType != kMamanaMediaContentType) {
    return null;
  }
  try {
    final map = jsonDecode(m.body) as Map<String, dynamic>;
    final key = map['object_key'] as String? ?? '';
    final kind = map['kind'] as String? ?? '';
    if (key.isEmpty || kind.isEmpty) {
      return null;
    }
    return MediaBodyInfo(kind: kind, objectKey: key);
  } catch (_) {
    return null;
  }
}

String mediaDownloadUrl(String apiBaseUrl, String objectKey) {
  final base = apiBaseUrl.endsWith('/')
      ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
      : apiBaseUrl;
  return '$base/v1/media/download?object_key=${Uri.encodeComponent(objectKey)}';
}

const String kMetaReplyAuthor = 'mamanaReplyAuthor';
const String kMetaReplySubtitle = 'mamanaReplySubtitle';
const String kMetaReplyThumb = 'mamanaReplyThumb';

/// Display name for the author of [message] in this thread.
String authorDisplayNameForMessage({
  required LocalMessage message,
  required int myUserId,
  required String? headerTitle,
  required String? conversationType,
  required String? myDisplayName,
  required String userNameYou,
  required String Function(String) userFallback,
}) {
  if (message.senderId == myUserId) {
    final name = myDisplayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return userNameYou;
  }
  if (conversationType == 'private' &&
      headerTitle != null &&
      headerTitle.trim().isNotEmpty) {
    return headerTitle.trim();
  }
  return userFallback('${message.senderId}');
}

/// Subtitle line under the author (text preview, Photo, Video, Voice message, …).
String subtitleForLocalMessage(LocalMessage m) {
  final preview = conversationPreviewForLocalMessage(m);
  if (preview.length > 80) {
    return '${preview.substring(0, 80)}…';
  }
  return preview;
}

/// Bakes reply preview fields into [metadata] so bubbles keep quotes after sync.
void attachReplyPreviewMetadata(
  Map<String, dynamic> metadata,
  LocalMessage m,
  List<LocalMessage> allMessages, {
  required int myUserId,
  required String apiBaseUrl,
  required String? headerTitle,
  required String? conversationType,
  required String? myDisplayName,
  required String userNameYou,
  required String Function(String) userFallback,
}) {
  if (m.replyToMessageId == null) {
    return;
  }
  final parent = findLocalMessage(allMessages, m.replyToMessageId!);
  if (parent == null) {
    return;
  }
  final data = replyPreviewDataForMessage(
    message: parent,
    myUserId: myUserId,
    apiBaseUrl: apiBaseUrl,
    headerTitle: headerTitle,
    conversationType: conversationType,
    myDisplayName: myDisplayName,
    userNameYou: userNameYou,
    userFallback: userFallback,
  );
  metadata[kMetaReplyAuthor] = data.authorName;
  metadata[kMetaReplySubtitle] = data.subtitle;
  if (data.thumbnailUrl != null) {
    metadata[kMetaReplyThumb] = data.thumbnailUrl;
  }
}

ReplyPreviewData? replyPreviewDataFromMetadata(Map<String, dynamic>? metadata) {
  if (metadata == null) {
    return null;
  }
  final subtitle = metadata[kMetaReplySubtitle];
  if (subtitle is! String || subtitle.isEmpty) {
    return null;
  }
  return ReplyPreviewData(
    authorName: metadata[kMetaReplyAuthor] as String? ?? '',
    subtitle: subtitle,
    thumbnailUrl: metadata[kMetaReplyThumb] as String?,
  );
}

ReplyPreviewData replyPreviewDataForMessage({
  required LocalMessage message,
  required int myUserId,
  required String apiBaseUrl,
  required String? headerTitle,
  required String? conversationType,
  required String? myDisplayName,
  required String userNameYou,
  required String Function(String) userFallback,
}) {
  final authorName = authorDisplayNameForMessage(
    message: message,
    myUserId: myUserId,
    headerTitle: headerTitle,
    conversationType: conversationType,
    myDisplayName: myDisplayName,
    userNameYou: userNameYou,
    userFallback: userFallback,
  );
  final subtitle = subtitleForLocalMessage(message);
  final media = parseMediaBody(message);
  String? thumbnailUrl;
  if (media != null && (media.kind == 'image' || media.kind == 'video')) {
    thumbnailUrl = mediaDownloadUrl(apiBaseUrl, media.objectKey);
  }
  return ReplyPreviewData(
    authorName: authorName,
    subtitle: subtitle,
    thumbnailUrl: thumbnailUrl,
  );
}

LocalMessage? findLocalMessage(List<LocalMessage> messages, int id) {
  for (final m in messages) {
    if (m.id == id) {
      return m;
    }
  }
  return null;
}

ReplyPreviewData? replyPreviewDataForId(
  String? replyToMessageId,
  List<LocalMessage> messages, {
  required int myUserId,
  required String apiBaseUrl,
  required String? headerTitle,
  required String? conversationType,
  required String? myDisplayName,
  required String userNameYou,
  required String Function(String) userFallback,
}) {
  if (replyToMessageId == null || replyToMessageId.isEmpty) {
    return null;
  }
  final id = int.tryParse(replyToMessageId);
  if (id == null) {
    return null;
  }
  final parent = findLocalMessage(messages, id);
  if (parent == null) {
    return const ReplyPreviewData(authorName: '', subtitle: 'Message');
  }
  return replyPreviewDataForMessage(
    message: parent,
    myUserId: myUserId,
    apiBaseUrl: apiBaseUrl,
    headerTitle: headerTitle,
    conversationType: conversationType,
    myDisplayName: myDisplayName,
    userNameYou: userNameYou,
    userFallback: userFallback,
  );
}

/// @deprecated Use [subtitleForLocalMessage] — kept for any external callers.
String previewForLocalMessage(LocalMessage m) => subtitleForLocalMessage(m);

/// @deprecated Use [replyPreviewDataForId].
String? replyPreviewForId(String? replyToMessageId, List<LocalMessage> messages) {
  final id = int.tryParse(replyToMessageId ?? '');
  if (id == null) {
    return null;
  }
  final parent = findLocalMessage(messages, id);
  if (parent == null) {
    return 'Message';
  }
  return subtitleForLocalMessage(parent);
}

class _ReplyThumbnail extends StatelessWidget {
  const _ReplyThumbnail({
    required this.url,
    required this.accessToken,
  });

  final String url;
  final String accessToken;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        headers: {'Authorization': 'Bearer $accessToken'},
        errorBuilder: (_, __, ___) => Container(
          width: 40,
          height: 40,
          color: AppColors.dividerLight,
          child: const Icon(Icons.broken_image_outlined, size: 20),
        ),
      ),
    );
  }
}

/// Telegram-style strip above the composer while replying.
class ComposerReplyPreview extends StatelessWidget {
  const ComposerReplyPreview({
    super.key,
    required this.data,
    required this.replyToTitle,
    required this.accessToken,
    required this.onDismiss,
    this.isDark = false,
  });

  final ReplyPreviewData data;
  final String replyToTitle;
  final String accessToken;
  final VoidCallback onDismiss;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final titleColor = AppColors.primary;
    final subtitleColor = isDark ? AppColors.subtitleDark : AppColors.subtitleLight;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: 44,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: titleColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                replyToTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 13, color: subtitleColor),
              ),
            ],
          ),
        ),
        if (data.thumbnailUrl != null) ...[
          const SizedBox(width: 8),
          _ReplyThumbnail(url: data.thumbnailUrl!, accessToken: accessToken),
        ],
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.close, size: 20),
          onPressed: onDismiss,
        ),
      ],
    );
  }
}

/// Quoted strip at the top of a reply bubble (Telegram-style).
class ReplyQuote extends StatelessWidget {
  const ReplyQuote({
    super.key,
    required this.data,
    required this.accentColor,
    required this.textColor,
    required this.accessToken,
    this.onPrimaryBubble = false,
    this.onTap,
  });

  final ReplyPreviewData data;
  final Color accentColor;
  final Color textColor;
  final String accessToken;

  /// True when the quote sits on the user's primary-colored sent bubble.
  final bool onPrimaryBubble;

  /// Scroll to the quoted message when set (Telegram-style).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = onPrimaryBubble ? Colors.white : accentColor;
    final subtitleColor = onPrimaryBubble
        ? Colors.white.withValues(alpha: 0.92)
        : textColor.withValues(alpha: 0.9);
    final barColor = onPrimaryBubble ? Colors.white : accentColor;
    final bgColor = onPrimaryBubble
        ? Colors.black.withValues(alpha: 0.22)
        : textColor.withValues(alpha: 0.12);

    final quote = Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4, right: 4),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: barColor, width: 3)),
        color: bgColor,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (data.thumbnailUrl != null) ...[
            const SizedBox(width: 8),
            _ReplyThumbnail(url: data.thumbnailUrl!, accessToken: accessToken),
          ],
        ],
      ),
    );

    if (onTap == null) return quote;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
        child: quote,
      ),
    );
  }
}
