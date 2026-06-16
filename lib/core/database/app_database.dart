import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class LocalConversations extends Table {
  IntColumn get id => integer()();
  TextColumn get type => text()();
  TextColumn get title => text().nullable()();
  TextColumn get peerJson => text().nullable()();
  TextColumn get lastMessagePreview => text().nullable()();
  DateTimeColumn get lastMessageAt => dateTime().nullable()();
  /// Server `unread_count` from list / GET conversation.
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class LocalMessages extends Table {
  IntColumn get id => integer()();
  IntColumn get conversationId => integer()();
  IntColumn get senderId => integer()();
  TextColumn get body => text()();
  TextColumn get contentType => text().withDefault(const Constant('text/plain'))();
  IntColumn get replyToMessageId => integer().nullable()();
  IntColumn get storyMediaId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  /// From API `edited_at` when the sender has edited the message.
  DateTimeColumn get editedAt => dateTime().nullable()();
  /// From API `receipt`: for own messages in a DM = peer delivery/read; for others = local read state.
  DateTimeColumn get receiptDeliveredAt => dateTime().nullable()();
  DateTimeColumn get receiptReadAt => dateTime().nullable()();
  /// Serialised JSON array of `{user_id, emoji}` objects from the API `reactions` field.
  /// Cached so reactions are available immediately from local DB before the remote fetch completes.
  TextColumn get reactionsJson => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Pending sends when offline (M5). Also used for optimistic UI on every send:
/// a row is inserted immediately so the bubble appears with a clock icon, then
/// removed once the server returns the persisted [LocalMessage].
class MessageOutbox extends Table {
  TextColumn get localId => text()();
  IntColumn get conversationId => integer()();
  TextColumn get body => text()();
  IntColumn get replyToMessageId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// Wire `content_type` so non-text outbox rows (sticker / media JSON) can
  /// flush through the right send path.
  TextColumn get contentType =>
      text().withDefault(const Constant('text/plain'))();

  /// Story-reply messages keep their `story_media_id` while pending.
  IntColumn get storyMediaId => integer().nullable()();

  /// Local file path for media uploads still pending presign + PUT.
  TextColumn get mediaPath => text().nullable()();
  TextColumn get mediaMime => text().nullable()();

  /// `image` | `video` | `voice` | `sticker` — drives the upload pipeline.
  TextColumn get mediaKind => text().nullable()();
  IntColumn get mediaDurationMs => integer().nullable()();

  /// Optional caption typed on the pre-send preview screen.
  TextColumn get mediaCaption => text().nullable()();

  /// Number of failed send attempts (incremented on each network failure).
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Timestamp of the most recent failure — surfaces a small error tint while
  /// the bubble stays in the pending state until the next retry succeeds.
  DateTimeColumn get lastErrorAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {localId};
}

@DriftDatabase(tables: [LocalConversations, LocalMessages, MessageOutbox])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.addColumn(localMessages, localMessages.receiptDeliveredAt);
            await m.addColumn(localMessages, localMessages.receiptReadAt);
          }
          if (from < 3) {
            await m.addColumn(localConversations, localConversations.lastMessagePreview);
            await m.addColumn(localConversations, localConversations.lastMessageAt);
          }
          if (from < 4) {
            await m.addColumn(localConversations, localConversations.unreadCount);
          }
          if (from < 5) {
            await m.addColumn(localMessages, localMessages.storyMediaId);
          }
          if (from < 6) {
            await m.addColumn(messageOutbox, messageOutbox.contentType);
            await m.addColumn(messageOutbox, messageOutbox.storyMediaId);
            await m.addColumn(messageOutbox, messageOutbox.mediaPath);
            await m.addColumn(messageOutbox, messageOutbox.mediaMime);
            await m.addColumn(messageOutbox, messageOutbox.mediaKind);
            await m.addColumn(messageOutbox, messageOutbox.mediaDurationMs);
            await m.addColumn(messageOutbox, messageOutbox.attempts);
            await m.addColumn(messageOutbox, messageOutbox.lastErrorAt);
          }
          if (from < 7) {
            await m.addColumn(localMessages, localMessages.editedAt);
          }
          if (from < 8) {
            await m.addColumn(messageOutbox, messageOutbox.mediaCaption);
          }
          if (from < 9) {
            await m.addColumn(localMessages, localMessages.reactionsJson);
          }
        },
      );

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'mamana.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
