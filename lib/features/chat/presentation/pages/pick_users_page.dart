import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mamana_plus/l10n/app_localizations.dart';

import '../../../../router/app_routes.dart';
import '../../../../shared/ui/ui.dart';
import '../../data/chat_repository.dart';
import '../utils/inbox_peer_users.dart';

class PickUsersPage extends StatefulWidget {
  const PickUsersPage({super.key, required this.extra});

  final PickUsersRouteExtra extra;

  @override
  State<PickUsersPage> createState() => _PickUsersPageState();
}

class _PickUsersPageState extends State<PickUsersPage> {
  final _search = TextEditingController();
  Timer? _debounce;

  List<InboxPeerUser> _localPeers = [];
  String _query = '';

  List<Map<String, dynamic>> _remoteItems = [];
  bool _remoteLoading = false;
  String? _remoteError;

  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.extra.initialSelectedIds};
    _reloadLocal();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reloadLocal() async {
    final repo = context.read<ChatRepository>();
    final conv = await repo.loadConversationsLocal();
    final exclude = widget.extra.excludeUserIds.toSet();
    if (!mounted) return;
    setState(() {
      _localPeers = dmPeersFromConversations(conv, excludeUserIds: exclude);
    });
  }

  void _onQueryChanged(String _) {
    final q = _search.text;
    setState(() => _query = q);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _runRemoteSearch);
  }

  Future<void> _runRemoteSearch() async {
    final q = _search.text.trim();
    if (q.length < 2) {
      if (!mounted) return;
      setState(() {
        _remoteItems = [];
        _remoteLoading = false;
        _remoteError = null;
      });
      return;
    }

    setState(() {
      _remoteLoading = true;
      _remoteError = null;
    });

    try {
      final repo = context.read<ChatRepository>();
      final raw = await repo.searchUsersDirectory(q);
      final exclude = widget.extra.excludeUserIds.toSet();
      final filtered = <Map<String, dynamic>>[];
      for (final m in raw) {
        final id = (m['id'] as num?)?.toInt();
        if (id == null || exclude.contains(id)) continue;
        filtered.add(m);
      }
      if (!mounted) return;
      setState(() {
        _remoteItems = filtered;
        _remoteLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      String? msg;
      if (e is DioException && e.response?.statusCode == 400) {
        msg = null;
      } else {
        msg = e.toString();
      }
      setState(() {
        _remoteItems = [];
        _remoteLoading = false;
        _remoteError = msg;
      });
    }
  }

  List<InboxPeerUser> get _localFiltered =>
      filterPeersByQuery(_localPeers, _query);

  List<Map<String, dynamic>> get _remoteDeduped {
    final localIds = _localFiltered.map((e) => e.id).toSet();
    final out = <Map<String, dynamic>>[];
    for (final m in _remoteItems) {
      final id = (m['id'] as num?)?.toInt();
      if (id == null || localIds.contains(id)) continue;
      out.add(m);
    }
    return out;
  }

  String _displayNameForRemote(Map<String, dynamic> m, AppLocalizations l10n) {
    final name = (m['display_name'] as String?)?.trim() ?? '';
    if (name.isEmpty) {
      final id = (m['id'] as num?)?.toInt();
      if (id != null) return l10n.userFallback('$id');
    }
    return name.isEmpty ? l10n.chatFallback : name;
  }

  String _displayNameForLocal(InboxPeerUser p, AppLocalizations l10n) {
    if (p.displayName.isEmpty) return l10n.userFallback('${p.id}');
    return p.displayName;
  }

  void _toggleSelected(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMulti = widget.extra.mode == PickUsersMode.multi;
    final title = isMulti ? l10n.pickUsersTitleMulti : l10n.pickUsersTitleSingle;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (isMulti)
            TextButton(
              onPressed: () => context.pop(List<int>.from(_selected)),
              child: Text(l10n.pickUsersDone),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: l10n.pickUsersSearchHint,
                prefixIcon: const Icon(Icons.search, color: AppColors.subtitleLight),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
            ),
          ),
          if (_remoteError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.pickUsersSearchFailed,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (_localFiltered.isNotEmpty) ...[
                  _SectionHeader(text: l10n.pickUsersSectionFromChats),
                  ..._localFiltered.map((p) => _UserRow(
                        title: _displayNameForLocal(p, l10n),
                        subtitle: '${p.id}',
                        isMulti: isMulti,
                        selected: _selected.contains(p.id),
                        onTap: () {
                          if (isMulti) {
                            _toggleSelected(p.id);
                          } else {
                            context.pop(p.id);
                          }
                        },
                      )),
                ] else if (_localPeers.isEmpty && _query.trim().isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(
                      l10n.pickUsersNoDirectChats,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.subtitleLight,
                      ),
                    ),
                  ),
                if (_query.trim().isNotEmpty && _query.trim().length < 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(
                      l10n.pickUsersMinCharsForDirectory,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.subtitleLight,
                      ),
                    ),
                  ),
                if (_query.trim().length >= 2) ...[
                  _SectionHeader(text: l10n.pickUsersSectionEveryone),
                  if (_remoteLoading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  else if (_remoteDeduped.isEmpty && _remoteError == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Text(
                        l10n.pickUsersEmptyRemote,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.subtitleLight,
                        ),
                      ),
                    )
                  else
                    ..._remoteDeduped.map((m) {
                      final id = (m['id'] as num).toInt();
                      return _UserRow(
                        title: _displayNameForRemote(m, l10n),
                        subtitle: '$id',
                        isMulti: isMulti,
                        selected: _selected.contains(id),
                        onTap: () {
                          if (isMulti) {
                            _toggleSelected(id);
                          } else {
                            context.pop(id);
                          }
                        },
                      );
                    }),
                ],
                if (_query.trim().isNotEmpty &&
                    _localFiltered.isEmpty &&
                    _query.trim().length >= 2 &&
                    !_remoteLoading &&
                    _remoteDeduped.isEmpty &&
                    _remoteError == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Text(
                      l10n.pickUsersEmpty,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.subtitleLight,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: isDark ? AppColors.subtitleDark : AppColors.subtitleLight,
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.title,
    required this.subtitle,
    required this.isMulti,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isMulti;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = title.isNotEmpty ? title[0].toUpperCase() : '?';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: Text(
                initials,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.onBackgroundDark : AppColors.onBackgroundLight,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.subtitleLight,
                    ),
                  ),
                ],
              ),
            ),
            if (isMulti)
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? AppColors.primary : AppColors.subtitleLight,
              ),
          ],
        ),
      ),
    );
  }
}
