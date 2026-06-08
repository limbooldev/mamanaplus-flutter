import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mime/mime.dart';

import '../../../../core/database/app_database.dart';
import '../../data/chat_repository.dart';
import '../../domain/member_presence.dart';
import '../../media_constants.dart';

int? _jsonInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

String? _peerDisplayNameFromPeerJson(String? peerJson) {
  if (peerJson == null) return null;
  try {
    final m = jsonDecode(peerJson) as Map<String, dynamic>;
    return (m['display_name'] as String?)?.trim();
  } catch (_) {
    return null;
  }
}

String? _peerAvatarMediaKeyFromPeerJson(String? peerJson) {
  if (peerJson == null) return null;
  try {
    final m = jsonDecode(peerJson) as Map<String, dynamic>;
    final k = (m['avatar_media_key'] as String?)?.trim();
    if (k != null && k.isNotEmpty) return k;
  } catch (_) {}
  return null;
}

String? _peerAvatarMediaKeyFromPeerField(dynamic peer) {
  if (peer is! Map) return null;
  final k = (peer['avatar_media_key'] as String?)?.trim();
  if (k != null && k.isNotEmpty) return k;
  return null;
}

String? _peerDisplayNameFromPeerField(dynamic peer) {
  if (peer is! Map) return null;
  return (peer['display_name'] as String?)?.trim();
}

int? _peerUserIdFromPeerField(dynamic peer) {
  if (peer is! Map) return null;
  final id = peer['id'];
  if (id is int) return id;
  if (id is num) return id.toInt();
  return null;
}

int? _peerUserIdFromPeerJson(String? peerJson) {
  if (peerJson == null) return null;
  try {
    final m = jsonDecode(peerJson) as Map<String, dynamic>;
    final id = m['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return null;
  } catch (_) {
    return null;
  }
}

bool? _peerOnlineFromPeer(dynamic peer) {
  if (peer is! Map) return null;
  final v = peer['online'];
  if (v is bool) return v;
  return null;
}

bool? _peerOnlineFromPeerJson(String? peerJson) {
  if (peerJson == null) return null;
  try {
    final m = jsonDecode(peerJson) as Map<String, dynamic>;
    final v = m['online'];
    if (v is bool) return v;
  } catch (_) {}
  return null;
}

DateTime? _parseLastSeenAt(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v);
}

DateTime? _peerLastSeenFromPeer(dynamic peer) {
  if (peer is! Map) return null;
  return _parseLastSeenAt(peer['last_seen_at']);
}

DateTime? _peerLastSeenFromPeerJson(String? peerJson) {
  if (peerJson == null) return null;
  try {
    final m = jsonDecode(peerJson) as Map<String, dynamic>;
    return _parseLastSeenAt(m['last_seen_at']);
  } catch (_) {}
  return null;
}

MemberPresence? _memberPresenceFromUserMap(dynamic user) {
  if (user is! Map) return null;
  final id = _jsonInt(user['id']);
  if (id == null) return null;
  return MemberPresence(
    online: user['online'] == true,
    lastSeenAt: _parseLastSeenAt(user['last_seen_at']),
    displayName: (user['display_name'] as String?)?.trim(),
  );
}

const _unsetReplyTo = Object();

/// A single emoji reaction by [userId] on a message.
class MessageReaction {
  const MessageReaction({required this.userId, required this.emoji});

  final int userId;
  final String emoji;

  factory MessageReaction.fromJson(Map<String, dynamic> j) => MessageReaction(
        userId: _jsonInt(j['user_id']) ?? 0,
        emoji: (j['emoji'] as String? ?? '').trim(),
      );

  @override
  bool operator ==(Object other) =>
      other is MessageReaction && other.userId == userId && other.emoji == emoji;

  @override
  int get hashCode => Object.hash(userId, emoji);
}

class ThreadState extends Equatable {
  const ThreadState({
    this.messages = const [],
    this.pending = const [],
    this.loading = false,
    this.sending = false,
    this.error,
    this.typingUserIds = const {},
    this.replyTo,
    this.readCursorByUserId = const {},
    this.headerTitle,
    this.peerAvatarMediaKey,
    this.myDisplayName,
    this.myAvatarMediaKey,
    this.dmPeerUserId,
    this.peerOnline,
    this.peerLastSeenAt,
    this.memberPresence = const {},
    this.messageSearchQuery,
    this.reactions = const {},
  });

  final List<LocalMessage> messages;

  /// Outbox rows (oldest first) shown as pending bubbles with a clock icon.
  /// Removed once the server returns the persisted message and we cache it.
  final List<MessageOutboxData> pending;
  final bool loading;
  final bool sending;
  final String? error;
  final Set<int> typingUserIds;
  final LocalMessage? replyTo;

  /// Other members' cumulative read cursor (`receipt_update.message_id`), by user id.
  final Map<int, int> readCursorByUserId;

  /// App bar title for private (peer name) or group (title); null → fallback `Thread #id`.
  final String? headerTitle;

  /// Private DM: peer profile photo object key.
  final String? peerAvatarMediaKey;

  /// Authenticated user's display name (for reply quotes to own messages).
  final String? myDisplayName;

  /// Authenticated user's profile photo object key.
  final String? myAvatarMediaKey;

  /// Private DM: other participant's user id (for block-from-thread, etc.).
  final int? dmPeerUserId;

  /// Private DM: peer presence from API / WebSocket `presence` events.
  final bool? peerOnline;
  final DateTime? peerLastSeenAt;

  /// Group: member id → presence (from `GET /v1/groups/{id}` + `presence` events).
  final Map<int, MemberPresence> memberPresence;

  /// Group in-thread search (server `q`); null when inactive.
  final String? messageSearchQuery;

  /// Emoji reactions keyed by message id. Populated from the API response and
  /// updated in real time via `reaction_added` / `reaction_removed` WS events.
  final Map<int, List<MessageReaction>> reactions;

  ThreadState copyWith({
    List<LocalMessage>? messages,
    List<MessageOutboxData>? pending,
    bool? loading,
    bool? sending,
    String? error,
    Set<int>? typingUserIds,
    Object? replyTo = _unsetReplyTo,
    Map<int, int>? readCursorByUserId,
    String? headerTitle,
    String? peerAvatarMediaKey,
    String? myDisplayName,
    String? myAvatarMediaKey,
    int? dmPeerUserId,
    bool? peerOnline,
    DateTime? peerLastSeenAt,
    Map<int, MemberPresence>? memberPresence,
    String? messageSearchQuery,
    bool clearMessageSearch = false,
    Map<int, List<MessageReaction>>? reactions,
  }) =>
      ThreadState(
        messages: messages ?? this.messages,
        pending: pending ?? this.pending,
        loading: loading ?? this.loading,
        sending: sending ?? this.sending,
        error: error,
        typingUserIds: typingUserIds ?? this.typingUserIds,
        replyTo: identical(replyTo, _unsetReplyTo)
            ? this.replyTo
            : replyTo as LocalMessage?,
        readCursorByUserId: readCursorByUserId ?? this.readCursorByUserId,
        headerTitle: headerTitle ?? this.headerTitle,
        peerAvatarMediaKey: peerAvatarMediaKey ?? this.peerAvatarMediaKey,
        myDisplayName: myDisplayName ?? this.myDisplayName,
        myAvatarMediaKey: myAvatarMediaKey ?? this.myAvatarMediaKey,
        dmPeerUserId: dmPeerUserId ?? this.dmPeerUserId,
        peerOnline: peerOnline ?? this.peerOnline,
        peerLastSeenAt: peerLastSeenAt ?? this.peerLastSeenAt,
        memberPresence: memberPresence ?? this.memberPresence,
        messageSearchQuery:
            clearMessageSearch ? null : (messageSearchQuery ?? this.messageSearchQuery),
        reactions: reactions ?? this.reactions,
      );

  /// Private DM: max peer read cursor from `receipt_update` — double-check when read up to [messageId].
  bool readReceiptForOwnMessage(int messageId, String? conversationType) {
    if (conversationType != 'private') return false;
    if (readCursorByUserId.isEmpty) return false;
    final peerMax = readCursorByUserId.values.reduce(
      (a, b) => a >= b ? a : b,
    );
    return peerMax >= messageId;
  }

  @override
  List<Object?> get props => [
        messages,
        pending,
        loading,
        sending,
        error,
        typingUserIds,
        replyTo,
        readCursorByUserId,
        headerTitle,
        peerAvatarMediaKey,
        myDisplayName,
        myAvatarMediaKey,
        dmPeerUserId,
        peerOnline,
        peerLastSeenAt,
        memberPresence,
        messageSearchQuery,
        reactions,
      ];
}

class ThreadCubit extends Cubit<ThreadState> {
  ThreadCubit(
    this._repo,
    this.conversationId,
    this.myUserId, {
    this.conversationType,
  }) : super(const ThreadState());

  final ChatRepository _repo;
  final int conversationId;
  final int myUserId;
  final String? conversationType;

  /// Exposed for widgets that need the same REST client as the cubit (e.g. voice download).
  ChatRepository get chatRepository => _repo;
  StreamSubscription<Map<String, dynamic>>? _sub;
  StreamSubscription<int>? _outboxSub;
  StreamSubscription<void>? _reconnectSub;
  bool _typingActive = false;

  /// Route extra and/or local inbox cache (`private` / `group`).
  String? _resolvedConversationType;

  String? get effectiveConversationType =>
      _resolvedConversationType ?? conversationType;

  Future<void> init() async {
    _resolvedConversationType =
        conversationType ?? await _repo.conversationTypeLocal(conversationId);
    Map<String, dynamic>? prefetchedConv;
    if (_resolvedConversationType == null) {
      try {
        prefetchedConv = await _repo.fetchConversation(conversationId);
        _resolvedConversationType = prefetchedConv['type'] as String?;
      } catch (_) {}
    }
    emit(state.copyWith(loading: true));
    await _reloadLocal();
    unawaited(_hydrateHeader(prefetched: prefetchedConv));
    unawaited(_resolveDmPeerUserId(prefetched: prefetchedConv));
    unawaited(_loadMyDisplayName());
    if (_resolvedConversationType == 'group') {
      unawaited(_loadGroupPresence());
    }
    await _reloadMessagesFromRemote();

    // Watch outbox so the optimistic bubble appears immediately when [send]
    // inserts the row, and disappears as soon as the server response is cached.
    _outboxSub =
        _repo.outboxChangedFor.where((id) => id == conversationId).listen((_) {
      unawaited(_reloadLocal());
    });

    // Every time the WebSocket re-establishes, re-fetch messages from REST. The
    // refetch is critical:
    // while the socket was down (app backgrounded, OS killed TCP flow, backend
    // 60 s idle close, etc.) any `new_message` events delivered by FCM-only
    // recipients never reached this cubit, so the in-memory thread is stale.
    // Without this, the user has to leave and re-enter the thread to see
    // messages that arrived during the disconnect window.
    _reconnectSub = _repo.socket.connected.listen((_) {
      // Outbox flush is centralized in [ChatRepository] on socket reconnect.
      if (state.messageSearchQuery != null) {
        unawaited(_reloadMessagesFromRemote());
      } else {
        unawaited(_syncNewerAfterReconnect());
      }
    });

    _sub = _repo.socket.events.listen((event) async {
      final type = event['type'] as String?;
      final payload = event['payload'];
      if (type == 'new_message' && payload is Map<String, dynamic>) {
        final cid = _jsonInt(payload['conversation_id']);
        if (cid != conversationId) return;
        final msg = payload['message'] as Map<String, dynamic>?;
        if (msg == null) return;
        if (state.messageSearchQuery != null) {
          await _reloadMessagesFromRemote();
        } else {
          // Write first, then read — avoids race between async cache and reload.
          await _repo.cacheMessages(conversationId, [msg]);
          await _reloadLocal();
        }
        final msgId = _jsonInt(msg['id']);
        final senderId = _jsonInt(msg['sender_id']);
        // Send `receipt:delivered` so the sender's bubble flips Sent → Delivered
        // in real time. Idempotent on the backend (see `MarkMessagesDelivered`).
        if (msgId != null && senderId != null && senderId != myUserId) {
          _repo.socket.sendDeliveredAck(conversationId, [msgId]);
        }
        // Mark new message as read immediately (user is in the thread).
        if (msgId != null) {
          unawaited(_repo.markRead(conversationId, msgId));
        }
      } else if (type == 'message_edited' && payload is Map<String, dynamic>) {
        final cid = _jsonInt(payload['conversation_id']);
        if (cid != conversationId) return;
        final msg = payload['message'] as Map<String, dynamic>?;
        if (msg == null) return;
        await _repo.cacheMessages(conversationId, [msg]);
        await _reloadLocal();
      } else if (type == 'typing' && payload is Map<String, dynamic>) {
        final cid = _jsonInt(payload['conversation_id']);
        final uid = _jsonInt(payload['user_id']);
        final typing = payload['typing'] as bool? ?? false;
        if (cid != conversationId || uid == null || uid == myUserId) return;
        final next = Set<int>.from(state.typingUserIds);
        if (typing) {
          next.add(uid);
        } else {
          next.remove(uid);
        }
        emit(state.copyWith(typingUserIds: next));
      } else if (type == 'presence' && payload is Map<String, dynamic>) {
        final uid = _jsonInt(payload['user_id']);
        if (uid == null || uid == myUserId) return;
        final online = payload['online'] == true;
        final lastSeen = _parseLastSeenAt(payload['last_seen_at']);
        if (effectiveConversationType == 'private' &&
            uid == state.dmPeerUserId) {
          emit(state.copyWith(
            peerOnline: online,
            peerLastSeenAt: lastSeen ?? state.peerLastSeenAt,
          ));
        } else if (effectiveConversationType == 'group') {
          final prev = state.memberPresence[uid];
          final next = Map<int, MemberPresence>.from(state.memberPresence);
          next[uid] = MemberPresence(
            online: online,
            lastSeenAt: lastSeen ?? prev?.lastSeenAt,
            displayName: prev?.displayName,
          );
          emit(state.copyWith(memberPresence: next));
        }
      } else if (type == 'reaction_added' && payload is Map<String, dynamic>) {
        final cid = _jsonInt(payload['conversation_id']);
        if (cid != conversationId) return;
        final mid = _jsonInt(payload['message_id']);
        final uid = _jsonInt(payload['user_id']);
        final emoji = (payload['emoji'] as String?)?.trim() ?? '';
        if (mid == null || uid == null || emoji.isEmpty) return;
        final prev = List<MessageReaction>.from(state.reactions[mid] ?? []);
        final reaction = MessageReaction(userId: uid, emoji: emoji);
        if (!prev.contains(reaction)) {
          prev.add(reaction);
          emit(state.copyWith(reactions: {...state.reactions, mid: prev}));
        }
      } else if (type == 'reaction_removed' && payload is Map<String, dynamic>) {
        final cid = _jsonInt(payload['conversation_id']);
        if (cid != conversationId) return;
        final mid = _jsonInt(payload['message_id']);
        final uid = _jsonInt(payload['user_id']);
        final emoji = (payload['emoji'] as String?)?.trim() ?? '';
        if (mid == null || uid == null || emoji.isEmpty) return;
        final prev = List<MessageReaction>.from(state.reactions[mid] ?? []);
        prev.removeWhere((r) => r.userId == uid && r.emoji == emoji);
        emit(state.copyWith(reactions: {...state.reactions, mid: prev}));
      } else if (type == 'receipt_update' && payload is Map<String, dynamic>) {
        final cid = _jsonInt(payload['conversation_id']);
        if (cid != conversationId) return;
        final uid = _jsonInt(payload['user_id']);
        final mid = _jsonInt(payload['message_id']);
        if (uid == null || mid == null || uid == myUserId) return;
        final deliveredAt =
            DateTime.tryParse(payload['delivered_at'] as String? ?? '');
        final readAt = DateTime.tryParse(payload['read_at'] as String? ?? '');

        // Per-message receipts: write delivered_at / read_at to the matching
        // LocalMessage so the bubble flips Sent → Delivered → Seen even without
        // a follow-up REST fetch.
        if (deliveredAt != null) {
          await _repo.applyDeliveredReceipt(
            conversationId: conversationId,
            messageId: mid,
            deliveredAt: deliveredAt,
          );
        }
        if (readAt != null) {
          await _repo.applyReadReceipt(
            conversationId: conversationId,
            messageId: mid,
            readAt: readAt,
          );
        }

        final prev = state.readCursorByUserId[uid] ?? 0;
        final next = readAt != null && mid > prev ? mid : prev;
        final newCursor = {...state.readCursorByUserId, uid: next};
        // Load fresh messages first, then emit ONCE with both cursor + messages.
        // Previously two separate emits (cursor, then reload) caused two concurrent
        // setMessages calls that raced and clobbered each other.
        final local = await _repo.loadMessagesLocal(conversationId);
        final pending = await _repo.loadOutboxLocal(conversationId);
        emit(state.copyWith(
          readCursorByUserId: newCursor,
          messages: local,
          pending: pending,
        ));
      }
    });
  }

  Future<void> _resolveDmPeerUserId({Map<String, dynamic>? prefetched}) async {
    if (effectiveConversationType != 'private') return;
    if (state.dmPeerUserId != null) return;
    final fromPrefetch = prefetched != null
        ? _peerUserIdFromPeerField(prefetched['peer'])
        : null;
    if (fromPrefetch != null) {
      emit(state.copyWith(dmPeerUserId: fromPrefetch));
      return;
    }
    final local = await _repo.loadConversationLocal(conversationId);
    final fromJson = _peerUserIdFromPeerJson(local?.peerJson);
    if (fromJson != null) {
      emit(state.copyWith(dmPeerUserId: fromJson));
      return;
    }
    try {
      final raw = prefetched ?? await _repo.fetchConversation(conversationId);
      final id = _peerUserIdFromPeerField(raw['peer']);
      if (id != null) {
        await _repo.upsertLocalConversationFromDto(raw);
        emit(state.copyWith(dmPeerUserId: id));
      }
    } catch (_) {}
  }

  Future<void> _loadMyDisplayName() async {
    try {
      final me = await _repo.fetchMe();
      final name = (me['display_name'] as String?)?.trim();
      final avatar = (me['avatar_media_key'] as String?)?.trim();
      emit(state.copyWith(
        myDisplayName: (name != null && name.isNotEmpty) ? name : null,
        myAvatarMediaKey: (avatar != null && avatar.isNotEmpty) ? avatar : null,
      ));
    } catch (_) {}
  }

  /// Resolves app bar title from local cache or `GET /v1/conversations/{id}`.
  Future<void> _hydrateHeader({Map<String, dynamic>? prefetched}) async {
    final local = await _repo.loadConversationLocal(conversationId);
    final type = _resolvedConversationType ?? local?.type;

    if (type == 'group') {
      final t = local?.title?.trim();
      if (t != null && t.isNotEmpty) {
        emit(state.copyWith(headerTitle: t));
      }
      unawaited(_loadGroupPresence());
      return;
    }

    if (type != 'private') return;

    var name = _peerDisplayNameFromPeerJson(local?.peerJson);
    var avatar = _peerAvatarMediaKeyFromPeerJson(local?.peerJson);
    var online = _peerOnlineFromPeerJson(local?.peerJson);
    var lastSeen = _peerLastSeenFromPeerJson(local?.peerJson);
    if ((name == null || name.isEmpty) && prefetched != null) {
      name = _peerDisplayNameFromPeerField(prefetched['peer']);
      avatar ??= _peerAvatarMediaKeyFromPeerField(prefetched['peer']);
      online ??= _peerOnlineFromPeer(prefetched['peer']);
      lastSeen ??= _peerLastSeenFromPeer(prefetched['peer']);
      if (name != null && name.isNotEmpty) {
        await _repo.upsertLocalConversationFromDto(prefetched);
      }
    }
    if (name == null || name.isEmpty) {
      try {
        final raw = prefetched ?? await _repo.fetchConversation(conversationId);
        await _repo.upsertLocalConversationFromDto(raw);
        name = _peerDisplayNameFromPeerField(raw['peer']);
        avatar ??= _peerAvatarMediaKeyFromPeerField(raw['peer']);
        online ??= _peerOnlineFromPeer(raw['peer']);
        lastSeen ??= _peerLastSeenFromPeer(raw['peer']);
      } catch (_) {}
    }
    emit(state.copyWith(
      headerTitle: (name != null && name.isNotEmpty) ? name : state.headerTitle,
      peerAvatarMediaKey: avatar ?? state.peerAvatarMediaKey,
      peerOnline: online,
      peerLastSeenAt: lastSeen,
    ));
  }

  Future<void> _loadGroupPresence() async {
    if (effectiveConversationType != 'group') return;
    try {
      final d = await _repo.getGroup(conversationId);
      final members = d['members'] as List<dynamic>? ?? [];
      final map = <int, MemberPresence>{};
      for (final raw in members) {
        if (raw is! Map) continue;
        final user = raw['user'];
        final p = _memberPresenceFromUserMap(user);
        if (p == null) continue;
        final id = _jsonInt((user as Map)['id']);
        if (id == null) continue;
        map[id] = p;
      }
      if (map.isNotEmpty) {
        emit(state.copyWith(memberPresence: map));
      }
    } catch (_) {}
  }

  Future<void> _reloadLocal() async {
    final local = await _repo.loadMessagesLocal(conversationId);
    final pending = await _repo.loadOutboxLocal(conversationId);
    emit(state.copyWith(messages: local, pending: pending));
  }

  Future<void> _syncNewerAfterReconnect() async {
    try {
      await _repo.syncNewerMessages(conversationId);
      final local = await _repo.loadMessagesLocal(conversationId);
      final pending = await _repo.loadOutboxLocal(conversationId);
      emit(state.copyWith(messages: local, pending: pending, loading: false));
      if (local.isNotEmpty) {
        await _repo.markRead(conversationId, local.first.id);
      }
    } catch (e) {
      final local = await _repo.loadMessagesLocal(conversationId);
      final pending = await _repo.loadOutboxLocal(conversationId);
      if (local.isNotEmpty || pending.isNotEmpty) {
        emit(state.copyWith(
          messages: local,
          pending: pending,
          loading: false,
        ));
      } else {
        emit(state.copyWith(loading: false, error: e.toString()));
      }
    }
  }

  Future<void> _reloadMessagesFromRemote() async {
    try {
      final data = await _repo.fetchMessages(
        conversationId,
        q: state.messageSearchQuery,
      );
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      final newReactions = _parseReactionsFromItems(items);
      await _repo.cacheMessages(conversationId, items);
      final local = await _repo.loadMessagesLocal(conversationId);
      final pending = await _repo.loadOutboxLocal(conversationId);
      emit(state.copyWith(
        messages: local,
        pending: pending,
        loading: false,
        reactions: {...state.reactions, ...newReactions},
      ));
      if (local.isNotEmpty) {
        await _repo.markRead(conversationId, local.first.id);
      }
    } catch (e) {
      final local = await _repo.loadMessagesLocal(conversationId);
      final pending = await _repo.loadOutboxLocal(conversationId);
      if (local.isNotEmpty || pending.isNotEmpty) {
        emit(state.copyWith(
          messages: local,
          pending: pending,
          loading: false,
        ));
      } else {
        emit(state.copyWith(loading: false, error: e.toString()));
      }
    }
  }

  /// Parses `reactions` arrays from a list of raw message JSON maps into a
  /// `messageId → reactions` map.
  static Map<int, List<MessageReaction>> _parseReactionsFromItems(
    List<Map<String, dynamic>> items,
  ) {
    final result = <int, List<MessageReaction>>{};
    for (final item in items) {
      final id = _jsonInt(item['id']);
      if (id == null) continue;
      final rawList = item['reactions'] as List<dynamic>?;
      if (rawList == null) continue;
      result[id] = rawList
          .whereType<Map<String, dynamic>>()
          .map(MessageReaction.fromJson)
          .toList();
    }
    return result;
  }

  /// Server-side substring search (text/plain only); pass null or short string to clear.
  Future<void> setMessageSearchQuery(String? raw) async {
    final q = raw?.trim();
    final norm = (q == null || q.length < 2) ? null : q;
    emit(state.copyWith(loading: true, error: null, clearMessageSearch: norm == null, messageSearchQuery: norm));
    await _reloadMessagesFromRemote();
  }

  void setReplyTo(LocalMessage? m) => emit(state.copyWith(replyTo: m));

  /// Optimistically adds or removes a reaction, then syncs with the server.
  /// If [myUserId] already reacted with [emoji], the reaction is removed (toggle).
  Future<void> toggleReaction(int messageId, String emoji) async {
    final prev = List<MessageReaction>.from(state.reactions[messageId] ?? []);
    final existing = prev.where(
      (r) => r.userId == myUserId && r.emoji == emoji,
    );
    final alreadyReacted = existing.isNotEmpty;

    // Optimistic update.
    if (alreadyReacted) {
      prev.removeWhere((r) => r.userId == myUserId && r.emoji == emoji);
    } else {
      prev.add(MessageReaction(userId: myUserId, emoji: emoji));
    }
    emit(state.copyWith(reactions: {...state.reactions, messageId: prev}));

    try {
      if (alreadyReacted) {
        await _repo.removeReaction(conversationId, messageId, emoji: emoji);
      } else {
        await _repo.addReaction(conversationId, messageId, emoji: emoji);
      }
    } catch (_) {
      // Roll back on error.
      final rolled = List<MessageReaction>.from(state.reactions[messageId] ?? []);
      if (alreadyReacted) {
        rolled.add(MessageReaction(userId: myUserId, emoji: emoji));
      } else {
        rolled.removeWhere((r) => r.userId == myUserId && r.emoji == emoji);
      }
      emit(state.copyWith(reactions: {...state.reactions, messageId: rolled}));
    }
  }

  String _newLocalId() =>
      '${conversationId}_${DateTime.now().microsecondsSinceEpoch}';

  Future<void> send(String text) async {
    final body = text.trim();
    if (body.isEmpty) return;
    final replyId = state.replyTo?.id;
    // Clear the reply chip immediately — bubble already appears via outbox.
    emit(state.copyWith(replyTo: null, error: null));
    unawaited(_repo.sendTextOptimistic(
      localId: _newLocalId(),
      conversationId: conversationId,
      body: body,
      replyToMessageId: replyId,
    ));
  }

  /// [kind] is `image`, `video`, or `voice` (matches backend JSON).
  Future<void> sendMediaFile({
    required String path,
    required String kind,
    int? durationMs,
    String? caption,
  }) async {
    final mime = lookupMimeType(path) ?? 'application/octet-stream';
    final replyId = state.replyTo?.id;
    emit(state.copyWith(replyTo: null, error: null));
    unawaited(_repo.sendMediaOptimistic(
      localId: _newLocalId(),
      conversationId: conversationId,
      path: path,
      mime: mime,
      kind: kind,
      durationMs: durationMs,
      replyToMessageId: replyId,
      caption: caption,
    ));
  }

  Future<void> sendSticker({required String stickerId, required String emoji}) async {
    final body = jsonEncode({'sticker_id': stickerId, 'emoji': emoji});
    final replyId = state.replyTo?.id;
    emit(state.copyWith(replyTo: null, error: null));
    unawaited(_repo.sendTextOptimistic(
      localId: _newLocalId(),
      conversationId: conversationId,
      body: body,
      contentType: kMamanaStickerContentType,
      replyToMessageId: replyId,
    ));
  }

  /// [kind] is `gif` or `sticker` (Giphy sticker pack).
  Future<void> sendGif({
    required String gifId,
    required String url,
    String? previewUrl,
    int? width,
    int? height,
    required String kind,
  }) async {
    if (url.trim().isEmpty || gifId.trim().isEmpty) return;
    final body = jsonEncode({
      'gif_id': gifId,
      'url': url,
      if (previewUrl != null && previewUrl.isNotEmpty) 'preview_url': previewUrl,
      if (width != null && width > 0) 'width': width,
      if (height != null && height > 0) 'height': height,
      'kind': kind,
    });
    final replyId = state.replyTo?.id;
    emit(state.copyWith(replyTo: null, error: null));
    unawaited(_repo.sendTextOptimistic(
      localId: _newLocalId(),
      conversationId: conversationId,
      body: body,
      contentType: kMamanaGifContentType,
      replyToMessageId: replyId,
    ));
  }

  Future<void> editMessage(int messageId, String newBody) async {
    if (newBody.trim().isEmpty) return;
    try {
      await _repo.editMessage(conversationId, messageId, body: newBody.trim());
      await _reloadLocal();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> deleteMessage(int messageId, {bool forEveryone = false}) async {
    try {
      await _repo.deleteMessage(
        conversationId,
        messageId,
        scope: forEveryone ? 'for_everyone' : 'for_me',
      );
      await _reloadLocal();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> cancelPendingMessage(String localId) async {
    try {
      await _repo.cancelPendingSend(
        localId: localId,
        conversationId: conversationId,
      );
      await _reloadLocal();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> flushOutbox() async {
    await _repo.flushPendingSends(conversationId);
    await _reloadLocal();
  }

  void onTyping(bool v) {
    _typingActive = v;
    unawaited(_repo.typing(conversationId, v));
  }

  @override
  Future<void> close() {
    if (_typingActive) {
      unawaited(_repo.typing(conversationId, false));
    }
    _sub?.cancel();
    _outboxSub?.cancel();
    _reconnectSub?.cancel();
    return super.close();
  }
}
