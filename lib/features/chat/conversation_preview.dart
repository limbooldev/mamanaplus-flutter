import 'dart:convert';

import 'package:mamana_plus/core/database/app_database.dart';

import 'media_constants.dart';

/// Media kinds that show an inbox icon alongside caption text.
enum ConversationPreviewMediaKind {
  image,
  video,
}

/// Parsed inbox / conversation-list preview (plain text or media + caption).
class ConversationListPreview {
  const ConversationListPreview({
    required this.text,
    this.mediaKind,
  });

  final String text;
  final ConversationPreviewMediaKind? mediaKind;

  bool get hasMediaIcon => mediaKind != null;
}

/// True when the user may copy or edit message body (plain text only).
bool isEditableChatMessage(LocalMessage m) {
  if (m.storyMediaId != null && m.storyMediaId! > 0) {
    return false;
  }
  final ct = normalizeContentType(m.contentType);
  if (ct != 'text/plain') {
    return false;
  }
  return m.body.trim().isNotEmpty;
}

/// Normalizes a MIME type (strips parameters like `; charset=utf-8`).
String normalizeContentType(String? contentType) {
  final raw = (contentType ?? '').trim();
  if (raw.isEmpty) return 'text/plain';
  final semi = raw.indexOf(';');
  return (semi >= 0 ? raw.substring(0, semi) : raw).trim().toLowerCase();
}

/// Human-readable inbox / conversation-list preview for a message.
ConversationListPreview conversationPreviewForMessage({
  required String body,
  required String contentType,
  int? storyMediaId,
}) {
  final ct = normalizeContentType(contentType);

  if (storyMediaId != null && storyMediaId > 0) {
    return const ConversationListPreview(text: 'Story');
  }

  if (ct == kMamanaGifContentType) {
    return ConversationListPreview(text: _gifPreviewFromBody(body));
  }
  if (ct == kMamanaStickerContentType) {
    return ConversationListPreview(text: _catalogStickerPreviewFromBody(body));
  }
  if (ct == kMamanaMediaContentType) {
    return _mediaPreviewFromBody(body);
  }

  // Legacy rows or servers that stored JSON under text/plain.
  final fromJson = _previewFromJsonBody(body);
  if (fromJson != null) return fromJson;

  final t = body.trim();
  if (t.isEmpty) return const ConversationListPreview(text: 'Message');
  if (t.length > 120) {
    return ConversationListPreview(text: '${t.substring(0, 117)}…');
  }
  return ConversationListPreview(text: t);
}

/// Same as [conversationPreviewForMessage] for a cached [LocalMessage].
String conversationPreviewForLocalMessage(LocalMessage m) {
  return conversationPreviewForMessage(
    body: m.body,
    contentType: m.contentType,
    storyMediaId: m.storyMediaId,
  ).text;
}

/// Encodes [preview] for storage in [LocalConversations.lastMessagePreview].
String encodeConversationListPreview(ConversationListPreview preview) {
  if (preview.mediaKind != null && preview.text.isNotEmpty) {
    return jsonEncode({
      'm': preview.mediaKind!.name,
      'p': preview.text,
    });
  }
  return preview.text;
}

/// Parses a stored or API `last_message_preview` string.
ConversationListPreview decodeConversationListPreview(String? preview) {
  final t = preview?.trim();
  if (t == null || t.isEmpty) {
    return const ConversationListPreview(text: '');
  }
  if (t.startsWith('{')) {
    try {
      final map = jsonDecode(t) as Map<String, dynamic>;
      final kindRaw = map['m'] as String?;
      final text = (map['p'] as String?)?.trim() ?? '';
      final kind = switch (kindRaw) {
        'image' => ConversationPreviewMediaKind.image,
        'video' => ConversationPreviewMediaKind.video,
        _ => null,
      };
      if (kind != null && text.isNotEmpty) {
        return ConversationListPreview(text: text, mediaKind: kind);
      }
    } catch (_) {}
    final fromBody = _previewFromJsonBody(t);
    if (fromBody != null) return fromBody;
  }
  return ConversationListPreview(text: t);
}

/// If [preview] from the API is already friendly, return it; otherwise parse JSON bodies.
ConversationListPreview normalizeConversationListPreview(String? preview) {
  final decoded = decodeConversationListPreview(preview);
  if (decoded.text.isNotEmpty || decoded.mediaKind != null) {
    return decoded;
  }
  return decoded;
}

String _gifPreviewFromBody(String body) {
  try {
    final map = jsonDecode(body) as Map<String, dynamic>;
    final kind = map['kind'] as String? ?? 'gif';
    return kind == 'sticker' ? 'Sticker' : 'GIF';
  } catch (_) {
    return 'GIF';
  }
}

String _catalogStickerPreviewFromBody(String body) {
  try {
    final map = jsonDecode(body) as Map<String, dynamic>;
    return map['emoji'] as String? ?? 'Sticker';
  } catch (_) {
    return 'Sticker';
  }
}

String _truncatePreview(String text) {
  final t = text.trim();
  if (t.length <= 120) return t;
  return '${t.substring(0, 117)}…';
}

ConversationPreviewMediaKind? _mediaKindFromWire(String? kind) {
  return switch (kind) {
    'image' || 'sticker' => ConversationPreviewMediaKind.image,
    'video' => ConversationPreviewMediaKind.video,
    _ => null,
  };
}

ConversationListPreview _mediaPreviewFromBody(String body) {
  try {
    final map = jsonDecode(body) as Map<String, dynamic>;
    final kind = map['kind'] as String? ?? '';
    final caption = (map['caption'] as String?)?.trim();
    if (caption != null && caption.isNotEmpty) {
      return ConversationListPreview(
        text: _truncatePreview(caption),
        mediaKind: _mediaKindFromWire(kind),
      );
    }
    return ConversationListPreview(
      text: switch (kind) {
        'image' => 'Photo',
        'video' => 'Video',
        'voice' => 'Voice message',
        'sticker' => 'Sticker',
        _ => 'Media',
      },
      mediaKind: _mediaKindFromWire(kind),
    );
  } catch (_) {
    return const ConversationListPreview(text: 'Media');
  }
}

ConversationListPreview? _previewFromJsonBody(String body) {
  final t = body.trim();
  if (!t.startsWith('{')) return null;
  try {
    final map = jsonDecode(t) as Map<String, dynamic>;
    if (map.containsKey('gif_id') && map.containsKey('url')) {
      final kind = map['kind'] as String? ?? 'gif';
      return ConversationListPreview(
        text: kind == 'sticker' ? 'Sticker' : 'GIF',
      );
    }
    if (map.containsKey('sticker_id') && map.containsKey('emoji')) {
      return ConversationListPreview(
        text: map['emoji'] as String? ?? 'Sticker',
      );
    }
    if (map.containsKey('object_key') && map.containsKey('kind')) {
      return _mediaPreviewFromBody(t);
    }
    if (map.containsKey('m') && map.containsKey('p')) {
      return decodeConversationListPreview(t);
    }
  } catch (_) {}
  return null;
}
