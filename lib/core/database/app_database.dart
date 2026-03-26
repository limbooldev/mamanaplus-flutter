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
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Pending sends when offline (M5).
class MessageOutbox extends Table {
  TextColumn get localId => text()();
  IntColumn get conversationId => integer()();
  TextColumn get body => text()();
  IntColumn get replyToMessageId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {localId};
}

@DriftDatabase(tables: [LocalConversations, LocalMessages, MessageOutbox])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'mamana.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
