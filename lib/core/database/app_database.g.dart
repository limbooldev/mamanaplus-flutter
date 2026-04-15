// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalConversationsTable extends LocalConversations
    with TableInfo<$LocalConversationsTable, LocalConversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _peerJsonMeta = const VerificationMeta(
    'peerJson',
  );
  @override
  late final GeneratedColumn<String> peerJson = GeneratedColumn<String>(
    'peer_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMessagePreviewMeta =
      const VerificationMeta('lastMessagePreview');
  @override
  late final GeneratedColumn<String> lastMessagePreview =
      GeneratedColumn<String>(
        'last_message_preview',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastMessageAtMeta = const VerificationMeta(
    'lastMessageAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastMessageAt =
      GeneratedColumn<DateTime>(
        'last_message_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _unreadCountMeta = const VerificationMeta(
    'unreadCount',
  );
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
    'unread_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    title,
    peerJson,
    lastMessagePreview,
    lastMessageAt,
    unreadCount,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalConversation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('peer_json')) {
      context.handle(
        _peerJsonMeta,
        peerJson.isAcceptableOrUnknown(data['peer_json']!, _peerJsonMeta),
      );
    }
    if (data.containsKey('last_message_preview')) {
      context.handle(
        _lastMessagePreviewMeta,
        lastMessagePreview.isAcceptableOrUnknown(
          data['last_message_preview']!,
          _lastMessagePreviewMeta,
        ),
      );
    }
    if (data.containsKey('last_message_at')) {
      context.handle(
        _lastMessageAtMeta,
        lastMessageAt.isAcceptableOrUnknown(
          data['last_message_at']!,
          _lastMessageAtMeta,
        ),
      );
    }
    if (data.containsKey('unread_count')) {
      context.handle(
        _unreadCountMeta,
        unreadCount.isAcceptableOrUnknown(
          data['unread_count']!,
          _unreadCountMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalConversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalConversation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      peerJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_json'],
      ),
      lastMessagePreview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_preview'],
      ),
      lastMessageAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_message_at'],
      ),
      unreadCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unread_count'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalConversationsTable createAlias(String alias) {
    return $LocalConversationsTable(attachedDatabase, alias);
  }
}

class LocalConversation extends DataClass
    implements Insertable<LocalConversation> {
  final int id;
  final String type;
  final String? title;
  final String? peerJson;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;

  /// Server `unread_count` from list / GET conversation.
  final int unreadCount;
  final DateTime updatedAt;
  const LocalConversation({
    required this.id,
    required this.type,
    this.title,
    this.peerJson,
    this.lastMessagePreview,
    this.lastMessageAt,
    required this.unreadCount,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || peerJson != null) {
      map['peer_json'] = Variable<String>(peerJson);
    }
    if (!nullToAbsent || lastMessagePreview != null) {
      map['last_message_preview'] = Variable<String>(lastMessagePreview);
    }
    if (!nullToAbsent || lastMessageAt != null) {
      map['last_message_at'] = Variable<DateTime>(lastMessageAt);
    }
    map['unread_count'] = Variable<int>(unreadCount);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalConversationsCompanion toCompanion(bool nullToAbsent) {
    return LocalConversationsCompanion(
      id: Value(id),
      type: Value(type),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      peerJson: peerJson == null && nullToAbsent
          ? const Value.absent()
          : Value(peerJson),
      lastMessagePreview: lastMessagePreview == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessagePreview),
      lastMessageAt: lastMessageAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageAt),
      unreadCount: Value(unreadCount),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalConversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalConversation(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String?>(json['title']),
      peerJson: serializer.fromJson<String?>(json['peerJson']),
      lastMessagePreview: serializer.fromJson<String?>(
        json['lastMessagePreview'],
      ),
      lastMessageAt: serializer.fromJson<DateTime?>(json['lastMessageAt']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String?>(title),
      'peerJson': serializer.toJson<String?>(peerJson),
      'lastMessagePreview': serializer.toJson<String?>(lastMessagePreview),
      'lastMessageAt': serializer.toJson<DateTime?>(lastMessageAt),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalConversation copyWith({
    int? id,
    String? type,
    Value<String?> title = const Value.absent(),
    Value<String?> peerJson = const Value.absent(),
    Value<String?> lastMessagePreview = const Value.absent(),
    Value<DateTime?> lastMessageAt = const Value.absent(),
    int? unreadCount,
    DateTime? updatedAt,
  }) => LocalConversation(
    id: id ?? this.id,
    type: type ?? this.type,
    title: title.present ? title.value : this.title,
    peerJson: peerJson.present ? peerJson.value : this.peerJson,
    lastMessagePreview: lastMessagePreview.present
        ? lastMessagePreview.value
        : this.lastMessagePreview,
    lastMessageAt: lastMessageAt.present
        ? lastMessageAt.value
        : this.lastMessageAt,
    unreadCount: unreadCount ?? this.unreadCount,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalConversation copyWithCompanion(LocalConversationsCompanion data) {
    return LocalConversation(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      peerJson: data.peerJson.present ? data.peerJson.value : this.peerJson,
      lastMessagePreview: data.lastMessagePreview.present
          ? data.lastMessagePreview.value
          : this.lastMessagePreview,
      lastMessageAt: data.lastMessageAt.present
          ? data.lastMessageAt.value
          : this.lastMessageAt,
      unreadCount: data.unreadCount.present
          ? data.unreadCount.value
          : this.unreadCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalConversation(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('peerJson: $peerJson, ')
          ..write('lastMessagePreview: $lastMessagePreview, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    title,
    peerJson,
    lastMessagePreview,
    lastMessageAt,
    unreadCount,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalConversation &&
          other.id == this.id &&
          other.type == this.type &&
          other.title == this.title &&
          other.peerJson == this.peerJson &&
          other.lastMessagePreview == this.lastMessagePreview &&
          other.lastMessageAt == this.lastMessageAt &&
          other.unreadCount == this.unreadCount &&
          other.updatedAt == this.updatedAt);
}

class LocalConversationsCompanion extends UpdateCompanion<LocalConversation> {
  final Value<int> id;
  final Value<String> type;
  final Value<String?> title;
  final Value<String?> peerJson;
  final Value<String?> lastMessagePreview;
  final Value<DateTime?> lastMessageAt;
  final Value<int> unreadCount;
  final Value<DateTime> updatedAt;
  const LocalConversationsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.peerJson = const Value.absent(),
    this.lastMessagePreview = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LocalConversationsCompanion.insert({
    this.id = const Value.absent(),
    required String type,
    this.title = const Value.absent(),
    this.peerJson = const Value.absent(),
    this.lastMessagePreview = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.unreadCount = const Value.absent(),
    required DateTime updatedAt,
  }) : type = Value(type),
       updatedAt = Value(updatedAt);
  static Insertable<LocalConversation> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? peerJson,
    Expression<String>? lastMessagePreview,
    Expression<DateTime>? lastMessageAt,
    Expression<int>? unreadCount,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (peerJson != null) 'peer_json': peerJson,
      if (lastMessagePreview != null)
        'last_message_preview': lastMessagePreview,
      if (lastMessageAt != null) 'last_message_at': lastMessageAt,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  LocalConversationsCompanion copyWith({
    Value<int>? id,
    Value<String>? type,
    Value<String?>? title,
    Value<String?>? peerJson,
    Value<String?>? lastMessagePreview,
    Value<DateTime?>? lastMessageAt,
    Value<int>? unreadCount,
    Value<DateTime>? updatedAt,
  }) {
    return LocalConversationsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      peerJson: peerJson ?? this.peerJson,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (peerJson.present) {
      map['peer_json'] = Variable<String>(peerJson.value);
    }
    if (lastMessagePreview.present) {
      map['last_message_preview'] = Variable<String>(lastMessagePreview.value);
    }
    if (lastMessageAt.present) {
      map['last_message_at'] = Variable<DateTime>(lastMessageAt.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalConversationsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('peerJson: $peerJson, ')
          ..write('lastMessagePreview: $lastMessagePreview, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $LocalMessagesTable extends LocalMessages
    with TableInfo<$LocalMessagesTable, LocalMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<int> conversationId = GeneratedColumn<int>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderIdMeta = const VerificationMeta(
    'senderId',
  );
  @override
  late final GeneratedColumn<int> senderId = GeneratedColumn<int>(
    'sender_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentTypeMeta = const VerificationMeta(
    'contentType',
  );
  @override
  late final GeneratedColumn<String> contentType = GeneratedColumn<String>(
    'content_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('text/plain'),
  );
  static const VerificationMeta _replyToMessageIdMeta = const VerificationMeta(
    'replyToMessageId',
  );
  @override
  late final GeneratedColumn<int> replyToMessageId = GeneratedColumn<int>(
    'reply_to_message_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receiptDeliveredAtMeta =
      const VerificationMeta('receiptDeliveredAt');
  @override
  late final GeneratedColumn<DateTime> receiptDeliveredAt =
      GeneratedColumn<DateTime>(
        'receipt_delivered_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _receiptReadAtMeta = const VerificationMeta(
    'receiptReadAt',
  );
  @override
  late final GeneratedColumn<DateTime> receiptReadAt =
      GeneratedColumn<DateTime>(
        'receipt_read_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    senderId,
    body,
    contentType,
    replyToMessageId,
    createdAt,
    receiptDeliveredAt,
    receiptReadAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('content_type')) {
      context.handle(
        _contentTypeMeta,
        contentType.isAcceptableOrUnknown(
          data['content_type']!,
          _contentTypeMeta,
        ),
      );
    }
    if (data.containsKey('reply_to_message_id')) {
      context.handle(
        _replyToMessageIdMeta,
        replyToMessageId.isAcceptableOrUnknown(
          data['reply_to_message_id']!,
          _replyToMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('receipt_delivered_at')) {
      context.handle(
        _receiptDeliveredAtMeta,
        receiptDeliveredAt.isAcceptableOrUnknown(
          data['receipt_delivered_at']!,
          _receiptDeliveredAtMeta,
        ),
      );
    }
    if (data.containsKey('receipt_read_at')) {
      context.handle(
        _receiptReadAtMeta,
        receiptReadAt.isAcceptableOrUnknown(
          data['receipt_read_at']!,
          _receiptReadAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}conversation_id'],
      )!,
      senderId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sender_id'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      contentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_type'],
      )!,
      replyToMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reply_to_message_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      receiptDeliveredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}receipt_delivered_at'],
      ),
      receiptReadAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}receipt_read_at'],
      ),
    );
  }

  @override
  $LocalMessagesTable createAlias(String alias) {
    return $LocalMessagesTable(attachedDatabase, alias);
  }
}

class LocalMessage extends DataClass implements Insertable<LocalMessage> {
  final int id;
  final int conversationId;
  final int senderId;
  final String body;
  final String contentType;
  final int? replyToMessageId;
  final DateTime createdAt;

  /// From API `receipt`: for own messages in a DM = peer delivery/read; for others = local read state.
  final DateTime? receiptDeliveredAt;
  final DateTime? receiptReadAt;
  const LocalMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.contentType,
    this.replyToMessageId,
    required this.createdAt,
    this.receiptDeliveredAt,
    this.receiptReadAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['conversation_id'] = Variable<int>(conversationId);
    map['sender_id'] = Variable<int>(senderId);
    map['body'] = Variable<String>(body);
    map['content_type'] = Variable<String>(contentType);
    if (!nullToAbsent || replyToMessageId != null) {
      map['reply_to_message_id'] = Variable<int>(replyToMessageId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || receiptDeliveredAt != null) {
      map['receipt_delivered_at'] = Variable<DateTime>(receiptDeliveredAt);
    }
    if (!nullToAbsent || receiptReadAt != null) {
      map['receipt_read_at'] = Variable<DateTime>(receiptReadAt);
    }
    return map;
  }

  LocalMessagesCompanion toCompanion(bool nullToAbsent) {
    return LocalMessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      senderId: Value(senderId),
      body: Value(body),
      contentType: Value(contentType),
      replyToMessageId: replyToMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToMessageId),
      createdAt: Value(createdAt),
      receiptDeliveredAt: receiptDeliveredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptDeliveredAt),
      receiptReadAt: receiptReadAt == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptReadAt),
    );
  }

  factory LocalMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMessage(
      id: serializer.fromJson<int>(json['id']),
      conversationId: serializer.fromJson<int>(json['conversationId']),
      senderId: serializer.fromJson<int>(json['senderId']),
      body: serializer.fromJson<String>(json['body']),
      contentType: serializer.fromJson<String>(json['contentType']),
      replyToMessageId: serializer.fromJson<int?>(json['replyToMessageId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      receiptDeliveredAt: serializer.fromJson<DateTime?>(
        json['receiptDeliveredAt'],
      ),
      receiptReadAt: serializer.fromJson<DateTime?>(json['receiptReadAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'conversationId': serializer.toJson<int>(conversationId),
      'senderId': serializer.toJson<int>(senderId),
      'body': serializer.toJson<String>(body),
      'contentType': serializer.toJson<String>(contentType),
      'replyToMessageId': serializer.toJson<int?>(replyToMessageId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'receiptDeliveredAt': serializer.toJson<DateTime?>(receiptDeliveredAt),
      'receiptReadAt': serializer.toJson<DateTime?>(receiptReadAt),
    };
  }

  LocalMessage copyWith({
    int? id,
    int? conversationId,
    int? senderId,
    String? body,
    String? contentType,
    Value<int?> replyToMessageId = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> receiptDeliveredAt = const Value.absent(),
    Value<DateTime?> receiptReadAt = const Value.absent(),
  }) => LocalMessage(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    senderId: senderId ?? this.senderId,
    body: body ?? this.body,
    contentType: contentType ?? this.contentType,
    replyToMessageId: replyToMessageId.present
        ? replyToMessageId.value
        : this.replyToMessageId,
    createdAt: createdAt ?? this.createdAt,
    receiptDeliveredAt: receiptDeliveredAt.present
        ? receiptDeliveredAt.value
        : this.receiptDeliveredAt,
    receiptReadAt: receiptReadAt.present
        ? receiptReadAt.value
        : this.receiptReadAt,
  );
  LocalMessage copyWithCompanion(LocalMessagesCompanion data) {
    return LocalMessage(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      body: data.body.present ? data.body.value : this.body,
      contentType: data.contentType.present
          ? data.contentType.value
          : this.contentType,
      replyToMessageId: data.replyToMessageId.present
          ? data.replyToMessageId.value
          : this.replyToMessageId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      receiptDeliveredAt: data.receiptDeliveredAt.present
          ? data.receiptDeliveredAt.value
          : this.receiptDeliveredAt,
      receiptReadAt: data.receiptReadAt.present
          ? data.receiptReadAt.value
          : this.receiptReadAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMessage(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('body: $body, ')
          ..write('contentType: $contentType, ')
          ..write('replyToMessageId: $replyToMessageId, ')
          ..write('createdAt: $createdAt, ')
          ..write('receiptDeliveredAt: $receiptDeliveredAt, ')
          ..write('receiptReadAt: $receiptReadAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    senderId,
    body,
    contentType,
    replyToMessageId,
    createdAt,
    receiptDeliveredAt,
    receiptReadAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMessage &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.senderId == this.senderId &&
          other.body == this.body &&
          other.contentType == this.contentType &&
          other.replyToMessageId == this.replyToMessageId &&
          other.createdAt == this.createdAt &&
          other.receiptDeliveredAt == this.receiptDeliveredAt &&
          other.receiptReadAt == this.receiptReadAt);
}

class LocalMessagesCompanion extends UpdateCompanion<LocalMessage> {
  final Value<int> id;
  final Value<int> conversationId;
  final Value<int> senderId;
  final Value<String> body;
  final Value<String> contentType;
  final Value<int?> replyToMessageId;
  final Value<DateTime> createdAt;
  final Value<DateTime?> receiptDeliveredAt;
  final Value<DateTime?> receiptReadAt;
  const LocalMessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.body = const Value.absent(),
    this.contentType = const Value.absent(),
    this.replyToMessageId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.receiptDeliveredAt = const Value.absent(),
    this.receiptReadAt = const Value.absent(),
  });
  LocalMessagesCompanion.insert({
    this.id = const Value.absent(),
    required int conversationId,
    required int senderId,
    required String body,
    this.contentType = const Value.absent(),
    this.replyToMessageId = const Value.absent(),
    required DateTime createdAt,
    this.receiptDeliveredAt = const Value.absent(),
    this.receiptReadAt = const Value.absent(),
  }) : conversationId = Value(conversationId),
       senderId = Value(senderId),
       body = Value(body),
       createdAt = Value(createdAt);
  static Insertable<LocalMessage> custom({
    Expression<int>? id,
    Expression<int>? conversationId,
    Expression<int>? senderId,
    Expression<String>? body,
    Expression<String>? contentType,
    Expression<int>? replyToMessageId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? receiptDeliveredAt,
    Expression<DateTime>? receiptReadAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (senderId != null) 'sender_id': senderId,
      if (body != null) 'body': body,
      if (contentType != null) 'content_type': contentType,
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      if (createdAt != null) 'created_at': createdAt,
      if (receiptDeliveredAt != null)
        'receipt_delivered_at': receiptDeliveredAt,
      if (receiptReadAt != null) 'receipt_read_at': receiptReadAt,
    });
  }

  LocalMessagesCompanion copyWith({
    Value<int>? id,
    Value<int>? conversationId,
    Value<int>? senderId,
    Value<String>? body,
    Value<String>? contentType,
    Value<int?>? replyToMessageId,
    Value<DateTime>? createdAt,
    Value<DateTime?>? receiptDeliveredAt,
    Value<DateTime?>? receiptReadAt,
  }) {
    return LocalMessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      body: body ?? this.body,
      contentType: contentType ?? this.contentType,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      createdAt: createdAt ?? this.createdAt,
      receiptDeliveredAt: receiptDeliveredAt ?? this.receiptDeliveredAt,
      receiptReadAt: receiptReadAt ?? this.receiptReadAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<int>(conversationId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<int>(senderId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (contentType.present) {
      map['content_type'] = Variable<String>(contentType.value);
    }
    if (replyToMessageId.present) {
      map['reply_to_message_id'] = Variable<int>(replyToMessageId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (receiptDeliveredAt.present) {
      map['receipt_delivered_at'] = Variable<DateTime>(
        receiptDeliveredAt.value,
      );
    }
    if (receiptReadAt.present) {
      map['receipt_read_at'] = Variable<DateTime>(receiptReadAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('body: $body, ')
          ..write('contentType: $contentType, ')
          ..write('replyToMessageId: $replyToMessageId, ')
          ..write('createdAt: $createdAt, ')
          ..write('receiptDeliveredAt: $receiptDeliveredAt, ')
          ..write('receiptReadAt: $receiptReadAt')
          ..write(')'))
        .toString();
  }
}

class $MessageOutboxTable extends MessageOutbox
    with TableInfo<$MessageOutboxTable, MessageOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<int> conversationId = GeneratedColumn<int>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _replyToMessageIdMeta = const VerificationMeta(
    'replyToMessageId',
  );
  @override
  late final GeneratedColumn<int> replyToMessageId = GeneratedColumn<int>(
    'reply_to_message_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    conversationId,
    body,
    replyToMessageId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageOutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('reply_to_message_id')) {
      context.handle(
        _replyToMessageIdMeta,
        replyToMessageId.isAcceptableOrUnknown(
          data['reply_to_message_id']!,
          _replyToMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  MessageOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageOutboxData(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}conversation_id'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      replyToMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reply_to_message_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MessageOutboxTable createAlias(String alias) {
    return $MessageOutboxTable(attachedDatabase, alias);
  }
}

class MessageOutboxData extends DataClass
    implements Insertable<MessageOutboxData> {
  final String localId;
  final int conversationId;
  final String body;
  final int? replyToMessageId;
  final DateTime createdAt;
  const MessageOutboxData({
    required this.localId,
    required this.conversationId,
    required this.body,
    this.replyToMessageId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    map['conversation_id'] = Variable<int>(conversationId);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || replyToMessageId != null) {
      map['reply_to_message_id'] = Variable<int>(replyToMessageId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MessageOutboxCompanion toCompanion(bool nullToAbsent) {
    return MessageOutboxCompanion(
      localId: Value(localId),
      conversationId: Value(conversationId),
      body: Value(body),
      replyToMessageId: replyToMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToMessageId),
      createdAt: Value(createdAt),
    );
  }

  factory MessageOutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageOutboxData(
      localId: serializer.fromJson<String>(json['localId']),
      conversationId: serializer.fromJson<int>(json['conversationId']),
      body: serializer.fromJson<String>(json['body']),
      replyToMessageId: serializer.fromJson<int?>(json['replyToMessageId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'conversationId': serializer.toJson<int>(conversationId),
      'body': serializer.toJson<String>(body),
      'replyToMessageId': serializer.toJson<int?>(replyToMessageId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MessageOutboxData copyWith({
    String? localId,
    int? conversationId,
    String? body,
    Value<int?> replyToMessageId = const Value.absent(),
    DateTime? createdAt,
  }) => MessageOutboxData(
    localId: localId ?? this.localId,
    conversationId: conversationId ?? this.conversationId,
    body: body ?? this.body,
    replyToMessageId: replyToMessageId.present
        ? replyToMessageId.value
        : this.replyToMessageId,
    createdAt: createdAt ?? this.createdAt,
  );
  MessageOutboxData copyWithCompanion(MessageOutboxCompanion data) {
    return MessageOutboxData(
      localId: data.localId.present ? data.localId.value : this.localId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      body: data.body.present ? data.body.value : this.body,
      replyToMessageId: data.replyToMessageId.present
          ? data.replyToMessageId.value
          : this.replyToMessageId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageOutboxData(')
          ..write('localId: $localId, ')
          ..write('conversationId: $conversationId, ')
          ..write('body: $body, ')
          ..write('replyToMessageId: $replyToMessageId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(localId, conversationId, body, replyToMessageId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageOutboxData &&
          other.localId == this.localId &&
          other.conversationId == this.conversationId &&
          other.body == this.body &&
          other.replyToMessageId == this.replyToMessageId &&
          other.createdAt == this.createdAt);
}

class MessageOutboxCompanion extends UpdateCompanion<MessageOutboxData> {
  final Value<String> localId;
  final Value<int> conversationId;
  final Value<String> body;
  final Value<int?> replyToMessageId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MessageOutboxCompanion({
    this.localId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.body = const Value.absent(),
    this.replyToMessageId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageOutboxCompanion.insert({
    required String localId,
    required int conversationId,
    required String body,
    this.replyToMessageId = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : localId = Value(localId),
       conversationId = Value(conversationId),
       body = Value(body),
       createdAt = Value(createdAt);
  static Insertable<MessageOutboxData> custom({
    Expression<String>? localId,
    Expression<int>? conversationId,
    Expression<String>? body,
    Expression<int>? replyToMessageId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (body != null) 'body': body,
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageOutboxCompanion copyWith({
    Value<String>? localId,
    Value<int>? conversationId,
    Value<String>? body,
    Value<int?>? replyToMessageId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return MessageOutboxCompanion(
      localId: localId ?? this.localId,
      conversationId: conversationId ?? this.conversationId,
      body: body ?? this.body,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<int>(conversationId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (replyToMessageId.present) {
      map['reply_to_message_id'] = Variable<int>(replyToMessageId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageOutboxCompanion(')
          ..write('localId: $localId, ')
          ..write('conversationId: $conversationId, ')
          ..write('body: $body, ')
          ..write('replyToMessageId: $replyToMessageId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalConversationsTable localConversations =
      $LocalConversationsTable(this);
  late final $LocalMessagesTable localMessages = $LocalMessagesTable(this);
  late final $MessageOutboxTable messageOutbox = $MessageOutboxTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localConversations,
    localMessages,
    messageOutbox,
  ];
}

typedef $$LocalConversationsTableCreateCompanionBuilder =
    LocalConversationsCompanion Function({
      Value<int> id,
      required String type,
      Value<String?> title,
      Value<String?> peerJson,
      Value<String?> lastMessagePreview,
      Value<DateTime?> lastMessageAt,
      Value<int> unreadCount,
      required DateTime updatedAt,
    });
typedef $$LocalConversationsTableUpdateCompanionBuilder =
    LocalConversationsCompanion Function({
      Value<int> id,
      Value<String> type,
      Value<String?> title,
      Value<String?> peerJson,
      Value<String?> lastMessagePreview,
      Value<DateTime?> lastMessageAt,
      Value<int> unreadCount,
      Value<DateTime> updatedAt,
    });

class $$LocalConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalConversationsTable> {
  $$LocalConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerJson => $composableBuilder(
    column: $table.peerJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessagePreview => $composableBuilder(
    column: $table.lastMessagePreview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalConversationsTable> {
  $$LocalConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerJson => $composableBuilder(
    column: $table.peerJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessagePreview => $composableBuilder(
    column: $table.lastMessagePreview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalConversationsTable> {
  $$LocalConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get peerJson =>
      $composableBuilder(column: $table.peerJson, builder: (column) => column);

  GeneratedColumn<String> get lastMessagePreview => $composableBuilder(
    column: $table.lastMessagePreview,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalConversationsTable,
          LocalConversation,
          $$LocalConversationsTableFilterComposer,
          $$LocalConversationsTableOrderingComposer,
          $$LocalConversationsTableAnnotationComposer,
          $$LocalConversationsTableCreateCompanionBuilder,
          $$LocalConversationsTableUpdateCompanionBuilder,
          (
            LocalConversation,
            BaseReferences<
              _$AppDatabase,
              $LocalConversationsTable,
              LocalConversation
            >,
          ),
          LocalConversation,
          PrefetchHooks Function()
        > {
  $$LocalConversationsTableTableManager(
    _$AppDatabase db,
    $LocalConversationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalConversationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> peerJson = const Value.absent(),
                Value<String?> lastMessagePreview = const Value.absent(),
                Value<DateTime?> lastMessageAt = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LocalConversationsCompanion(
                id: id,
                type: type,
                title: title,
                peerJson: peerJson,
                lastMessagePreview: lastMessagePreview,
                lastMessageAt: lastMessageAt,
                unreadCount: unreadCount,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String type,
                Value<String?> title = const Value.absent(),
                Value<String?> peerJson = const Value.absent(),
                Value<String?> lastMessagePreview = const Value.absent(),
                Value<DateTime?> lastMessageAt = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                required DateTime updatedAt,
              }) => LocalConversationsCompanion.insert(
                id: id,
                type: type,
                title: title,
                peerJson: peerJson,
                lastMessagePreview: lastMessagePreview,
                lastMessageAt: lastMessageAt,
                unreadCount: unreadCount,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalConversationsTable,
      LocalConversation,
      $$LocalConversationsTableFilterComposer,
      $$LocalConversationsTableOrderingComposer,
      $$LocalConversationsTableAnnotationComposer,
      $$LocalConversationsTableCreateCompanionBuilder,
      $$LocalConversationsTableUpdateCompanionBuilder,
      (
        LocalConversation,
        BaseReferences<
          _$AppDatabase,
          $LocalConversationsTable,
          LocalConversation
        >,
      ),
      LocalConversation,
      PrefetchHooks Function()
    >;
typedef $$LocalMessagesTableCreateCompanionBuilder =
    LocalMessagesCompanion Function({
      Value<int> id,
      required int conversationId,
      required int senderId,
      required String body,
      Value<String> contentType,
      Value<int?> replyToMessageId,
      required DateTime createdAt,
      Value<DateTime?> receiptDeliveredAt,
      Value<DateTime?> receiptReadAt,
    });
typedef $$LocalMessagesTableUpdateCompanionBuilder =
    LocalMessagesCompanion Function({
      Value<int> id,
      Value<int> conversationId,
      Value<int> senderId,
      Value<String> body,
      Value<String> contentType,
      Value<int?> replyToMessageId,
      Value<DateTime> createdAt,
      Value<DateTime?> receiptDeliveredAt,
      Value<DateTime?> receiptReadAt,
    });

class $$LocalMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalMessagesTable> {
  $$LocalMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get replyToMessageId => $composableBuilder(
    column: $table.replyToMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get receiptDeliveredAt => $composableBuilder(
    column: $table.receiptDeliveredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get receiptReadAt => $composableBuilder(
    column: $table.receiptReadAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalMessagesTable> {
  $$LocalMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get replyToMessageId => $composableBuilder(
    column: $table.replyToMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get receiptDeliveredAt => $composableBuilder(
    column: $table.receiptDeliveredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get receiptReadAt => $composableBuilder(
    column: $table.receiptReadAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalMessagesTable> {
  $$LocalMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get replyToMessageId => $composableBuilder(
    column: $table.replyToMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get receiptDeliveredAt => $composableBuilder(
    column: $table.receiptDeliveredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get receiptReadAt => $composableBuilder(
    column: $table.receiptReadAt,
    builder: (column) => column,
  );
}

class $$LocalMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalMessagesTable,
          LocalMessage,
          $$LocalMessagesTableFilterComposer,
          $$LocalMessagesTableOrderingComposer,
          $$LocalMessagesTableAnnotationComposer,
          $$LocalMessagesTableCreateCompanionBuilder,
          $$LocalMessagesTableUpdateCompanionBuilder,
          (
            LocalMessage,
            BaseReferences<_$AppDatabase, $LocalMessagesTable, LocalMessage>,
          ),
          LocalMessage,
          PrefetchHooks Function()
        > {
  $$LocalMessagesTableTableManager(_$AppDatabase db, $LocalMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> conversationId = const Value.absent(),
                Value<int> senderId = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> contentType = const Value.absent(),
                Value<int?> replyToMessageId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> receiptDeliveredAt = const Value.absent(),
                Value<DateTime?> receiptReadAt = const Value.absent(),
              }) => LocalMessagesCompanion(
                id: id,
                conversationId: conversationId,
                senderId: senderId,
                body: body,
                contentType: contentType,
                replyToMessageId: replyToMessageId,
                createdAt: createdAt,
                receiptDeliveredAt: receiptDeliveredAt,
                receiptReadAt: receiptReadAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int conversationId,
                required int senderId,
                required String body,
                Value<String> contentType = const Value.absent(),
                Value<int?> replyToMessageId = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> receiptDeliveredAt = const Value.absent(),
                Value<DateTime?> receiptReadAt = const Value.absent(),
              }) => LocalMessagesCompanion.insert(
                id: id,
                conversationId: conversationId,
                senderId: senderId,
                body: body,
                contentType: contentType,
                replyToMessageId: replyToMessageId,
                createdAt: createdAt,
                receiptDeliveredAt: receiptDeliveredAt,
                receiptReadAt: receiptReadAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalMessagesTable,
      LocalMessage,
      $$LocalMessagesTableFilterComposer,
      $$LocalMessagesTableOrderingComposer,
      $$LocalMessagesTableAnnotationComposer,
      $$LocalMessagesTableCreateCompanionBuilder,
      $$LocalMessagesTableUpdateCompanionBuilder,
      (
        LocalMessage,
        BaseReferences<_$AppDatabase, $LocalMessagesTable, LocalMessage>,
      ),
      LocalMessage,
      PrefetchHooks Function()
    >;
typedef $$MessageOutboxTableCreateCompanionBuilder =
    MessageOutboxCompanion Function({
      required String localId,
      required int conversationId,
      required String body,
      Value<int?> replyToMessageId,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$MessageOutboxTableUpdateCompanionBuilder =
    MessageOutboxCompanion Function({
      Value<String> localId,
      Value<int> conversationId,
      Value<String> body,
      Value<int?> replyToMessageId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$MessageOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $MessageOutboxTable> {
  $$MessageOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get replyToMessageId => $composableBuilder(
    column: $table.replyToMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessageOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageOutboxTable> {
  $$MessageOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get replyToMessageId => $composableBuilder(
    column: $table.replyToMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessageOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageOutboxTable> {
  $$MessageOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<int> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get replyToMessageId => $composableBuilder(
    column: $table.replyToMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MessageOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessageOutboxTable,
          MessageOutboxData,
          $$MessageOutboxTableFilterComposer,
          $$MessageOutboxTableOrderingComposer,
          $$MessageOutboxTableAnnotationComposer,
          $$MessageOutboxTableCreateCompanionBuilder,
          $$MessageOutboxTableUpdateCompanionBuilder,
          (
            MessageOutboxData,
            BaseReferences<
              _$AppDatabase,
              $MessageOutboxTable,
              MessageOutboxData
            >,
          ),
          MessageOutboxData,
          PrefetchHooks Function()
        > {
  $$MessageOutboxTableTableManager(_$AppDatabase db, $MessageOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> localId = const Value.absent(),
                Value<int> conversationId = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int?> replyToMessageId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageOutboxCompanion(
                localId: localId,
                conversationId: conversationId,
                body: body,
                replyToMessageId: replyToMessageId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localId,
                required int conversationId,
                required String body,
                Value<int?> replyToMessageId = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MessageOutboxCompanion.insert(
                localId: localId,
                conversationId: conversationId,
                body: body,
                replyToMessageId: replyToMessageId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessageOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessageOutboxTable,
      MessageOutboxData,
      $$MessageOutboxTableFilterComposer,
      $$MessageOutboxTableOrderingComposer,
      $$MessageOutboxTableAnnotationComposer,
      $$MessageOutboxTableCreateCompanionBuilder,
      $$MessageOutboxTableUpdateCompanionBuilder,
      (
        MessageOutboxData,
        BaseReferences<_$AppDatabase, $MessageOutboxTable, MessageOutboxData>,
      ),
      MessageOutboxData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalConversationsTableTableManager get localConversations =>
      $$LocalConversationsTableTableManager(_db, _db.localConversations);
  $$LocalMessagesTableTableManager get localMessages =>
      $$LocalMessagesTableTableManager(_db, _db.localMessages);
  $$MessageOutboxTableTableManager get messageOutbox =>
      $$MessageOutboxTableTableManager(_db, _db.messageOutbox);
}
