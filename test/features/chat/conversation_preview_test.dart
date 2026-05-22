import 'package:flutter_test/flutter_test.dart';
import 'package:mamana_plus/features/chat/conversation_preview.dart';
import 'package:mamana_plus/features/chat/media_constants.dart';

void main() {
  test('GIF content type shows GIF', () {
    expect(
      conversationPreviewForMessage(
        body: '{"gif_id":"x","url":"https://x.gif","kind":"gif"}',
        contentType: kMamanaGifContentType,
      ),
      'GIF',
    );
  });

  test('Giphy sticker content type shows Sticker', () {
    expect(
      conversationPreviewForMessage(
        body: '{"gif_id":"x","url":"https://x.webp","kind":"sticker"}',
        contentType: kMamanaGifContentType,
      ),
      'Sticker',
    );
  });

  test('catalog sticker shows emoji', () {
    expect(
      conversationPreviewForMessage(
        body: '{"sticker_id":"heart","emoji":"❤️"}',
        contentType: kMamanaStickerContentType,
      ),
      '❤️',
    );
  });

  test('normalizeConversationListPreview parses JSON body from API', () {
    expect(
      normalizeConversationListPreview(
        '{"gif_id":"abc","url":"https://media.giphy.com/x.gif","kind":"gif"}',
      ),
      'GIF',
    );
    expect(
      normalizeConversationListPreview(
        '{"sticker_id":"wave","emoji":"👋"}',
      ),
      '👋',
    );
  });

  test('media kinds map to labels', () {
    expect(
      conversationPreviewForMessage(
        body: '{"object_key":"conv/1/a","mime":"image/jpeg","kind":"image"}',
        contentType: kMamanaMediaContentType,
      ),
      'Photo',
    );
  });

  test('media caption is used as preview when present', () {
    expect(
      conversationPreviewForMessage(
        body:
            '{"object_key":"conv/1/a","mime":"image/jpeg","kind":"image","caption":"Look at this sunset"}',
        contentType: kMamanaMediaContentType,
      ),
      'Look at this sunset',
    );
  });
}
