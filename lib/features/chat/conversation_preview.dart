import 'dart:convert';

import 'package:mamana_plus/core/database/app_database.dart';

import 'media_constants.dart';

/// Normalizes a MIME type (strips parameters like `; charset=utf-8`).
String normalizeContentType(String? contentType) {
  final raw = (contentType ?? '').trim();
  if (raw.isEmpty) return 'text/plain';
  final semi = raw.indexOf(';');
  return (semi >= 0 ? raw.substring(0, semi) : raw).trim().toLowerCase();
}

/// Human-readable inbox / conversation-list preview for a message.
String conversationPreviewForMessage({
  required String body,
  required String contentType,
  int? storyMediaId,
}) {
  final ct = normalizeContentType(contentType);

  if (storyMediaId != null && storyMediaId > 0) {
    return 'Story';
  }

  if (ct == kMamanaGifContentType) {
    return _gifPreviewFromBody(body);
  }
  if (ct == kMamanaStickerContentType) {
    return _catalogStickerPreviewFromBody(body);
  }
  if (ct == kMamanaMediaContentType) {
    return _mediaPreviewFromBody(body);
  }

  // Legacy rows or servers that stored JSON under text/plain.
  final fromJson = _previewFromJsonBody(body);
  if (fromJson != null) return fromJson;

  final t = body.trim();
  if (t.isEmpty) return 'Message';
  if (t.length > 120) return '${t.substring(0, 117)}…';
  return t;
}

/// Same as [conversationPreviewForMessage] for a cached [LocalMessage].
String conversationPreviewForLocalMessage(LocalMessage m) {
  return conversationPreviewForMessage(
    body: m.body,
    contentType: m.contentType,
    storyMediaId: m.storyMediaId,
  );
}

/// If [preview] from the API is already friendly, return it; otherwise parse JSON bodies.
String normalizeConversationListPreview(String? preview) {
  final t = preview?.trim();
  if (t == null || t.isEmpty) return '';
  if (!t.startsWith('{')) return t;
  return _previewFromJsonBody(t) ?? t;
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

String _mediaPreviewFromBody(String body) {
  try {
    final map = jsonDecode(body) as Map<String, dynamic>;
    return switch (map['kind'] as String? ?? '') {
      'image' => 'Photo',
      'video' => 'Video',
      'voice' => 'Voice message',
      'sticker' => 'Sticker',
      _ => 'Media',
    };
  } catch (_) {
    return 'Media';
  }
}

String? _previewFromJsonBody(String body) {
  final t = body.trim();
  if (!t.startsWith('{')) return null;
  try {
    final map = jsonDecode(t) as Map<String, dynamic>;
    if (map.containsKey('gif_id') && map.containsKey('url')) {
      final kind = map['kind'] as String? ?? 'gif';
      return kind == 'sticker' ? 'Sticker' : 'GIF';
    }
    if (map.containsKey('sticker_id') && map.containsKey('emoji')) {
      return map['emoji'] as String? ?? 'Sticker';
    }
    if (map.containsKey('object_key') && map.containsKey('kind')) {
      return switch (map['kind'] as String? ?? '') {
        'image' => 'Photo',
        'video' => 'Video',
        'voice' => 'Voice message',
        'sticker' => 'Sticker',
        _ => 'Media',
      };
    }
  } catch (_) {}
  return null;
}
