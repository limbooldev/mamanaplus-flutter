import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/social_models.dart';

class SocialPostCommentTile extends StatelessWidget {
  const SocialPostCommentTile({
    super.key,
    required this.comment,
    required this.onReport,
  });

  final SocialComment comment;
  final Future<void> Function(int commentId) onReport;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        comment.userName,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      subtitle: Text(comment.body),
      trailing: IconButton(
        icon: const Icon(Icons.flag_outlined, size: 20),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Report comment?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Report'),
                ),
              ],
            ),
          );
          if (ok == true && context.mounted) {
            await onReport(comment.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reported')),
              );
            }
          }
        },
      ),
    );
  }
}

class SocialPostCommentComposer extends StatefulWidget {
  const SocialPostCommentComposer({super.key, required this.onSubmit});

  final Future<void> Function(String body) onSubmit;

  @override
  State<SocialPostCommentComposer> createState() =>
      _SocialPostCommentComposerState();
}

class _SocialPostCommentComposerState extends State<SocialPostCommentComposer> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _ctrl,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Write a comment…',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    final t = _ctrl.text.trim();
                    if (t.isEmpty) return;
                    setState(() => _busy = true);
                    try {
                      await widget.onSubmit(t);
                      if (mounted) _ctrl.clear();
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send'),
          ),
        ),
      ],
    );
  }
}
