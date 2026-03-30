import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mamana_plus/l10n/app_localizations.dart';

import '../../../../router/app_routes.dart';
import '../../../../core/database/app_database.dart';
import '../../data/chat_repository.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/inbox_cubit.dart';
import '../cubit/public_groups_cubit.dart';

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: BlocProvider(
        create: (context) => InboxCubit(context.read<ChatRepository>())..refresh(),
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.chatsTitle),
            actions: [
              _NewGroupButton(l10n: l10n),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => context.read<AuthCubit>().logout(),
              ),
            ],
            bottom: TabBar(
              tabs: [
                Tab(text: l10n.tabChats),
                Tab(text: l10n.tabGroups),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _ChatsTab(l10n: l10n),
              _PublicGroupsTab(l10n: l10n),
            ],
          ),
          floatingActionButton: _DmFab(l10n: l10n),
        ),
      ),
    );
  }
}

// ─── Chats tab ───────────────────────────────────────────────────────────────

class _NewGroupButton extends StatelessWidget {
  const _NewGroupButton({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    // Only shown when the Chats tab is active.
    return IconButton(
      icon: const Icon(Icons.group_add),
      onPressed: () async {
        await context.pushNewGroup();
        if (context.mounted) context.read<InboxCubit>().refresh();
      },
    );
  }
}

class _DmFab extends StatelessWidget {
  const _DmFab({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showDmDialog(context, l10n),
      child: const Icon(Icons.add),
    );
  }

  Future<void> _showDmDialog(BuildContext context, AppLocalizations l10n) async {
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

class _ChatsTab extends StatelessWidget {
  const _ChatsTab({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InboxCubit, InboxState>(
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
}

// ─── Public Groups tab ────────────────────────────────────────────────────────

class _PublicGroupsTab extends StatelessWidget {
  const _PublicGroupsTab({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PublicGroupsCubit(context.read<ChatRepository>())..refresh(),
      child: BlocBuilder<PublicGroupsCubit, PublicGroupsState>(
        builder: (context, state) {
          if (state.loading && state.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null) {
            return Center(child: Text(state.error!));
          }
          if (state.items.isEmpty) {
            return Center(child: Text(l10n.noPublicGroups));
          }
          return RefreshIndicator(
            onRefresh: () => context.read<PublicGroupsCubit>().refresh(),
            child: ListView.builder(
              itemCount: state.items.length,
              itemBuilder: (context, i) {
                final group = state.items[i];
                return _PublicGroupTile(group: group, l10n: l10n);
              },
            ),
          );
        },
      ),
    );
  }
}

class _PublicGroupTile extends StatelessWidget {
  const _PublicGroupTile({required this.group, required this.l10n});
  final PublicGroup group;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(group.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.description.isNotEmpty)
            Text(
              group.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          Text(l10n.membersCount(group.memberCount)),
        ],
      ),
      isThreeLine: group.description.isNotEmpty,
      trailing: group.isMember
          ? FilledButton.tonal(
              onPressed: () => context.pushThread(group.id, conversationType: 'group'),
              child: Text(l10n.buttonOpen),
            )
          : FilledButton(
              onPressed: () => _join(context, group.id),
              child: Text(l10n.buttonJoin),
            ),
    );
  }

  Future<void> _join(BuildContext context, int groupId) async {
    try {
      await context.read<PublicGroupsCubit>().join(groupId);
      if (context.mounted) {
        context.pushThread(groupId, conversationType: 'group');
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.joinFailed)),
        );
      }
    }
  }
}
