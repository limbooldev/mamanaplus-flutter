import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mamana_plus/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/ui/ui.dart';
import '../../data/chat_repository.dart';

class GroupCreatePage extends StatefulWidget {
  const GroupCreatePage({super.key});

  @override
  State<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  final _title = TextEditingController();
  final _members = TextEditingController()..text = '';
  var _creating = false;

  @override
  void dispose() {
    _title.dispose();
    _members.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newGroupTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GroupIconPreview(
              titleController: _title,
              isDark: isDark,
            ),
            const SizedBox(height: 24),
            _FieldLabel(text: l10n.labelGroupTitle),
            const SizedBox(height: 8),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                hintText: 'e.g. Book Club',
                prefixIcon: const Icon(
                  Icons.group_outlined,
                  color: AppColors.subtitleLight,
                ),
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            _FieldLabel(text: l10n.labelMemberIds),
            const SizedBox(height: 8),
            TextField(
              controller: _members,
              decoration: InputDecoration(
                hintText: l10n.labelMemberIds,
                prefixIcon: const Icon(
                  Icons.person_add_alt_outlined,
                  color: AppColors.subtitleLight,
                ),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 8),
            Text(
              'Separate multiple IDs with commas (e.g. 2, 5, 12)',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.subtitleLight,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _creating ? null : () => _create(context, l10n),
              child: _creating
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.buttonCreate),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, AppLocalizations l10n) async {
    final name = _title.text.trim();
    if (name.isEmpty) return;

    setState(() => _creating = true);
    try {
      final ids = _members.text
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();
      await context.read<ChatRepository>().createGroup(name, ids);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}

// ─── Group icon preview ───────────────────────────────────────────────────────

class _GroupIconPreview extends StatefulWidget {
  const _GroupIconPreview({
    required this.titleController,
    required this.isDark,
  });
  final TextEditingController titleController;
  final bool isDark;

  @override
  State<_GroupIconPreview> createState() => _GroupIconPreviewState();
}

class _GroupIconPreviewState extends State<_GroupIconPreview> {
  @override
  void initState() {
    super.initState();
    widget.titleController.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.titleController.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final text = widget.titleController.text;
    final initials = text.isNotEmpty ? text[0].toUpperCase() : 'G';

    return Center(
      child: Container(
        width: 80,
        height: 80,
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
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Field label ──────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.onBackgroundDark : AppColors.onBackgroundLight,
      ),
    );
  }
}
