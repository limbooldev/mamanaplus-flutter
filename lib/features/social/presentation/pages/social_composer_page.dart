import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/social_repository.dart';

/// Create a social post (image or video). Paste **media_url** after uploading
/// via your pipeline, or use a public test URL in development.
class SocialComposerPage extends StatefulWidget {
  const SocialComposerPage({super.key, this.existingPostId});

  /// When set, performs PUT update instead of POST create.
  final int? existingPostId;

  @override
  State<SocialComposerPage> createState() => _SocialComposerPageState();
}

class _SocialComposerPageState extends State<SocialComposerPage> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _media = TextEditingController();
  final _thumb = TextEditingController();
  String _type = 'image';
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _media.dispose();
    _thumb.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingPostId != null ? 'Edit post' : 'New post'),
        actions: [
          if (_busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _submit,
              child: const Text('Publish'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Post type',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'image', label: Text('Image')),
              ButtonSegment(value: 'video', label: Text('Video')),
            ],
            selected: {_type},
            onSelectionChanged: (Set<String> s) =>
                setState(() => _type = s.first),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Caption / description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _media,
            decoration: const InputDecoration(
              labelText: 'Media URL (https://…)',
              helperText: 'Required for image/video posts in v1',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _thumb,
            decoration: const InputDecoration(
              labelText: 'Thumbnail URL (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final repo = context.read<SocialRepository>();
    final media = _media.text.trim();
    if (media.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a media URL')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      if (widget.existingPostId != null) {
        await repo.updatePost(
          widget.existingPostId!,
          title: _title.text.trim(),
          content: _content.text.trim(),
          postType: _type,
          mediaUrl: media,
          thumbnailUrl: _thumb.text.trim().isEmpty ? null : _thumb.text.trim(),
        );
      } else {
        await repo.createPost(
          title: _title.text.trim(),
          content: _content.text.trim(),
          postType: _type,
          mediaUrl: media,
          thumbnailUrl: _thumb.text.trim().isEmpty ? null : _thumb.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
