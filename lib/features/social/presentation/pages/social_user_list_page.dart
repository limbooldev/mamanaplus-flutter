import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/social_repository.dart';
import '../../domain/social_models.dart';

typedef SocialUserListLoader = Future<List<SocialUserBrief>> Function(
  SocialRepository repo,
  int page,
);

/// User list (followers, following, discovery, hidden users) — first page.
class SocialUserListPage extends StatefulWidget {
  const SocialUserListPage({
    super.key,
    required this.title,
    required this.load,
  });

  final String title;
  final SocialUserListLoader load;

  @override
  State<SocialUserListPage> createState() => _SocialUserListPageState();
}

class _SocialUserListPageState extends State<SocialUserListPage> {
  List<SocialUserBrief> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repo = context.read<SocialRepository>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.load(repo, 1);
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  const Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 48),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                      Center(
                        child: FilledButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(child: Text('No users')),
                        ],
                      )
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final u = _items[i];
                          return ListTile(
                            title: Text(
                              u.displayName,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text('User #${u.id}'),
                          );
                        },
                      ),
      ),
    );
  }
}
