import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mamana_plus/core/database/app_database.dart';
import 'package:mamana_plus/features/chat/media_constants.dart';
import 'package:mamana_plus/features/chat/presentation/cubit/thread_cubit.dart';
import 'package:mamana_plus/features/chat/presentation/mappers/local_message_to_chat_message.dart';

const _myUserId = 42;
const _peerUserId = 7;
const _conversationId = 100;
const _apiBaseUrl = 'https://api.test';

LocalMessage _localMessage({
  required int id,
  int senderId = _peerUserId,
  String body = 'hi',
  String contentType = 'text/plain',
  DateTime? createdAt,
  DateTime? receiptDeliveredAt,
  DateTime? receiptReadAt,
}) {
  return LocalMessage(
    id: id,
    conversationId: _conversationId,
    senderId: senderId,
    body: body,
    contentType: contentType,
    createdAt: createdAt ?? DateTime(2026, 5, 11, 22, 0),
    receiptDeliveredAt: receiptDeliveredAt,
    receiptReadAt: receiptReadAt,
  );
}

MessageOutboxData _outboxRow({
  required String localId,
  String body = 'queued',
  String contentType = 'text/plain',
  DateTime? createdAt,
  String? mediaPath,
  String? mediaMime,
  String? mediaKind,
  int? mediaDurationMs,
  int attempts = 0,
  DateTime? lastErrorAt,
}) {
  return MessageOutboxData(
    localId: localId,
    conversationId: _conversationId,
    body: body,
    createdAt: createdAt ?? DateTime(2026, 5, 11, 22, 5),
    contentType: contentType,
    mediaPath: mediaPath,
    mediaMime: mediaMime,
    mediaKind: mediaKind,
    mediaDurationMs: mediaDurationMs,
    attempts: attempts,
    lastErrorAt: lastErrorAt,
  );
}

void main() {
  group('mapLocalMessagesToChatMessages — own-message status', () {
    test('no receipts → Sent', () {
      final messages = mapLocalMessagesToChatMessages(
        [_localMessage(id: 1, senderId: _myUserId)],
        myUserId: _myUserId,
        readReceiptForOwn: (_) => false,
        apiBaseUrl: _apiBaseUrl,
      );

      expect(messages.single.status, MessageStatus.sent);
    });

    test('delivered_at present, no read → Delivered', () {
      final messages = mapLocalMessagesToChatMessages(
        [
          _localMessage(
            id: 1,
            senderId: _myUserId,
            receiptDeliveredAt: DateTime(2026, 5, 11, 22, 1),
          ),
        ],
        myUserId: _myUserId,
        readReceiptForOwn: (_) => false,
        apiBaseUrl: _apiBaseUrl,
      );

      expect(messages.single.status, MessageStatus.delivered);
    });

    test('read_at present → Seen', () {
      final messages = mapLocalMessagesToChatMessages(
        [
          _localMessage(
            id: 1,
            senderId: _myUserId,
            receiptDeliveredAt: DateTime(2026, 5, 11, 22, 1),
            receiptReadAt: DateTime(2026, 5, 11, 22, 2),
          ),
        ],
        myUserId: _myUserId,
        readReceiptForOwn: (_) => false,
        apiBaseUrl: _apiBaseUrl,
      );

      expect(messages.single.status, MessageStatus.seen);
    });

    test('peer cursor advanced past message id (DM) → Seen even without per-message read_at', () {
      final messages = mapLocalMessagesToChatMessages(
        [_localMessage(id: 5, senderId: _myUserId)],
        myUserId: _myUserId,
        // Caller (cubit) decides if peer cursor covered this message id.
        readReceiptForOwn: (id) => id == 5,
        apiBaseUrl: _apiBaseUrl,
      );

      expect(messages.single.status, MessageStatus.seen);
    });

    test('peer messages have null status (no checkmarks shown)', () {
      final messages = mapLocalMessagesToChatMessages(
        [_localMessage(id: 1, senderId: _peerUserId)],
        myUserId: _myUserId,
        readReceiptForOwn: (_) => false,
        apiBaseUrl: _apiBaseUrl,
      );

      expect(messages.single.status, isNull);
    });
  });

  group('mapPendingOutboxToChatMessages', () {
    test('text outbox row → text Message with Sending status and pending_ id', () {
      final pending = [_outboxRow(localId: 'abc', body: 'hello')];

      final messages = mapPendingOutboxToChatMessages(
        pending,
        myUserId: _myUserId,
      );

      expect(messages, hasLength(1));
      final m = messages.single;
      expect(m, isA<TextMessage>());
      expect(m.id, '${kPendingMessagePrefix}abc');
      expect(m.id.startsWith(kPendingMessagePrefix), isTrue);
      expect(m.status, MessageStatus.sending);
      expect((m as TextMessage).text, 'hello');
      expect(m.authorId, '$_myUserId');
    });

    test('sticker outbox row → custom Message with sending status and emoji metadata', () {
      final pending = [
        _outboxRow(
          localId: 'sticker-1',
          contentType: kMamanaStickerContentType,
          body: '{"sticker_id":"wave","emoji":"👋"}',
        ),
      ];

      final messages = mapPendingOutboxToChatMessages(
        pending,
        myUserId: _myUserId,
      );

      expect(messages.single.status, MessageStatus.sending);
      expect(messages.single, isA<CustomMessage>());
      expect(
        (messages.single as CustomMessage).metadata?['mamanaStickerEmoji'],
        '👋',
      );
    });

    test('image media outbox row → image Message pointing at file://', () {
      final pending = [
        _outboxRow(
          localId: 'img-1',
          contentType: kMamanaMediaContentType,
          mediaPath: '/tmp/photo.jpg',
          mediaMime: 'image/jpeg',
          mediaKind: 'image',
        ),
      ];

      final messages = mapPendingOutboxToChatMessages(
        pending,
        myUserId: _myUserId,
      );

      expect(messages.single.status, MessageStatus.sending);
      expect(messages.single, isA<ImageMessage>());
      expect((messages.single as ImageMessage).source, 'file:///tmp/photo.jpg');
    });

    test('voice media outbox row → audio Message with duration', () {
      final pending = [
        _outboxRow(
          localId: 'voice-1',
          contentType: kMamanaMediaContentType,
          mediaPath: '/tmp/voice.m4a',
          mediaMime: 'audio/mp4',
          mediaKind: 'voice',
          mediaDurationMs: 3500,
        ),
      ];

      final messages = mapPendingOutboxToChatMessages(
        pending,
        myUserId: _myUserId,
      );

      final m = messages.single;
      expect(m, isA<AudioMessage>());
      expect((m as AudioMessage).source, 'file:///tmp/voice.m4a');
      expect(m.duration, const Duration(milliseconds: 3500));
      expect(m.status, MessageStatus.sending);
    });

    test('video media outbox row → video Message', () {
      final pending = [
        _outboxRow(
          localId: 'vid-1',
          contentType: kMamanaMediaContentType,
          mediaPath: '/tmp/clip.mp4',
          mediaMime: 'video/mp4',
          mediaKind: 'video',
        ),
      ];

      final messages = mapPendingOutboxToChatMessages(
        pending,
        myUserId: _myUserId,
      );

      expect(messages.single, isA<VideoMessage>());
      expect((messages.single as VideoMessage).source, 'file:///tmp/clip.mp4');
      expect(messages.single.status, MessageStatus.sending);
    });
  });

  group('ThreadState', () {
    test('default has empty pending list', () {
      const s = ThreadState();
      expect(s.pending, isEmpty);
      expect(s.messages, isEmpty);
    });

    test('copyWith preserves pending unless overridden', () {
      final pending = [_outboxRow(localId: 'p1')];
      final base = const ThreadState().copyWith(pending: pending);

      final next = base.copyWith(loading: true);
      expect(next.pending, same(pending));
      expect(next.loading, isTrue);
    });

    test('readReceiptForOwnMessage returns false when conversation is not private', () {
      const s = ThreadState(readCursorByUserId: {7: 99});
      expect(s.readReceiptForOwnMessage(50, 'group'), isFalse);
    });

    test('readReceiptForOwnMessage returns true when peer cursor reached message id', () {
      const s = ThreadState(readCursorByUserId: {7: 99});
      expect(s.readReceiptForOwnMessage(99, 'private'), isTrue);
      expect(s.readReceiptForOwnMessage(50, 'private'), isTrue);
      expect(s.readReceiptForOwnMessage(100, 'private'), isFalse);
    });
  });
}
