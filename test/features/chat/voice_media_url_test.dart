import 'dart:convert';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mamana_plus/core/database/app_database.dart';
import 'package:mamana_plus/features/chat/media_constants.dart';
import 'package:mamana_plus/features/chat/presentation/mappers/local_message_to_chat_message.dart';
import 'package:mamana_plus/features/chat/presentation/widgets/thread_media_widgets.dart';

const _myUserId = 42;
const _conversationId = 100;

void main() {
  group('parseObjectKeyFromMediaDownloadUrl', () {
    test('decodes object_key from https download URL', () {
      expect(
        parseObjectKeyFromMediaDownloadUrl(
          'https://api.example.com/v1/media/download?object_key=conv%2F123%2Ffile.m4a',
        ),
        'conv/123/file.m4a',
      );
    });

    test('returns null for file scheme', () {
      expect(parseObjectKeyFromMediaDownloadUrl('file:///tmp/voice.m4a'), isNull);
    });

    test('returns null when object_key missing', () {
      expect(
        parseObjectKeyFromMediaDownloadUrl('https://api.example.com/v1/media/download'),
        isNull,
      );
    });

    test('returns null for invalid URI', () {
      expect(parseObjectKeyFromMediaDownloadUrl('not a uri'), isNull);
    });
  });

  test('voice message URL from mapper yields same object_key for download', () {
    const key = 'conv/99/voice.m4a';
    final local = LocalMessage(
      id: 1,
      conversationId: _conversationId,
      senderId: _myUserId,
      body: jsonEncode({
        'object_key': key,
        'kind': 'voice',
        'mime': 'audio/m4a',
      }),
      contentType: kMamanaMediaContentType,
      createdAt: DateTime(2026, 5, 11),
    );
    final mapped = mapLocalMessagesToChatMessages(
      [local],
      myUserId: _myUserId,
      readReceiptForOwn: (_) => false,
      apiBaseUrl: 'https://api.test',
    );
    final msg = mapped.single;
    expect(msg, isA<AudioMessage>());
    expect(parseObjectKeyFromMediaDownloadUrl((msg as AudioMessage).source), key);
  });
}
