import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/jwt_util.dart';
import '../../data/chat_repository.dart';
import '../cubit/thread_cubit.dart';

class ThreadPage extends StatelessWidget {
  const ThreadPage({
    super.key,
    required this.conversationId,
    required this.accessToken,
  });

  final int conversationId;
  final String accessToken;

  @override
  Widget build(BuildContext context) {
    final myId = parseUserIdFromAccessToken(accessToken) ?? 0;
    return BlocProvider(
      create: (context) => ThreadCubit(
        context.read<ChatRepository>(),
        conversationId,
        myId,
      )..init(),
      child: _ThreadScaffold(conversationId: conversationId),
    );
  }
}

class _ThreadScaffold extends StatefulWidget {
  const _ThreadScaffold({required this.conversationId});

  final int conversationId;

  @override
  State<_ThreadScaffold> createState() => _ThreadScaffoldState();
}

class _ThreadScaffoldState extends State<_ThreadScaffold> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Thread #${widget.conversationId}'),
        actions: [
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
                            onLongPress: () => context.read<ThreadCubit>().setReplyTo(m),
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
                        onChanged: (_) => context.read<ThreadCubit>().onTyping(true),
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

  void _send(BuildContext context) {
    final text = _controller.text;
    _controller.clear();
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
