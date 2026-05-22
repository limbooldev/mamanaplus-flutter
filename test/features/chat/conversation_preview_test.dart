import 'package:flutter_test/flutter_test.dart';
import 'package:mamana_plus/features/chat/conversation_preview.dart';
import 'package:mamana_plus/features/chat/media_constants.dart';

void main() {
  test('GIF content type shows GIF', () {
    expect(
      conversationPreviewForMessage(
        body: '{"gif_id":"x","url":"https://x.gif","kind":"gif"}',
        contentType: kMamanaGifContentType,
      ).text,
      'GIF',
    );
  });

  test('Giphy sticker content type shows Sticker', () {
    expect(
      conversationPreviewForMessage(
        body: '{"gif_id":"x","url":"https://x.webp","kind":"sticker"}',
        contentType: kMamanaGifContentType,
      ).text,
      'Sticker',
    );
  });

  test('catalog sticker shows emoji', () {
    expect(
      conversationPreviewForMessage(
        body: '{"sticker_id":"heart","emoji":"❤️"}',
        contentType: kMamanaStickerContentType,
      ).text,
      '❤️',
    );
  });

  test('normalizeConversationListPreview parses JSON body from API', () {
    expect(
      decodeConversationListPreview(
        '{"gif_id":"abc","url":"https://media.giphy.com/x.gif","kind":"gif"}',
      ).text,
      'GIF',
    );
    expect(
      decodeConversationListPreview(
        '{"sticker_id":"wave","emoji":"👋"}',
      ).text,
      '👋',
    );
  });

  test('media kinds map to labels', () {
    final preview = conversationPreviewForMessage(
      body: '{"object_key":"conv/1/a","mime":"image/jpeg","kind":"image"}',
      contentType: kMamanaMediaContentType,
    );
    expect(preview.text, 'Photo');
    expect(preview.mediaKind, ConversationPreviewMediaKind.image);
  });

  test('media caption includes media kind for inbox icon', () {
    final preview = conversationPreviewForMessage(
      body:
          '{"object_key":"conv/1/a","mime":"image/jpeg","kind":"image","caption":"Look at this sunset"}',
      contentType: kMamanaMediaContentType,
    );
    expect(preview.text, 'Look at this sunset');
    expect(preview.mediaKind, ConversationPreviewMediaKind.image);

    final encoded = encodeConversationListPreview(preview);
    expect(encoded, '{"m":"image","p":"Look at this sunset"}');

    final decoded = decodeConversationListPreview(encoded);
    expect(decoded.text, 'Look at this sunset');
    expect(decoded.mediaKind, ConversationPreviewMediaKind.image);
  });

  test('video caption encodes with video kind', () {
    final preview = conversationPreviewForMessage(
      body:
          '{"object_key":"conv/1/a","mime":"video/mp4","kind":"video","caption":"Check this out"}',
      contentType: kMamanaMediaContentType,
    );
    expect(preview.mediaKind, ConversationPreviewMediaKind.video);
    expect(
      decodeConversationListPreview(encodeConversationListPreview(preview))
          .mediaKind,
      ConversationPreviewMediaKind.video,
    );
  });
}
