import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mamana_plus/l10n/app_localizations.dart';
import 'package:giphy_get/giphy_get.dart';

import '../../../../core/api_config.dart';
import '../../../../core/giphy_config.dart';
import '../../../../core/notification_dismiss.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/jwt_util.dart';
import '../../../../router/app_routes.dart';
import '../../../../shared/ui/ui.dart';
import '../../conversation_preview.dart';
import '../../data/chat_mute_prefs.dart';
import '../../data/chat_repository.dart';
import '../cubit/thread_cubit.dart';
import '../mappers/local_message_to_chat_message.dart';
import '../widgets/media_caption_preview.dart';
import '../widgets/message_status_icon.dart';
import '../widgets/mamana_gif_bubble.dart';
import '../widgets/reply_quote.dart';
import '../widgets/scroll_target_highlight.dart';
import '../widgets/thread_app_bar_status.dart';
import '../widgets/thread_composer_with_panel.dart';
import '../widgets/thread_media_widgets.dart';
import '../../../social/presentation/pages/user_profile_page.dart';
import '../../../social/presentation/widgets/social_media_widgets.dart';

class ThreadPage extends StatelessWidget {
  const ThreadPage({
    super.key,
    required this.conversationId,
    required this.accessToken,
    this.conversationType,
  });

  final int conversationId;
  final String accessToken;
  final String? conversationType;

  @override
  Widget build(BuildContext context) {
    final myId = parseUserIdFromAccessToken(accessToken) ?? 0;
    final apiBase = context.read<ApiConfig>().baseUrl;
    return BlocProvider(
      create: (context) => ThreadCubit(
        context.read<ChatRepository>(),
        conversationId,
        myId,
        conversationType: conversationType,
      )..init(),
      child: _ThreadScaffold(
        conversationId: conversationId,
        myUserId: myId,
        accessToken: accessToken,
        apiBaseUrl: apiBase,
        conversationType: conversationType,
      ),
    );
  }
}

class _ThreadScaffold extends StatefulWidget {
  const _ThreadScaffold({
    required this.conversationId,
    required this.myUserId,
    required this.accessToken,
    required this.apiBaseUrl,
    this.conversationType,
  });

  final int conversationId;
  final int myUserId;
  final String accessToken;
  final String apiBaseUrl;
  final String? conversationType;

  @override
  State<_ThreadScaffold> createState() => _ThreadScaffoldState();
}

class _ThreadScaffoldState extends State<_ThreadScaffold> {
  final _composerController = TextEditingController();
  final _composerFocusNode = FocusNode();
  late final InMemoryChatController _chatController;
  Timer? _typingIdleTimer;
  String _lastChatSyncSig = '';
  var _muteLoaded = false;
  var _muted = false;
  var _showEmojiPanel = false;
  var _emojiPanelTab = 0;
  double _keyboardHeight = 280;
  final _giphyApiKey = GiphyConfig.fromEnvironment().apiKey;
  String? _scrollHighlightMessageId;
  Timer? _scrollHighlightTimer;
  late final ScrollController _listScrollController;

  /// Keeps the list pinned to the newest messages until the user scrolls up.
  var _stickToBottom = true;

  static const _stickToBottomReleaseGap = 72.0;
  static const _scrollToBottomLayoutPasses = 8;

  @override
  void initState() {
    super.initState();
    _chatController = InMemoryChatController();
    _listScrollController = ScrollController();
    _listScrollController.addListener(_onListScroll);
    _composerController.addListener(_handleComposerTextChanged);
    _composerFocusNode.addListener(_onComposerFocusChanged);
    dismissConversationNotification(widget.conversationId);
  }

  void _onListScroll() {
    if (!_stickToBottom || !_listScrollController.hasClients) return;
    final pos = _listScrollController.position;
    if (pos.userScrollDirection == ScrollDirection.idle) return;
    final gap = pos.maxScrollExtent - pos.pixels;
    if (gap > _stickToBottomReleaseGap) {
      _stickToBottom = false;
    }
  }

  void _jumpToListBottom() {
    if (!_listScrollController.hasClients) return;
    final max = _listScrollController.position.maxScrollExtent;
    if (max <= 0) return;
    if ((_listScrollController.offset - max).abs() > 0.5) {
      _listScrollController.jumpTo(max);
    }
  }

  /// Re-scroll after composer height / media layout updates (library initial
  /// scroll often runs before [ComposerHeightNotifier] has a real measurement).
  void _scheduleScrollToBottom() {
    if (!_stickToBottom || !mounted) return;
    var pass = 0;
    void schedulePass() {
      if (!_stickToBottom || !mounted || pass >= _scrollToBottomLayoutPasses) {
        return;
      }
      pass++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_stickToBottom || !mounted) return;
        _jumpToListBottom();
        schedulePass();
      });
    }
    schedulePass();
  }

  void _onComposerFocusChanged() {
    if (_composerFocusNode.hasFocus && _showEmojiPanel) {
      setState(() => _showEmojiPanel = false);
    }
  }

  void _captureKeyboardHeight(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset > 200 && (inset - _keyboardHeight).abs() > 1) {
      _keyboardHeight = inset;
    }
  }

  void _toggleEmojiPanel({int tab = 0}) {
    if (_showEmojiPanel && _emojiPanelTab == tab) {
      setState(() => _showEmojiPanel = false);
      _composerFocusNode.requestFocus();
      return;
    }
    _captureKeyboardHeight(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _showEmojiPanel = true;
      _emojiPanelTab = tab;
    });
  }

  void _insertEmoji(String emoji) {
    final text = _composerController.text;
    final sel = _composerController.selection;
    final start = sel.start >= 0 ? sel.start : text.length;
    final end = sel.end >= 0 ? sel.end : text.length;
    final next = text.replaceRange(start, end, emoji);
    _composerController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  void _sendGiphySelection(GiphyGif gif, {required String kind}) {
    final images = gif.images;
    final url = images?.original?.url ??
        images?.fixedWidth.url ??
        gif.url ??
        '';
    final gifId = gif.id ?? '';
    if (url.isEmpty || gifId.isEmpty) return;
    final preview = images?.fixedWidth.url ??
        images?.fixedWidthStill?.url ??
        url;
    int? w;
    int? h;
    final orig = images?.original;
    if (orig != null) {
      w = int.tryParse(orig.width);
      h = int.tryParse(orig.height);
    }
    context.read<ThreadCubit>().sendGif(
          gifId: gifId,
          url: url,
          previewUrl: preview,
          width: w,
          height: h,
          kind: kind,
        );
    setState(() => _showEmojiPanel = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_muteLoaded) {
      _muteLoaded = true;
      _muted = context.read<ChatMutePrefs>().isMuted(widget.conversationId);
    }
  }

  @override
  void dispose() {
    _scrollHighlightTimer?.cancel();
    _typingIdleTimer?.cancel();
    _listScrollController.removeListener(_onListScroll);
    _listScrollController.dispose();
    _composerController.removeListener(_handleComposerTextChanged);
    _composerFocusNode.removeListener(_onComposerFocusChanged);
    _composerController.dispose();
    _composerFocusNode.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _handleComposerTextChanged() {
    if (!mounted) return;
    _onTypingFromText(context, _composerController.text);
  }

  void _onTypingFromText(BuildContext context, String text) {
    final cubit = context.read<ThreadCubit>();
    _typingIdleTimer?.cancel();
    if (text.isEmpty) {
      cubit.onTyping(false);
      return;
    }
    cubit.onTyping(true);
    _typingIdleTimer = Timer(const Duration(seconds: 2), () => cubit.onTyping(false));
  }

  String _chatSignature(ThreadState s) {
    final parts = s.messages
        .map(
          (m) =>
              '${m.id}|${m.body}|${m.contentType}|${m.replyToMessageId}|${m.receiptDeliveredAt}|${m.receiptReadAt}',
        )
        .join('~');
    final pendingParts = s.pending
        .map(
          (r) =>
              'p:${r.localId}|${r.body}|${r.contentType}|${r.replyToMessageId}|${r.mediaPath}|${r.lastErrorAt}',
        )
        .join('~');
    final reads =
        s.readCursorByUserId.entries.map((e) => '${e.key}:${e.value}').join(',');
    return '$parts^$pendingParts#$reads';
  }

  ReplyPreviewMapContext _replyPreviewMapContext(ThreadCubit cubit) {
    final l10n = AppLocalizations.of(context)!;
    return ReplyPreviewMapContext(
      myUserId: widget.myUserId,
      apiBaseUrl: widget.apiBaseUrl,
      headerTitle: cubit.state.headerTitle,
      conversationType: cubit.effectiveConversationType,
      myDisplayName: cubit.state.myDisplayName,
      userNameYou: l10n.userNameYou,
      userFallback: l10n.userFallback,
    );
  }

  Future<void> _syncChatMessages(ThreadState state) async {
    if (!mounted) return;
    final cubit = context.read<ThreadCubit>();
    final convType = cubit.effectiveConversationType;
    final previewCtx = _replyPreviewMapContext(cubit);
    final delivered = mapLocalMessagesToChatMessages(
      state.messages,
      myUserId: widget.myUserId,
      readReceiptForOwn: (id) => state.readReceiptForOwnMessage(id, convType),
      apiBaseUrl: widget.apiBaseUrl,
      replyPreview: previewCtx,
    );
    final pendingMapped = mapPendingOutboxToChatMessages(
      state.pending,
      myUserId: widget.myUserId,
      allMessages: state.messages,
      replyPreview: previewCtx,
    );
    // Pending bubbles always sit at the bottom (newest), keyed by 'pending_*'
    // so they never collide with server message ids during the diff.
    final mapped = [...delivered, ...pendingMapped];
    if (!mounted) return;

    // For existing messages whose content changed (e.g. status: delivered→seen),
    // use updateMessage instead of relying on setMessages's remove+insert diff.
    // setMessages uses ValueKey(message.id) for ChatMessageInternal, so remove+insert
    // reuses the old widget state (which still has the old status) — the status icon
    // never updates. updateMessage emits ChatOperationType.update which
    // ChatMessageInternal listens to and directly calls setState.
    final existingById = {for (final m in _chatController.messages) m.id: m};
    for (final newMsg in mapped) {
      if (!mounted) return;
      final old = existingById[newMsg.id];
      if (old != null && old != newMsg) {
        await _chatController.updateMessage(old, newMsg);
      }
    }
    if (!mounted) return;

    // setMessages handles structural changes only (inserts/deletes).
    // Because updates are pre-applied above, the diff sees no "change" ops for
    // existing messages — only new/removed messages produce insertItem/removeItem.
    await _chatController.setMessages(mapped, animated: false);
    _scheduleScrollToBottom();
  }

  LocalMessage? _localById(List<LocalMessage> messages, int id) {
    for (final m in messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  ReplyPreviewData _replyPreviewForMessage(LocalMessage message) {
    final cubit = context.read<ThreadCubit>();
    final ctx = _replyPreviewMapContext(cubit);
    return replyPreviewDataForMessage(
      message: message,
      myUserId: ctx.myUserId,
      apiBaseUrl: ctx.apiBaseUrl,
      headerTitle: ctx.headerTitle,
      conversationType: ctx.conversationType,
      myDisplayName: ctx.myDisplayName,
      userNameYou: ctx.userNameYou,
      userFallback: ctx.userFallback,
    );
  }

  ReplyPreviewData? _replyPreviewForChatMessage(Message message) {
    final fromMeta = replyPreviewDataFromMetadata(message.metadata);
    if (fromMeta != null) {
      return fromMeta;
    }
    final cubit = context.read<ThreadCubit>();
    final ctx = _replyPreviewMapContext(cubit);
    return replyPreviewDataForId(
      message.replyToMessageId,
      cubit.state.messages,
      myUserId: ctx.myUserId,
      apiBaseUrl: ctx.apiBaseUrl,
      headerTitle: ctx.headerTitle,
      conversationType: ctx.conversationType,
      myDisplayName: ctx.myDisplayName,
      userNameYou: ctx.userNameYou,
      userFallback: ctx.userFallback,
    );
  }

  bool _hasReplyQuote(Message message) {
    final id = message.replyToMessageId;
    if (id != null && id.isNotEmpty) {
      return true;
    }
    return replyPreviewDataFromMetadata(message.metadata) != null;
  }

  void _closeEmojiPanel() {
    if (!_showEmojiPanel) return;
    setState(() => _showEmojiPanel = false);
  }

  void _handleThreadBack() {
    if (_showEmojiPanel) {
      _closeEmojiPanel();
      return;
    }
    Navigator.of(context).pop();
  }

  VoidCallback? _replyQuoteTapHandler(BuildContext chatContext, Message message) {
    final replyId = message.replyToMessageId;
    if (replyId == null || replyId.isEmpty) return null;
    return () {
      HapticFeedback.selectionClick();
      unawaited(_scrollToRepliedMessage(chatContext, replyId));
    };
  }

  void _pulseScrollTarget(String messageId) {
    _scrollHighlightTimer?.cancel();
    setState(() => _scrollHighlightMessageId = messageId);
    _scrollHighlightTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _scrollHighlightMessageId = null);
      }
    });
  }

  Widget _wrapScrollTargetHighlight(String messageId, Widget child) {
    return ScrollTargetHighlight(
      active: _scrollHighlightMessageId == messageId,
      child: child,
    );
  }

  Future<void> _scrollToRepliedMessage(
    BuildContext chatContext,
    String messageId,
  ) async {
    _closeEmojiPanel();
    if (!mounted) return;

    final found = _chatController.messages.any((m) => m.id == messageId);
    if (!found) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original message is not in this thread')),
      );
      return;
    }

    double bottomReserve = 96;
    try {
      final composerH = chatContext.read<ComposerHeightNotifier>().height;
      final safeBottom = MediaQuery.paddingOf(chatContext).bottom;
      bottomReserve = (composerH + safeBottom + 24).clamp(72.0, 220.0);
    } catch (_) {
      // chatContext must be from inside [Chat]; fallback if provider is missing.
    }

    const scrollDuration = Duration(milliseconds: 500);
    const scrollCurve = Curves.easeInOutCubic;

    try {
      await _chatController.scrollToMessage(
        messageId,
        duration: scrollDuration,
        curve: scrollCurve,
        alignment: 0.25,
        offset: bottomReserve,
      );
    } catch (_) {
      await _chatController.scrollToMessage(
        messageId,
        duration: scrollDuration,
        curve: scrollCurve,
        alignment: 0.25,
      );
    }

    if (mounted) {
      _pulseScrollTarget(messageId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_showEmojiPanel,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showEmojiPanel) {
          _closeEmojiPanel();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _handleThreadBack,
        ),
        title: BlocBuilder<ThreadCubit, ThreadState>(
          buildWhen: (a, b) =>
              a.headerTitle != b.headerTitle ||
              a.peerAvatarMediaKey != b.peerAvatarMediaKey ||
              a.loading != b.loading ||
              a.dmPeerUserId != b.dmPeerUserId ||
              a.typingUserIds != b.typingUserIds ||
              a.peerOnline != b.peerOnline ||
              a.peerLastSeenAt != b.peerLastSeenAt ||
              a.memberPresence != b.memberPresence,
          builder: (context, state) {
            final isGroup =
                context.read<ThreadCubit>().effectiveConversationType == 'group';
            final title = state.headerTitle?.trim();
            final String titleText;
            if (title != null && title.isNotEmpty) {
              titleText = title;
            } else {
              titleText = l10n.threadTitle(widget.conversationId);
            }
            final isDark = theme.brightness == Brightness.dark;
            final subtitleColor =
                isDark ? AppColors.subtitleDark : AppColors.subtitleLight;
            final titleStyle = GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.onBackgroundDark
                  : AppColors.onBackgroundLight,
            );
            final titleRow = Row(
              children: [
                UserAvatar(
                  displayName: titleText,
                  avatarMediaKey: isGroup ? null : state.peerAvatarMediaKey,
                  size: 36,
                  isGroup: isGroup,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        titleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      ThreadAppBarStatus(
                        isGroup: isGroup,
                        typingUserIds: state.typingUserIds,
                        myUserId: widget.myUserId,
                        dmPeerUserId: state.dmPeerUserId,
                        peerOnline: state.peerOnline,
                        peerLastSeenAt: state.peerLastSeenAt,
                        memberPresence: state.memberPresence,
                        subtitleColor: subtitleColor,
                      ),
                    ],
                  ),
                ),
              ],
            );
            if (!isGroup) {
              final peerId = state.dmPeerUserId;
              if (peerId == null) return titleRow;
              return Tooltip(
                message: 'View profile',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openDmPeerProfile(context, peerId),
                    child: titleRow,
                  ),
                ),
              );
            }
            return Tooltip(
              message: l10n.threadMenuGroupInfo,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openGroupDetailScreen(context),
                  child: titleRow,
                ),
              ),
            );
          },
        ),
        actions: [
          BlocBuilder<ThreadCubit, ThreadState>(
            builder: (context, state) {
              final t = context.read<ThreadCubit>().effectiveConversationType;
              if (t != 'group') return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.search_rounded),
                tooltip: 'Search',
                onPressed: () => _openGroupMessageSearch(context),
              );
            },
          ),
          IconButton(
            icon: Icon(_muted ? Icons.notifications_off_outlined : Icons.notifications_outlined),
            tooltip: _muted ? 'Unmute' : 'Mute',
            onPressed: () async {
              final p = context.read<ChatMutePrefs>();
              final next = !_muted;
              await p.setMuted(widget.conversationId, next);
              if (mounted) setState(() => _muted = next);
            },
          ),
          BlocBuilder<ThreadCubit, ThreadState>(
            buildWhen: (a, b) => a.dmPeerUserId != b.dmPeerUserId,
            builder: (context, state) {
              final peerId = state.dmPeerUserId;
              if (peerId == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.block_outlined),
                tooltip: l10n.buttonBlock,
                onPressed: () => _confirmBlockDmPeer(context, peerId),
              );
            },
          ),
          BlocBuilder<ThreadCubit, ThreadState>(
            builder: (context, state) {
              final t = context.read<ThreadCubit>().effectiveConversationType;
              if (t != 'group') return const SizedBox.shrink();
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  if (value == 'groupInfo') {
                    _openGroupDetailScreen(context);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem<String>(
                    value: 'groupInfo',
                    child: Text(l10n.threadMenuGroupInfo),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<ThreadCubit, ThreadState>(
              listenWhen: (p, c) => p.error != c.error,
              listener: (context, state) {
                if (state.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.error!)),
                  );
                }
              },
              builder: (context, state) {
                if (state.loading && state.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sig = _chatSignature(state);
                if (sig != _lastChatSyncSig) {
                  _lastChatSyncSig = sig;
                  // Capture `state` here so each distinct state (including the
                  // transient "pending/clock" state) is processed individually.
                  final capturedState = state;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      unawaited(_syncChatMessages(capturedState));
                    }
                  });
                }
                final isDark = theme.brightness == Brightness.dark;
                _captureKeyboardHeight(context);
                final chatTheme = _buildChatTheme(theme, isDark);
                final maxBubbleW = math.min(340.0, MediaQuery.sizeOf(context).width * 0.78);
                return Chat(
                  currentUserId: '${widget.myUserId}',
                  resolveUser: (id) async {
                    final cubit = context.read<ThreadCubit>();
                    final s = cubit.state;
                    final isMe = id == '${widget.myUserId}';
                    String? imageSource;
                    final key = isMe
                        ? s.myAvatarMediaKey
                        : (s.dmPeerUserId?.toString() == id
                            ? s.peerAvatarMediaKey
                            : null);
                    if (key != null && key.isNotEmpty) {
                      imageSource = socialMediaResolveUrl(widget.apiBaseUrl, key);
                    }
                    return User(
                      id: id,
                      name: isMe ? l10n.userNameYou : l10n.userFallback(id),
                      imageSource: imageSource,
                    );
                  },
                  chatController: _chatController,
                  theme: chatTheme,
                  backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                  onMessageSend: (text) {
                    _typingIdleTimer?.cancel();
                    context.read<ThreadCubit>().onTyping(false);
                    context.read<ThreadCubit>().send(text);
                  },
                  onAttachmentTap: () => _openAttachmentSheet(context),
                  onMessageLongPress: (ctx, message, {required index, required details}) {
                    final id = int.tryParse(message.id);
                    if (id == null) return;
                    final cubit = context.read<ThreadCubit>();
                    final local = _localById(cubit.state.messages, id);
                    if (local == null) return;
                    if (local.senderId == widget.myUserId) {
                      unawaited(_ownMessageActions(context, local));
                    } else {
                      unawaited(_peerMessageActions(context, local));
                    }
                  },
                  builders: Builders(
                    customMessageBuilder:
                        (context, CustomMessage message, int index, {required isSentByMe, groupStatus}) {
                      if (message.metadata?['mamanaStoryReply'] == true) {
                        final text =
                            (message.metadata?['story_reply_text'] as String?) ?? '';
                        final theme = context.read<ChatTheme>();
                        final bubble = isSentByMe
                            ? theme.colors.primary
                            : theme.colors.surfaceContainerHigh;
                        final fg = isSentByMe ? theme.colors.onPrimary : theme.colors.onSurface;
                        return Align(
                          alignment:
                              isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxBubbleW),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: bubble,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_stories_outlined, color: fg, size: 22),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      text.isEmpty ? 'Story' : text,
                                      style: TextStyle(color: fg),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      final gifUrl = message.metadata?['mamanaGifUrl'] as String?;
                      if (gifUrl != null && gifUrl.isNotEmpty) {
                        final preview =
                            message.metadata?['mamanaGifPreviewUrl'] as String? ?? gifUrl;
                        final w = message.metadata?['mamanaGifWidth'] as int?;
                        final h = message.metadata?['mamanaGifHeight'] as int?;
                        final theme = context.read<ChatTheme>();
                        final fg = isSentByMe
                            ? theme.colors.onPrimary
                            : theme.colors.onSurface;
                        return MamanaGifBubble(
                          url: gifUrl,
                          previewUrl: preview,
                          isSentByMe: isSentByMe,
                          width: w,
                          height: h,
                          maxWidth: maxBubbleW,
                          onTap: () => _openGifFullscreen(context, gifUrl),
                          time: message.resolvedTime,
                          status: isSentByMe ? message.resolvedStatus : null,
                          showStatus: isSentByMe,
                          footerTextStyle: theme.typography.labelSmall.copyWith(
                            color: fg.withValues(alpha: 0.85),
                          ),
                        );
                      }
                      final emoji = message.metadata?['mamanaStickerEmoji'] as String?;
                      if (emoji == null) {
                        return const SizedBox.shrink();
                      }
                      final theme = context.read<ChatTheme>();
                      final bubble = isSentByMe
                          ? theme.colors.primary
                          : theme.colors.surfaceContainerHigh;
                      final fg = isSentByMe
                          ? theme.colors.onPrimary
                          : theme.colors.onSurface;
                      return Align(
                        alignment:
                            isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxBubbleW),
                          child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: bubble,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 56)),
                              const SizedBox(height: 2),
                              CustomTimeAndStatus(
                                time: message.resolvedTime,
                                status: isSentByMe ? message.resolvedStatus : null,
                                showStatus: isSentByMe,
                                textStyle: theme.typography.labelSmall.copyWith(
                                  color: fg.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ),
                      );
                    },
                    chatMessageBuilder:
                        (context, message, index, animation, child, {isRemoved, required isSentByMe, groupStatus}) {
                      // Custom builders replace [ChatMessage], which owns the long-press /
                      // tap [GestureDetector] wired to [onMessageLongPress]. Re-wrap so
                      // actions (copy, reply, etc.) still fire.
                      return ChatMessage(
                        message: message,
                        index: index,
                        animation: animation,
                        isRemoved: isRemoved,
                        groupStatus: groupStatus,
                        child: Align(
                          alignment:
                              isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxBubbleW),
                            child: _wrapScrollTargetHighlight(
                              message.id,
                              _SwipeReplyDetector(
                                isSentByMe: isSentByMe,
                                onSwipeReply: () {
                                  final id = int.tryParse(message.id);
                                  if (id == null) return;
                                  final cubit = context.read<ThreadCubit>();
                                  final local =
                                      _localById(cubit.state.messages, id);
                                  if (local == null) return;
                                  HapticFeedback.selectionClick();
                                  cubit.setReplyTo(local);
                                },
                                child: child,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    textMessageBuilder:
                        (context, message, index, {required isSentByMe, groupStatus}) {
                      // Custom bubble so we can pair the timestamp with our
                      // four-state [MessageStatusIcon] (the library's default
                      // [SimpleTextMessage] uses `getIconForStatus`, which
                      // collapses Sent and Delivered onto the same icon).
                      final theme = context.read<ChatTheme>();
                      final bubble = isSentByMe
                          ? theme.colors.primary
                          : theme.colors.surfaceContainerHigh;
                      final fg = isSentByMe
                          ? theme.colors.onPrimary
                          : theme.colors.onSurface;
                      final replyPreview =
                          _replyPreviewForChatMessage(message);
                      final showReply =
                          _hasReplyQuote(message) && replyPreview != null;
                      final groupedFollowUp =
                          groupStatus?.isFirst == false;
                      return Align(
                        alignment:
                            isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxBubbleW),
                          child: Container(
                            margin: EdgeInsets.fromLTRB(
                              8,
                              showReply && groupedFollowUp ? 10 : 4,
                              8,
                              4,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: bubble,
                              borderRadius: BorderRadius.circular(
                                AppShapes.bubbleRadius,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (showReply)
                                  ReplyQuote(
                                    data: replyPreview!,
                                    accentColor: isSentByMe
                                        ? fg.withValues(alpha: 0.85)
                                        : AppColors.primary,
                                    textColor: fg,
                                    accessToken: widget.accessToken,
                                    onPrimaryBubble: isSentByMe,
                                    onTap: _replyQuoteTapHandler(context, message),
                                  ),
                                Text(
                                  message.text,
                                  textAlign: TextAlign.start,
                                  textDirection: textDirectionFor(message.text),
                                  style: theme.typography.bodyMedium
                                      .copyWith(color: fg),
                                ),
                                const SizedBox(height: 2),
                                CustomTimeAndStatus(
                                  time: message.resolvedTime,
                                  status: isSentByMe
                                      ? message.resolvedStatus
                                      : null,
                                  showStatus: isSentByMe,
                                  isEdited:
                                      (message.metadata?['mamanaIsEdited']
                                          as bool?) ??
                                      false,
                                  textStyle: theme.typography.labelSmall.copyWith(
                                    color: fg.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    imageMessageBuilder:
                        (context, message, index, {required isSentByMe, groupStatus}) {
                      final theme = context.read<ChatTheme>();
                      final bubble =
                          isSentByMe ? theme.colors.primary : theme.colors.surfaceContainerHigh;
                      final fg = isSentByMe ? theme.colors.onPrimary : theme.colors.onSurface;
                      final replyPreview =
                          _replyPreviewForChatMessage(message);
                      final showReply =
                          _hasReplyQuote(message) && replyPreview != null;
                      // Pending media bubbles render the local file directly via
                      // [Image.file] — `Image.network` chokes on a `file://` URI
                      // and bearer headers obviously don't apply.
                      final src = message.source;
                      final localPath = src.startsWith('file://')
                          ? Uri.parse(src).toFilePath()
                          : null;
                      Widget imageWidget;
                      if (localPath != null) {
                        imageWidget = Image.file(
                          File(localPath),
                          width: kChatInlineImageW,
                          height: kChatInlineImageH,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Padding(
                            padding: const EdgeInsets.all(8),
                            child: Center(
                              child: Text(
                                message.text ?? src,
                                style: TextStyle(color: fg),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      } else {
                        imageWidget = Image.network(
                          src,
                          width: kChatInlineImageW,
                          height: kChatInlineImageH,
                          fit: BoxFit.cover,
                          headers: {
                            'Authorization': 'Bearer ${widget.accessToken}',
                          },
                          loadingBuilder: (c, child, progress) {
                            if (progress == null) {
                              return child;
                            }
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                color: fg.withValues(alpha: 0.12),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Padding(
                            padding: const EdgeInsets.all(8),
                            child: Center(
                              child: Text(
                                message.text ?? src,
                                style: TextStyle(color: fg),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      }
                      final captionWidget = buildMediaCaptionWidget(
                        message.metadata?['caption'] as String?,
                        fg,
                      );
                      return Align(
                        alignment:
                            isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxBubbleW),
                          child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: bubble,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showReply)
                                ReplyQuote(
                                  data: replyPreview!,
                                  accentColor: isSentByMe
                                      ? fg.withValues(alpha: 0.85)
                                      : AppColors.primary,
                                  textColor: fg,
                                  accessToken: widget.accessToken,
                                  onPrimaryBubble: isSentByMe,
                                  onTap: _replyQuoteTapHandler(context, message),
                                ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: kChatInlineImageW,
                                  height: kChatInlineImageH,
                                  child: GestureDetector(
                                    onTap: localPath != null
                                        ? null
                                        : () => openChatFullscreenImage(
                                              context,
                                              url: src,
                                              accessToken: widget.accessToken,
                                            ),
                                    child: imageWidget,
                                  ),
                                ),
                              ),
                              if (captionWidget != null) captionWidget,
                              CustomTimeAndStatus(
                                time: message.resolvedTime,
                                status: isSentByMe
                                    ? message.resolvedStatus
                                    : null,
                                showStatus: isSentByMe,
                                textStyle: theme.typography.labelSmall.copyWith(
                                  color: fg.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ),
                      );
                    },
                    videoMessageBuilder:
                        (context, message, index, {required isSentByMe, groupStatus}) {
                      final theme = context.read<ChatTheme>();
                      final bubble =
                          isSentByMe ? theme.colors.primary : theme.colors.surfaceContainerHigh;
                      final fg = isSentByMe ? theme.colors.onPrimary : theme.colors.onSurface;
                      return Align(
                        alignment:
                            isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxBubbleW),
                          child: ThreadVideoBubble(
                            message: message,
                            accessToken: widget.accessToken,
                            bubble: bubble,
                            foreground: fg,
                            isSentByMe: isSentByMe,
                          ),
                        ),
                      );
                    },
                    audioMessageBuilder:
                        (context, message, index, {required isSentByMe, groupStatus}) {
                      final theme = context.read<ChatTheme>();
                      final bubble =
                          isSentByMe ? theme.colors.primary : theme.colors.surfaceContainerHigh;
                      final fg = isSentByMe ? theme.colors.onPrimary : theme.colors.onSurface;
                      final replyPreview =
                          _replyPreviewForChatMessage(message);
                      final showReply =
                          _hasReplyQuote(message) && replyPreview != null;
                      return Align(
                        alignment:
                            isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxBubbleW),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showReply)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                                  child: ReplyQuote(
                                    data: replyPreview!,
                                    accentColor: isSentByMe
                                        ? fg.withValues(alpha: 0.85)
                                        : AppColors.primary,
                                    textColor: fg,
                                    accessToken: widget.accessToken,
                                    onPrimaryBubble: isSentByMe,
                                    onTap: _replyQuoteTapHandler(context, message),
                                  ),
                                ),
                              ThreadAudioBubble(
                                message: message,
                                chatRepository: context.read<ThreadCubit>().chatRepository,
                                accessToken: widget.accessToken,
                                bubble: bubble,
                                foreground: fg,
                                isSentByMe: isSentByMe,
                                onLayoutSettled:
                                    _stickToBottom ? _scheduleScrollToBottom : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    chatAnimatedListBuilder: (ctx, itemBuilder) {
                      // Default (non-reversed) list: oldest at top, newest above composer.
                      // ChatAnimatedListReversed + setMessages diffs can hit
                      // SliverAnimatedList child-order assertions.
                      return ChatAnimatedList(
                        scrollController: _listScrollController,
                        itemBuilder: itemBuilder,
                      );
                    },
                    // Chat overlays the composer on a Stack; [Composer] uses
                    // Positioned(bottom: 0). A raw Column here pins to the top — use
                    // [Composer.topWidget] so reply/search sits above the field but
                    // the bar stays at the bottom.
                    composerBuilder: (ctx) => ThreadComposerWithPanel(
                      textEditingController: _composerController,
                      focusNode: _composerFocusNode,
                      hintText: l10n.composerHint,
                      handleSafeArea: true,
                      onLayoutHeightChanged: _scheduleScrollToBottom,
                      isDark: isDark,
                      showEmojiPanel: _showEmojiPanel,
                      panelHeight: _keyboardHeight,
                      panelInitialTab: _emojiPanelTab,
                      giphyApiKey: _giphyApiKey,
                      onToggleEmojiPanel: () => _toggleEmojiPanel(),
                      onEmojiSelected: _insertEmoji,
                      onGifSelected: (gif) => _sendGiphySelection(gif, kind: 'gif'),
                      onStickerSelected: (gif) => _sendGiphySelection(gif, kind: 'sticker'),
                      onVoiceSend: (path, duration) async {
                        await context.read<ThreadCubit>().sendMediaFile(
                          path: path,
                          kind: 'voice',
                        );
                      },
                      onVoicePermissionDenied: () {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Microphone permission required'),
                          ),
                        );
                      },
                      topWidget: BlocBuilder<ThreadCubit, ThreadState>(
                        buildWhen: (a, b) =>
                            a.replyTo != b.replyTo || a.messageSearchQuery != b.messageSearchQuery,
                        builder: (context, st) {
                          final hasReply = st.replyTo != null;
                          final hasSearch = st.messageSearchQuery != null;
                          if (!hasReply && !hasSearch) {
                            return const SizedBox.shrink();
                          }
                          final borderCol = isDark ? AppColors.dividerDark : AppColors.dividerLight;
                          return Material(
                            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasSearch)
                                  _ComposerMetaStrip(
                                    borderColor: borderCol,
                                    child: Row(
                                      children: [
                                        Icon(Icons.search, size: 18, color: AppColors.primary),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Search: "${st.messageSearchQuery}"',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(fontSize: 13),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              context.read<ThreadCubit>().setMessageSearchQuery(null),
                                          child: Text(l10n.buttonCancel),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (hasReply)
                                  Builder(
                                    builder: (ctx) {
                                      final preview =
                                          _replyPreviewForMessage(st.replyTo!);
                                      return _ComposerMetaStrip(
                                        borderColor: borderCol,
                                        child: ComposerReplyPreview(
                                          data: preview,
                                          replyToTitle:
                                              l10n.replyToUser(preview.authorName),
                                          accessToken: widget.accessToken,
                                          isDark: isDark,
                                          onDismiss: () => context
                                              .read<ThreadCubit>()
                                              .setReplyTo(null),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _openGroupDetailScreen(BuildContext context) {
    context.pushGroupDetail(widget.conversationId);
  }

  void _openDmPeerProfile(BuildContext context, int peerId) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => UserProfilePage(userId: peerId),
      ),
    );
  }

  Future<void> _openGroupMessageSearch(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = TextEditingController();
    final q = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search messages'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'At least 2 characters'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.buttonCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Search'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (!context.mounted || q == null) return;
    await context.read<ThreadCubit>().setMessageSearchQuery(q);
  }

  void _openGifFullscreen(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAttachmentSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo library'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video'),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || picked == null) return;
    final cubit = context.read<ThreadCubit>();
    final picker = ImagePicker();
    switch (picked) {
      case 'gallery':
        final x = await picker.pickImage(source: ImageSource.gallery);
        if (x == null) break;
        if (!context.mounted) return;
        final picked = await openMediaCaptionPreview(
          context,
          path: x.path,
          kind: 'image',
        );
        if (picked != null && context.mounted) {
          await cubit.sendMediaFile(
            path: picked.path,
            kind: 'image',
            caption: picked.caption,
          );
        }
        break;
      case 'camera':
        final x = await picker.pickImage(source: ImageSource.camera);
        if (x == null) break;
        if (!context.mounted) return;
        final picked = await openMediaCaptionPreview(
          context,
          path: x.path,
          kind: 'image',
        );
        if (picked != null && context.mounted) {
          await cubit.sendMediaFile(
            path: picked.path,
            kind: 'image',
            caption: picked.caption,
          );
        }
        break;
      case 'video':
        final x = await picker.pickVideo(source: ImageSource.gallery);
        if (x == null) break;
        if (!context.mounted) return;
        final picked = await openMediaCaptionPreview(
          context,
          path: x.path,
          kind: 'video',
        );
        if (picked != null && context.mounted) {
          await cubit.sendMediaFile(
            path: picked.path,
            kind: 'video',
            caption: picked.caption,
          );
        }
        break;
    }
  }

  ChatTheme _buildChatTheme(ThemeData theme, bool isDark) {
    return ChatTheme(
      shape: const BorderRadius.all(Radius.circular(AppShapes.bubbleRadius)),
      colors: ChatColors(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        surface: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
        onSurface: isDark ? AppColors.onBackgroundDark : AppColors.onBackgroundLight,
        surfaceContainerLow:
            isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        surfaceContainer:
            isDark ? AppColors.cardDark : const Color(0xFFF0F0F0),
        surfaceContainerHigh:
            isDark ? AppColors.receivedBubbleDark : AppColors.receivedBubbleLight,
      ),
      typography: ChatTypography(
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.subtitleLight,
        ),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        labelMedium:
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: AppColors.subtitleLight,
        ),
      ),
    );
  }

  Future<void> _ownMessageActions(BuildContext context, LocalMessage m) async {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<ThreadCubit>();
    final canCopy = isEditableChatMessage(m);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: Text(l10n.actionReply),
              onTap: () => Navigator.pop(ctx, 'reply'),
            ),
            if (canCopy)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(l10n.actionCopy),
                onTap: () => Navigator.pop(ctx, 'copy'),
              ),
            if (canCopy)
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(l10n.actionEdit),
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: Text(l10n.actionDeleteForMe),
              onTap: () => Navigator.pop(ctx, 'me'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: Text(l10n.actionDeleteForEveryone),
              onTap: () => Navigator.pop(ctx, 'all'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'reply') {
      cubit.setReplyTo(m);
    } else if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: m.body));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.snackCopiedMessage)),
        );
      }
    } else if (action == 'edit') {
      final ctrl = TextEditingController(text: m.body);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.editMessageTitle),
          content: TextField(controller: ctrl, maxLines: 4),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.buttonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.buttonSave),
            ),
          ],
        ),
      );
      if (ok == true && context.mounted) {
        await cubit.editMessage(m.id, ctrl.text);
      }
      ctrl.dispose();
    } else if (action == 'me') {
      await cubit.deleteMessage(m.id, forEveryone: false);
    } else if (action == 'all') {
      await cubit.deleteMessage(m.id, forEveryone: true);
    }
  }

  Future<void> _confirmBlockDmPeer(BuildContext context, int peerUserId) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.blockPeerConfirmTitle),
        content: Text(l10n.blockPeerConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.buttonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.buttonBlock),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ChatRepository>().blockUser(peerUserId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.snackBlocked)),
        );
      }
    }
  }

  Future<void> _peerMessageActions(BuildContext context, LocalMessage m) async {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<ThreadCubit>();
    final ct = m.contentType.toLowerCase().trim();
    final canCopy = (ct == 'text/plain' || ct.startsWith('text/plain;')) &&
        m.body.trim().isNotEmpty;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: Text(l10n.actionReply),
              onTap: () => Navigator.pop(ctx, 'reply'),
            ),
            if (canCopy)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(l10n.actionCopy),
                onTap: () => Navigator.pop(ctx, 'copy'),
              ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.actionReport),
              onTap: () => Navigator.pop(ctx, 'report'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'reply') {
      cubit.setReplyTo(m);
    } else if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: m.body));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.snackCopiedMessage)),
        );
      }
    } else if (action == 'report' && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.snackReportSubmitted)),
      );
    }
  }
}

/// Thin divider + padding row used above the composer for reply / search context.
class _ComposerMetaStrip extends StatelessWidget {
  const _ComposerMetaStrip({
    required this.borderColor,
    required this.child,
  });

  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: child,
      ),
    );
  }
}

/// Horizontal swipe toward the list center starts a reply (received: right; sent: left).
/// Dragging translates the bubble slightly (Telegram-style visual feedback).
class _SwipeReplyDetector extends StatefulWidget {
  const _SwipeReplyDetector({
    required this.isSentByMe,
    required this.onSwipeReply,
    required this.child,
  });

  final bool isSentByMe;
  final VoidCallback onSwipeReply;
  final Widget child;

  @override
  State<_SwipeReplyDetector> createState() => _SwipeReplyDetectorState();
}

class _SwipeReplyDetectorState extends State<_SwipeReplyDetector> {
  /// Accumulated horizontal drag for threshold detection.
  double _dragDx = 0;

  /// Clamped offset applied to [Transform.translate] while dragging.
  double _visualDx = 0;

  static const _threshold = 56.0;
  static const _maxVisual = 72.0;

  void _onUpdate(DragUpdateDetails d) {
    _dragDx += d.delta.dx;
    if (widget.isSentByMe) {
      _visualDx = _dragDx.clamp(-_maxVisual, _maxVisual * 0.2);
    } else {
      _visualDx = _dragDx.clamp(-_maxVisual * 0.2, _maxVisual);
    }
    setState(() {});
  }

  void _onEnd() {
    final ok = widget.isSentByMe ? _dragDx < -_threshold : _dragDx > _threshold;
    _dragDx = 0;
    if (ok) widget.onSwipeReply();
    setState(() => _visualDx = 0);
  }

  void _onCancel() {
    _dragDx = 0;
    setState(() => _visualDx = 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: (_) => _onEnd(),
      onHorizontalDragCancel: _onCancel,
      child: Transform.translate(
        offset: Offset(_visualDx, 0),
        child: widget.child,
      ),
    );
  }
}
