import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/jwt_util.dart';
import '../../data/chat_repository.dart';
import '../cubit/thread_cubit.dart';

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
    return BlocProvider(
      create: (context) => ThreadCubit(
        context.read<ChatRepository>(),
        conversationId,
        myId,
        conversationType: conversationType,
      )..init(),
      child: _ThreadScaffold(conversationId: conversationId, myUserId: myId),
    );
  }
}

class _ThreadScaffold extends StatefulWidget {
  const _ThreadScaffold({required this.conversationId, required this.myUserId});

  final int conversationId;
  final int myUserId;

  @override
  State<_ThreadScaffold> createState() => _ThreadScaffoldState();
}

class _ThreadScaffoldState extends State<_ThreadScaffold> {
  final _controller = TextEditingController();
  Timer? _typingIdleTimer;

  @override
  void dispose() {
    _typingIdleTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(BuildContext context, String text) {
    final cubit = context.read<ThreadCubit>();
    _typingIdleTimer?.cancel();
    if (text.isEmpty) {
      cubit.onTyping(false);
      return;
    }
    cubit.onTyping(true);
    _typingIdleTimer = Timer(const Duration(seconds: 2), () => cubit.onTyping(false));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Thread #${widget.conversationId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.image_outlined),
            tooltip: 'Stub image (presign)',
            onPressed: () => context.read<ThreadCubit>().sendStubAttachment(),
          ),
          IconButton(
            icon: const Icon(Icons.block),
            onPressed: () => _blockPrompt(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<ThreadCubit, ThreadState>(
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
                final typing = state.typingUserIds.isNotEmpty;
                final convType = context.read<ThreadCubit>().conversationType;
                return Column(
                  children: [
                    if (typing)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Someone is typing…', style: TextStyle(fontStyle: FontStyle.italic)),
                      ),
                    Expanded(
                      child: ListView.builder(
                        reverse: true,
                        itemCount: state.messages.length,
                        itemBuilder: (context, i) {
                          final m = state.messages[i];
                          final isReply = m.replyToMessageId != null;
                          final mine = m.senderId == widget.myUserId;
                          final read = state.readReceiptForOwnMessage(m.id, convType);
                          return ListTile(
                            dense: true,
                            title: Text(
                              m.body,
                              style: TextStyle(
                                fontStyle: m.body.isEmpty ? FontStyle.italic : FontStyle.normal,
                              ),
                            ),
                            subtitle: isReply
                                ? Text('↩ reply to #${m.replyToMessageId}')
                                : null,
                            trailing: mine
                                ? Icon(
                                    read ? Icons.done_all : Icons.check,
                                    size: 18,
                                    color: read ? Theme.of(context).colorScheme.primary : null,
                                  )
                                : null,
                            onLongPress: mine
                                ? () => _ownMessageActions(context, m)
                                : () => context.read<ThreadCubit>().setReplyTo(m),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            maintainBottomViewPadding: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BlocBuilder<ThreadCubit, ThreadState>(
                  buildWhen: (a, b) => a.replyTo != b.replyTo,
                  builder: (context, state) {
                    if (state.replyTo == null) return const SizedBox.shrink();
                    return MaterialBanner(
                      content: Text('Replying to: ${state.replyTo!.body}'),
                      actions: [
                        TextButton(
                          onPressed: () => context.read<ThreadCubit>().setReplyTo(null),
                          child: const Text('Cancel'),
                        ),
                      ],
                    );
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(hintText: 'Message'),
                        onChanged: (t) => _onTextChanged(context, t),
                        onSubmitted: (_) => _send(context),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () => _send(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _ownMessageActions(BuildContext context, LocalMessage m) async {
    final cubit = context.read<ThreadCubit>();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Delete for me'),
              onTap: () => Navigator.pop(ctx, 'me'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: const Text('Delete for everyone'),
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
          title: const Text('Edit message'),
          content: TextField(controller: ctrl, maxLines: 4),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
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

  void _send(BuildContext context) {
    final text = _controller.text;
    _controller.clear();
    _typingIdleTimer?.cancel();
    context.read<ThreadCubit>().onTyping(false);
    context.read<ThreadCubit>().send(text);
  }

  Future<void> _blockPrompt(BuildContext context) async {
    final idCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block user id'),
        content: TextField(
          controller: idCtrl,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Block')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final id = int.tryParse(idCtrl.text.trim());
      if (id != null) {
        await context.read<ChatRepository>().blockUser(id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Blocked')));
        }
      }
    }
    idCtrl.dispose();
  }
}
