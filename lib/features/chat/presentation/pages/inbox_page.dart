import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../router/app_routes.dart';
import '../../../../core/database/app_database.dart';
import '../../data/chat_repository.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/inbox_cubit.dart';

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => InboxCubit(context.read<ChatRepository>())..refresh(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chats'),
          actions: [
            IconButton(
              icon: const Icon(Icons.group_add),
              onPressed: () async {
                await context.pushNewGroup();
                if (context.mounted) context.read<InboxCubit>().refresh();
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => context.read<AuthCubit>().logout(),
            ),
          ],
        ),
        body: BlocBuilder<InboxCubit, InboxState>(
          builder: (context, state) {
            if (state.loading && state.items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null) {
              return Center(child: Text(state.error!));
            }
            return RefreshIndicator(
              onRefresh: () => context.read<InboxCubit>().refresh(),
              child: ListView.builder(
                itemCount: state.items.length,
                itemBuilder: (context, i) {
                  final c = state.items[i];
                  final title = _titleFor(c);
                  return ListTile(
                    title: Text(title),
                    subtitle: Text(c.type),
                    onTap: () => context.pushThread(c.id),
                  );
                },
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showDmDialog(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  String _titleFor(LocalConversation c) {
    if (c.title != null && c.title!.isNotEmpty) return c.title!;
    if (c.peerJson != null) {
      try {
        final m = jsonDecode(c.peerJson!) as Map<String, dynamic>;
        return m['display_name'] as String? ?? 'Chat';
      } catch (_) {}
    }
    return 'Chat #${c.id}';
  }

  Future<void> _showDmDialog(BuildContext context) async {
    final idCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open DM with user id'),
        content: TextField(
          controller: idCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Peer user id'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final id = int.tryParse(idCtrl.text.trim());
      if (id != null) {
        await context.read<ChatRepository>().createDm(id);
        if (!context.mounted) return;
        await context.read<InboxCubit>().refresh();
      }
    }
    idCtrl.dispose();
  }
}
