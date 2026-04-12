import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mamana_plus/l10n/app_localizations.dart';

import '../../../../shared/ui/ui.dart';
import '../../data/chat_repository.dart';

/// Loads `GET /v1/groups/{id}` (conversation + members).
class GroupDetailPage extends StatefulWidget {
  const GroupDetailPage({super.key, required this.conversationId});

  final int conversationId;

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _bans = [];
  Object? _error;
  var _loading = true;
  var _leaving = false;
  int? _myUserId;
  String? _myRole;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  bool get _isModerator {
    final r = _myRole;
    return r == 'admin' || r == 'owner';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<ChatRepository>();
      try {
        final me = await repo.fetchMe();
        if (mounted) {
          _myUserId = (me['id'] as num).toInt();
        }
      } catch (_) {}

      final d = await repo.getGroup(widget.conversationId);
      if (!mounted) return;
      setState(() => _data = d);

      _myRole = _roleForCurrentUser(d);

      if (_isModerator) {
        try {
          final bans = await repo.listGroupBans(widget.conversationId);
          if (mounted) setState(() => _bans = bans);
        } catch (_) {
          if (mounted) setState(() => _bans = []);
        }
      } else {
        if (mounted) setState(() => _bans = []);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _roleForCurrentUser(Map<String, dynamic> data) {
    final myId = _myUserId;
    if (myId == null) return null;
    final members = data['members'] as List<dynamic>? ?? [];
    for (final raw in members) {
      final m = raw as Map<String, dynamic>;
      final u = m['user'] as Map<String, dynamic>? ?? {};
      final id = (u['id'] as num?)?.toInt();
      if (id == myId) {
        return m['role'] as String? ?? 'member';
      }
    }
    return null;
  }

  Future<void> _confirmLeave(AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.leaveGroupConfirmTitle),
        content: Text(l10n.leaveGroupConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.buttonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.buttonLeave,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _leaving = true);
    try {
      await context.read<ChatRepository>().leaveGroup(widget.conversationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.snackLeftGroup)),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.leaveGroupFailed)),
      );
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  Future<void> _confirmRemoveMember(
    AppLocalizations l10n,
    ChatRepository repo,
    String name,
    int userId,
  ) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.groupRemoveMemberTitle),
        content: Text(l10n.groupRemoveMemberBody(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.buttonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.buttonRemove),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    try {
      await repo.removeGroupMember(widget.conversationId, userId);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.groupModerationFailed)),
        );
      }
    }
  }

  Future<void> _confirmBanMember(
    AppLocalizations l10n,
    ChatRepository repo,
    String name,
    int userId,
  ) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.groupBanMemberTitle),
        content: Text(l10n.groupBanMemberBody(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.buttonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.groupActionBanMember),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    try {
      await repo.banGroupMember(widget.conversationId, userId);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.groupModerationFailed)),
        );
      }
    }
  }

  Future<void> _unban(AppLocalizations l10n, ChatRepository repo, int userId) async {
    try {
      await repo.unbanGroupMember(widget.conversationId, userId);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.groupModerationFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.groupAppBarTitle),
        actions: [
          if (!_loading && _error == null)
            TextButton(
              onPressed: _leaving ? null : () => _confirmLeave(l10n),
              child: Text(
                l10n.buttonLeaveGroup,
                style: GoogleFonts.inter(
                  color: _leaving ? AppColors.subtitleLight : AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
              ? Center(
                  child: Text(
                    '$_error',
                    style: GoogleFonts.inter(
                      color: AppColors.error,
                      fontSize: 14,
                    ),
                  ),
                )
              : _buildBody(l10n, isDark),
    );
  }

  Widget _buildBody(AppLocalizations l10n, bool isDark) {
    final conv = _data?['conversation'] as Map<String, dynamic>?;
    final members = _data?['members'] as List<dynamic>? ?? [];
    final title =
        conv?['title'] as String? ?? l10n.groupFallbackTitle(widget.conversationId);
    final repo = context.read<ChatRepository>();
    final desc = (conv?['description'] as String?)?.trim();
    final online = (_data?['online_count'] as num?)?.toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupHeader(
          title: title,
          memberCountLabel: l10n.membersCount(members.length),
          isDark: isDark,
        ),
        if (desc != null && desc.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              desc,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.35,
                color: AppColors.subtitleLight,
              ),
            ),
          ),
        if (online != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              l10n.groupOnlineNow(online),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        Divider(
          height: 1,
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
        Expanded(
          child: ListView(
            children: [
              ...members.asMap().entries.map((e) {
                final i = e.key;
                final m = e.value as Map<String, dynamic>;
                final u = m['user'] as Map<String, dynamic>? ?? {};
                final userId = (u['id'] as num?)?.toInt() ?? 0;
                final name = u['display_name'] as String? ??
                    l10n.userFallback('$userId');
                final role = m['role'] as String? ?? 'member';
                final isAdmin = role == 'admin' || role == 'owner';
                final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
                final myId = _myUserId;
                final canModerate = _isModerator &&
                    myId != null &&
                    userId != myId &&
                    role != 'owner';

                return Column(
                  children: [
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 68,
                        color: isDark
                            ? AppColors.dividerDark
                            : AppColors.dividerLight,
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 8, right: 4),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isAdmin
                                      ? [
                                          AppColors.primaryDeep,
                                          AppColors.primary,
                                        ]
                                      : [
                                          AppColors.primary,
                                          AppColors.primary
                                              .withValues(alpha: 0.7),
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.onBackgroundDark
                                          : AppColors.onBackgroundLight,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    role,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.subtitleLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isAdmin)
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                role,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          if (canModerate)
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert_rounded,
                                color: isDark
                                    ? AppColors.onBackgroundDark
                                    : AppColors.onBackgroundLight,
                              ),
                              onSelected: (v) {
                                if (v == 'remove') {
                                  _confirmRemoveMember(l10n, repo, name, userId);
                                } else if (v == 'ban') {
                                  _confirmBanMember(l10n, repo, name, userId);
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text(l10n.groupActionRemoveMember),
                                ),
                                PopupMenuItem(
                                  value: 'ban',
                                  child: Text(l10n.groupActionBanMember),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
              if (_isModerator && _bans.isNotEmpty) ...[
                Divider(
                  height: 24,
                  thickness: 1,
                  color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Text(
                    l10n.groupBannedSectionTitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.onBackgroundDark
                          : AppColors.onBackgroundLight,
                    ),
                  ),
                ),
                ..._bans.map((row) {
                  final u = row['user'] as Map<String, dynamic>? ?? {};
                  final uid = (u['id'] as num?)?.toInt() ?? 0;
                  final bname = u['display_name'] as String? ??
                      l10n.userFallback('$uid');
                  return ListTile(
                    title: Text(
                      bname,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.onBackgroundDark
                            : AppColors.onBackgroundLight,
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () => _unban(l10n, repo, uid),
                      child: Text(l10n.groupActionUnban),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Group header ─────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.memberCountLabel,
    required this.isDark,
  });
  final String title;
  final String memberCountLabel;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final initials = title.isNotEmpty ? title[0].toUpperCase() : 'G';
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryDeep, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.onBackgroundDark
                        : AppColors.onBackgroundLight,
                  ),
                ),
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
                      memberCountLabel,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.subtitleLight,
                      ),
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
}
