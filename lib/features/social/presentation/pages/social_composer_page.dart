import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';

import '../../data/social_repository.dart';
import '../widgets/social_media_widgets.dart';

/// Create or edit a social post: pick **one** image or video (type inferred), caption only.
class SocialComposerPage extends StatefulWidget {
  const SocialComposerPage({super.key, this.existingPostId});

  /// When set, performs PUT update instead of POST create.
  final int? existingPostId;

  @override
  State<SocialComposerPage> createState() => _SocialComposerPageState();
}

class _SocialComposerPageState extends State<SocialComposerPage> {
  final _caption = TextEditingController();
  XFile? _picked;
  String? _pickedMime;
  String _postType = 'image';
  String? _existingMediaKey;
  bool _busy = false;
  bool _loadingPost = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingPostId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _loadingPost = true);
    try {
      final p = await context.read<SocialRepository>().getPost(
            widget.existingPostId!,
          );
      if (!mounted) return;
      setState(() {
        _caption.text = p.content;
        _existingMediaKey = p.mediaUrl;
        _postType = p.postType;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPost = false);
    }
  }

  Future<void> _pickMedia() async {
    final x = await ImagePicker().pickMedia();
    if (x == null) return;
    final mime = lookupMimeType(x.path) ?? 'application/octet-stream';
    final isVideo =
        mime.startsWith('video/') || mime == 'application/mp4';
    if (!mounted) return;
    setState(() {
      _picked = x;
      _pickedMime = mime;
      _postType = isVideo ? 'video' : 'image';
    });
  }

  void _clearPick() {
    setState(() {
      _picked = null;
      _pickedMime = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingPostId != null ? 'Edit post' : 'New post'),
        actions: [
          if (_busy || _loadingPost)
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
          OutlinedButton.icon(
            onPressed: _busy || _loadingPost ? null : _pickMedia,
            icon: const Icon(Icons.perm_media_outlined),
            label: const Text('Choose photo or video'),
          ),
          if (_picked != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_postType == 'video' ? 'Video' : 'Image'} · ${_picked!.name}',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: _clearPick,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ],
          if (widget.existingPostId != null &&
              _picked == null &&
              (_existingMediaKey != null && _existingMediaKey!.isNotEmpty)) ...[
            const SizedBox(height: 12),
            Text(
              'Current media',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: _postType == 'video'
                    ? SocialPostVideo(mediaRef: _existingMediaKey)
                    : SocialPostImage(
                        mediaRef: _existingMediaKey,
                        borderRadius: BorderRadius.zero,
                      ),
              ),
            ),
          ],
          if (_picked != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: _postType == 'video'
                    ? _LocalFileVideoPreview(path: _picked!.path)
                    : Image.file(
                        File(_picked!.path),
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _caption,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Caption',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final repo = context.read<SocialRepository>();
    String? mediaUrl;
    if (_picked != null && _pickedMime != null) {
      setState(() => _busy = true);
      try {
        final bytes = await File(_picked!.path).readAsBytes();
        mediaUrl = await repo.uploadSocialMediaBytes(
          bytes,
          _pickedMime!,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } else {
      mediaUrl = _existingMediaKey;
    }
    if (mediaUrl == null || mediaUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a photo or video')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      if (widget.existingPostId != null) {
        await repo.updatePost(
          widget.existingPostId!,
          title: '',
          content: _caption.text.trim(),
          postType: _postType,
          mediaUrl: mediaUrl,
        );
      } else {
        await repo.createPost(
          title: '',
          content: _caption.text.trim(),
          postType: _postType,
          mediaUrl: mediaUrl,
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

class _LocalFileVideoPreview extends StatefulWidget {
  const _LocalFileVideoPreview({required this.path});

  final String path;

  @override
  State<_LocalFileVideoPreview> createState() => _LocalFileVideoPreviewState();
}

class _LocalFileVideoPreviewState extends State<_LocalFileVideoPreview> {
  VideoPlayerController? _c;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final file = File(widget.path);
    if (!await file.exists() || !mounted) return;
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() => _c = controller);
    } catch (_) {
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null || !c.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black87,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return AspectRatio(
      aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(c),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() {
                c.value.isPlaying ? c.pause() : c.play();
              }),
              child: AnimatedOpacity(
                opacity: c.value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: Colors.black26,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.play_arrow,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
