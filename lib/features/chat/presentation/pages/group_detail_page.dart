import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Group')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('$_error'))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final conv = _data?['conversation'] as Map<String, dynamic>?;
    final members = _data?['members'] as List<dynamic>? ?? [];
    final title = conv?['title'] as String? ?? 'Group #${widget.conversationId}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, i) {
              final m = members[i] as Map<String, dynamic>;
              final u = m['user'] as Map<String, dynamic>? ?? {};
              final name = u['display_name'] as String? ?? 'User ${u['id']}';
              final role = m['role'] as String? ?? 'member';
              return ListTile(title: Text(name), subtitle: Text(role));
            },
          ),
        ),
      ],
    );
  }
}
