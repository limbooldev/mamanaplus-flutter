import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mamana_plus/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/api_config.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/jwt_util.dart';
import '../../../../shared/ui/ui.dart';
import '../../data/chat_repository.dart';
import '../cubit/thread_cubit.dart';
import '../mappers/local_message_to_chat_message.dart';
import '../widgets/chat_image_editor_flow.dart';
import '../widgets/chat_video_editor_flow.dart';
import '../widgets/thread_media_widgets.dart';

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
  });

  final int conversationId;
  final int myUserId;
  final String accessToken;
  final String apiBaseUrl;

  @override
  State<_ThreadScaffold> createState() => _ThreadScaffoldState();
}

class _ThreadScaffoldState extends State<_ThreadScaffold> {
  final _composerController = TextEditingController();
  late final InMemoryChatController _chatController;
  Timer? _typingIdleTimer;
  String _lastChatSyncSig = '';

  @override
  void initState() {
    super.initState();
    _chatController = InMemoryChatController();
    _composerController.addListener(_handleComposerTextChanged);
  }

  @override
  void dispose() {
    _typingIdleTimer?.cancel();
    _composerController.removeListener(_handleComposerTextChanged);
    _composerController.dispose();
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
    final reads =
        s.readCursorByUserId.entries.map((e) => '${e.key}:${e.value}').join(',');
    return '$parts#$reads';
  }

  Future<void> _syncChatMessages(ThreadState state) async {
    if (!mounted) return;
    final convType = context.read<ThreadCubit>().effectiveConversationType;
    final mapped = mapLocalMessagesToChatMessages(
      state.messages,
      myUserId: widget.myUserId,
      readReceiptForOwn: (id) => state.readReceiptForOwnMessage(id, convType),
      apiBaseUrl: widget.apiBaseUrl,
    );
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
  }

  LocalMessage? _localById(List<LocalMessage> messages, int id) {
    for (final m in messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: BlocBuilder<ThreadCubit, ThreadState>(
          buildWhen: (a, b) => a.headerTitle != b.headerTitle,
          builder: (context, state) {
            final title = state.headerTitle?.trim();
            final String titleText;
            final String initial;
            if (title != null && title.isNotEmpty) {
              titleText = title;
              initial = title[0].toUpperCase();
            } else {
              titleText = l10n.threadTitle(widget.conversationId);
              initial = '#';
            }
            return Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDeep],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titleText,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.block_outlined),
            onPressed: () => _blockPrompt(context),
          ),
        ],
      ),
      body: Column(
        children: [
          BlocBuilder<ThreadCubit, ThreadState>(
            buildWhen: (a, b) => a.replyTo != b.replyTo,
            builder: (context, state) {
              if (state.replyTo == null) return const SizedBox.shrink();
              return MaterialBanner(
                content: Text(l10n.replyingTo(state.replyTo!.body)),
                actions: [
                  TextButton(
                    onPressed: () => context.read<ThreadCubit>().setReplyTo(null),
                    child: Text(l10n.buttonCancel),
                  ),
                ],
              );
            },
          ),
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
                  // Schedule AFTER the current frame so setMessages → insertItem
                  // is not called during build (which Flutter silently drops).
                  // Use the latest cubit state at callback time to avoid stale captures
                  // racing with other pending setMessages calls.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      unawaited(_syncChatMessages(context.read<ThreadCubit>().state));
                    }
                  });
                }
                final typing = state.typingUserIds.isNotEmpty;
                final isDark = theme.brightness == Brightness.dark;
                final chatTheme = _buildChatTheme(theme, isDark);
                return Chat(
                  currentUserId: '${widget.myUserId}',
                  resolveUser: (id) async => User(
                    id: id,
                    name: id == '${widget.myUserId}' ? l10n.userNameYou : l10n.userFallback(id),
                  ),
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
                      cubit.setReplyTo(local);
                    }
                  },
                  builders: Builders(
                    imageMessageBuilder:
                        (context, message, index, {required isSentByMe, groupStatus}) {
                      final theme = context.read<ChatTheme>();
                      final bubble =
                          isSentByMe ? theme.colors.primary : theme.colors.surfaceContainerHigh;
                      final fg = isSentByMe ? theme.colors.onPrimary : theme.colors.onSurface;
                      return Align(
                        alignment:
                            isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
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
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: GestureDetector(
                                  onTap: () => openChatFullscreenImage(
                                    context,
                                    url: message.source,
                                    accessToken: widget.accessToken,
                                  ),
                                  child: Image.network(
                                    message.source,
                                    width: 220,
                                    fit: BoxFit.cover,
                                    headers: {
                                      'Authorization': 'Bearer ${widget.accessToken}',
                                    },
                                    loadingBuilder: (c, child, p) => p == null
                                        ? child
                                        : const SizedBox(
                                            width: 220,
                                            height: 160,
                                            child: Center(
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                    errorBuilder: (_, __, ___) => Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Text(
                                        message.text ?? message.source,
                                        style: TextStyle(color: fg),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (isSentByMe)
                                TimeAndStatus(
                                  time: message.resolvedTime,
                                  status: message.resolvedStatus,
                                  showTime: true,
                                  showStatus: true,
                                  textStyle: theme.typography.labelSmall.copyWith(
                                    color: fg.withValues(alpha: 0.9),
                                  ),
                                ),
                            ],
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
                      return ThreadVideoBubble(
                        message: message,
                        accessToken: widget.accessToken,
                        bubble: bubble,
                        foreground: fg,
                        isSentByMe: isSentByMe,
                      );
                    },
                    audioMessageBuilder:
                        (context, message, index, {required isSentByMe, groupStatus}) {
                      final theme = context.read<ChatTheme>();
                      final bubble =
                          isSentByMe ? theme.colors.primary : theme.colors.surfaceContainerHigh;
                      final fg = isSentByMe ? theme.colors.onPrimary : theme.colors.onSurface;
                      return ThreadAudioBubble(
                        message: message,
                        accessToken: widget.accessToken,
                        bubble: bubble,
                        foreground: fg,
                        isSentByMe: isSentByMe,
                      );
                    },
                    chatAnimatedListBuilder: (ctx, itemBuilder) {
                      // Default (non-reversed) list: oldest at top, newest above composer.
                      // ChatAnimatedListReversed + setMessages diffs can hit
                      // SliverAnimatedList child-order assertions.
                      return ChatAnimatedList(
                        itemBuilder: itemBuilder,
                        bottomSliver: typing
                            ? SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                                  child: Row(
                                    children: [
                                      const IsTypingIndicator(),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.typingIndicator,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontStyle: FontStyle.italic,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                    composerBuilder: (ctx) => Composer(
                      textEditingController: _composerController,
                      hintText: l10n.composerHint,
                      sendButtonDisabled: state.sending,
                      handleSafeArea: true,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
            ListTile(
              leading: const Icon(Icons.mic_none),
              title: const Text('Voice'),
              onTap: () => Navigator.pop(ctx, 'voice'),
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
        final edited = await openChatImageEditor(context, x.path);
        if (edited != null && context.mounted) {
          await cubit.sendMediaFile(path: edited, kind: 'image');
        }
        break;
      case 'camera':
        final x = await picker.pickImage(source: ImageSource.camera);
        if (x == null) break;
        if (!context.mounted) return;
        final edited = await openChatImageEditor(context, x.path);
        if (edited != null && context.mounted) {
          await cubit.sendMediaFile(path: edited, kind: 'image');
        }
        break;
      case 'video':
        final x = await picker.pickVideo(source: ImageSource.gallery);
        if (x == null) break;
        if (!context.mounted) return;
        final edited = await openChatVideoEditor(context, x.path);
        if (edited != null && context.mounted) {
          await cubit.sendMediaFile(path: edited, kind: 'video');
        }
        break;
      case 'voice':
        await _recordVoice(context, cubit);
        break;
    }
  }

  Future<void> _recordVoice(BuildContext context, ThreadCubit cubit) async {
    final rec = AudioRecorder();
    final ok = await rec.hasPermission();
    if (!ok) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
    await rec.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Recording…'),
        actions: [
          TextButton(
            onPressed: () async {
              await rec.stop();
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                await cubit.sendMediaFile(path: path, kind: 'voice');
              }
            },
            child: const Text('Stop & send'),
          ),
        ],
      ),
    );
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
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
    if (action == 'edit') {
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

  Future<void> _blockPrompt(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final idCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.blockDialogTitle),
        content: TextField(
          controller: idCtrl,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.buttonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.buttonBlock),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final id = int.tryParse(idCtrl.text.trim());
      if (id != null) {
        await context.read<ChatRepository>().blockUser(id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.snackBlocked)),
          );
        }
      }
    }
    idCtrl.dispose();
  }
}
