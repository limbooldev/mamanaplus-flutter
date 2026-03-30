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
  Object? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<ChatRepository>();
      final d = await repo.getGroup(widget.conversationId);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupAppBarTitle)),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupHeader(title: title, memberCount: members.length, isDark: isDark),
        Divider(
          height: 1,
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
        Expanded(
          child: ListView.separated(
            itemCount: members.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 68,
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            ),
            itemBuilder: (context, i) {
              final m = members[i] as Map<String, dynamic>;
              final u = m['user'] as Map<String, dynamic>? ?? {};
              final name = u['display_name'] as String? ??
                  l10n.userFallback('${u['id']}');
              final role = m['role'] as String? ?? 'member';
              final isAdmin = role == 'admin' || role == 'owner';
              final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isAdmin
                              ? [
                                  const Color(0xFF7B5FFF),
                                  AppColors.primary,
                                ]
                              : [
                                  AppColors.primary,
                                  AppColors.primary.withValues(alpha: 0.7),
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
                    const SizedBox(width: 12),
                    Expanded(
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
                    if (isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
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
                  ],
                ),
              );
            },
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
    required this.memberCount,
    required this.isDark,
  });
  final String title;
  final int memberCount;
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
                colors: [Color(0xFF7B5FFF), AppColors.primary],
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
                      '$memberCount members',
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
