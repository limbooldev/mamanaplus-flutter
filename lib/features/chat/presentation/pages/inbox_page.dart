import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mamana_plus/l10n/app_localizations.dart';

import '../../../../router/app_routes.dart';
import '../../../../core/database/app_database.dart';
import '../../data/chat_repository.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/inbox_cubit.dart';

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocProvider(
      create: (context) => InboxCubit(context.read<ChatRepository>())..refresh(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.chatsTitle),
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
                  final title = _titleFor(c, l10n);
                  return ListTile(
                    title: Text(title),
                    subtitle: Text(c.type),
                    trailing: c.type == 'group'
                        ? IconButton(
                            icon: const Icon(Icons.info_outline),
                            onPressed: () => context.pushGroupDetail(c.id),
                          )
                        : null,
                    onTap: () => context.pushThread(c.id, conversationType: c.type),
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

  String _titleFor(LocalConversation c, AppLocalizations l10n) {
    if (c.title != null && c.title!.isNotEmpty) return c.title!;
    if (c.peerJson != null) {
      try {
        final m = jsonDecode(c.peerJson!) as Map<String, dynamic>;
        return m['display_name'] as String? ?? l10n.chatFallback;
      } catch (_) {}
    }
    return l10n.chatFallbackId(c.id);
  }

  Future<void> _showDmDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final idCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dmDialogTitle),
        content: TextField(
          controller: idCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: l10n.dmPeerHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.buttonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.buttonOpen),
          ),
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
