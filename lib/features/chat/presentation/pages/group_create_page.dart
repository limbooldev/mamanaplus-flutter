import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mamana_plus/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../data/chat_repository.dart';

class GroupCreatePage extends StatefulWidget {
  const GroupCreatePage({super.key});

  @override
  State<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  final _title = TextEditingController();
  final _members = TextEditingController()..text = '';

  @override
  void dispose() {
    _title.dispose();
    _members.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.newGroupTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              decoration: InputDecoration(labelText: l10n.labelGroupTitle),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _members,
              decoration: InputDecoration(labelText: l10n.labelMemberIds),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                final ids = _members.text
                    .split(',')
                    .map((s) => int.tryParse(s.trim()))
                    .whereType<int>()
                    .toList();
                await context.read<ChatRepository>().createGroup(_title.text.trim(), ids);
                if (context.mounted) context.pop();
              },
              child: Text(l10n.buttonCreate),
            ),
          ],
        ),
      ),
    );
  }
}
