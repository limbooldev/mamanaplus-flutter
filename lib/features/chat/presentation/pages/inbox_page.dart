import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mamana_plus/l10n/app_localizations.dart';

import '../../../../router/app_routes.dart';
import '../../../../core/formatting/relative_message_time.dart';
import '../../../../core/database/app_database.dart';
import '../../../../shared/ui/ui.dart';
import '../../data/chat_repository.dart';
import '../cubit/inbox_cubit.dart';
import '../cubit/public_groups_cubit.dart';

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(
      length: 2,
      child: BlocProvider(
        create: (context) => InboxCubit(context.read<ChatRepository>())..refresh(),
        child: Scaffold(
          appBar: _InboxAppBar(l10n: l10n, isDark: isDark),
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

// ─── AppBar ───────────────────────────────────────────────────────────────────

class _InboxAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _InboxAppBar({required this.l10n, required this.isDark});
  final AppLocalizations l10n;
  final bool isDark;

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + kTextTabBarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(l10n.chatsTitle),
      actions: [
        _NewGroupButton(l10n: l10n),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(kTextTabBarHeight),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              ),
            ),
          ),
          child: TabBar(
            tabs: [
              Tab(text: l10n.tabChats),
              Tab(text: l10n.tabGroups),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── New Group Button ─────────────────────────────────────────────────────────

class _NewGroupButton extends StatelessWidget {
  const _NewGroupButton({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.group_add_outlined),
      onPressed: () async {
        await context.pushNewGroup();
        if (context.mounted) context.read<InboxCubit>().refresh();
      },
    );
  }
}

// ─── FAB ──────────────────────────────────────────────────────────────────────

class _DmFab extends StatelessWidget {
  const _DmFab({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'fab_inbox_new_dm',
      onPressed: () => _openPickUser(context, l10n),
      child: const Icon(Icons.edit_outlined),
    );
  }

  Future<void> _openPickUser(BuildContext context, AppLocalizations l10n) async {
    final id = await context.pushPickUsersSingle();
    if (id != null && context.mounted) {
      try {
        final res = await context.read<ChatRepository>().createDm(id);
        if (!context.mounted) return;
        await context.read<InboxCubit>().refresh();
        if (!context.mounted) return;
        final conversationId = (res['id'] as num).toInt();
        await context.pushThread(conversationId, conversationType: 'private');
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')),
          );
        }
      }
    }
  }
}

// ─── Chats tab ────────────────────────────────────────────────────────────────

class _ChatsTab extends StatelessWidget {
  const _ChatsTab({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InboxCubit, InboxState>(
      builder: (context, state) {
        if (state.loading && state.items.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (state.error != null) {
          return _ErrorState(message: state.error!);
        }
        if (state.items.isEmpty) {
          return _EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            message: 'No conversations yet.\nTap + to start one.',
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => context.read<InboxCubit>().refresh(),
          child: ListView.separated(
            itemCount: state.items.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: 72,
            ),
            itemBuilder: (context, i) {
              final c = state.items[i];
              final title = _titleFor(c, l10n);
              final isGroup = c.type == 'group';
              return _ConversationTile(
                title: title,
                previewLine: _previewLine(c, isGroup),
                timeLabel: _timeLabel(context, c),
                isGroup: isGroup,
                conversationId: c.id,
                unreadCount: c.unreadCount,
                onTap: () async {
                  await context.pushThread(
                    c.id,
                    conversationType: c.type,
                  );
                  if (context.mounted) {
                    await context.read<InboxCubit>().refreshQuiet();
                  }
                },
              );
            },
          ),
        );
      },
    );
  }

  String _previewLine(LocalConversation c, bool isGroup) {
    final preview = c.lastMessagePreview?.trim();
    if (preview != null && preview.isNotEmpty) return preview;
    return isGroup ? 'Group' : 'Direct message';
  }

  String? _timeLabel(BuildContext context, LocalConversation c) {
    final at = c.lastMessageAt;
    if (at == null) return null;
    return formatRelativeMessageTime(
      at,
      locale: Localizations.localeOf(context).toString(),
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

// ─── Conversation tile ────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.title,
    required this.previewLine,
    required this.timeLabel,
    required this.isGroup,
    required this.conversationId,
    required this.unreadCount,
    required this.onTap,
  });

  final String title;
  /// Last message preview or placeholder (no timestamp).
  final String previewLine;
  final String? timeLabel;
  final bool isGroup;
  final int conversationId;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = title.isNotEmpty ? title[0].toUpperCase() : '?';
    final titleColor = isDark
        ? AppColors.onBackgroundDark
        : AppColors.onBackgroundLight;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(initials: initials, isGroup: isGroup),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                      ),
                      if (timeLabel != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          timeLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.subtitleLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          previewLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.subtitleLight,
                          ),
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        _UnreadBadge(count: unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─── Avatar widget ────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.isGroup});
  final String initials;
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isGroup
              ? [AppColors.primaryDeep, AppColors.primary]
              : [AppColors.primary, AppColors.primary.withValues(alpha: 0.75)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─── Public Groups tab ────────────────────────────────────────────────────────

class _PublicGroupsTab extends StatelessWidget {
  const _PublicGroupsTab({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          PublicGroupsCubit(context.read<ChatRepository>())..refresh(),
      child: BlocBuilder<PublicGroupsCubit, PublicGroupsState>(
        builder: (context, state) {
          if (state.loading && state.items.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (state.error != null) {
            return _ErrorState(message: state.error!);
          }
          if (state.items.isEmpty) {
            return _EmptyState(
              icon: Icons.group_outlined,
              message: l10n.noPublicGroups,
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => context.read<PublicGroupsCubit>().refresh(),
            child: ListView.separated(
              itemCount: state.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials =
        group.title.isNotEmpty ? group.title[0].toUpperCase() : 'G';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(initials: initials, isGroup: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.onBackgroundDark
                        : AppColors.onBackgroundLight,
                  ),
                ),
                if (group.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    group.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.subtitleLight,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 14,
                      color: AppColors.subtitleLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.membersCount(group.memberCount),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.subtitleLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          group.isMember
              ? OutlinedButton(
                  onPressed: () =>
                      context.pushThread(group.id, conversationType: 'group'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size(72, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppShapes.pillRadius),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(l10n.buttonOpen),
                )
              : FilledButton(
                  onPressed: () => _join(context, group.id),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(72, 36),
                  ),
                  child: Text(l10n.buttonJoin),
                ),
        ],
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

// ─── Empty / Error states ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.subtitleLight),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppColors.subtitleLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: GoogleFonts.inter(color: AppColors.error, fontSize: 14),
      ),
    );
  }
}
