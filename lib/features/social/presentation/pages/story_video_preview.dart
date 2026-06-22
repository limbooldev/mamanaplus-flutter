import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mamana_plus/l10n/app_localizations.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/media/media_upload_processor.dart';
import '../../../chat/presentation/widgets/chat_video_editor_flow.dart';

/// Full-screen preview after picking a story video. User can edit then share.
Future<String?> openStoryVideoPreview(BuildContext context, String path) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => _StoryVideoPreviewPage(initialPath: path),
    ),
  );
}

class _StoryVideoPreviewPage extends StatefulWidget {
  const _StoryVideoPreviewPage({required this.initialPath});

  final String initialPath;

  @override
  State<_StoryVideoPreviewPage> createState() => _StoryVideoPreviewPageState();
}

class _StoryVideoPreviewPageState extends State<_StoryVideoPreviewPage> {
  late String _path;
  VideoPlayerController? _controller;
  Object? _error;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
    _init();
  }

  Future<void> _init() async {
    try {
      await MediaUploadProcessor.readVideoDurationMs(
        _path,
        maxDurationMs: MediaUploadLimits.maxStoryVideoDurationMs,
      );
      final c = VideoPlayerController.file(File(_path));
      await c.initialize();
      c.setLooping(true);
      await c.play();
      c.addListener(() {
        if (mounted) setState(() {});
      });
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _checking = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _controller = null;
          _checking = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _openEditor() async {
    if (!mounted) return;
    final edited = await openChatVideoEditor(context, _path);
    if (edited == null || !mounted) return;

    await _controller?.dispose();
    setState(() {
      _path = edited;
      _controller = null;
      _checking = true;
      _error = null;
    });
    await _init();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _share() {
    if (_error != null) return;
    Navigator.of(context).pop(_path);
  }

  void _togglePlayback() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
      } else {
        c.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.mediaPreviewClose,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: _checking ? null : _openEditor,
            icon: const Icon(Icons.edit, color: Colors.white),
            label: Text(
              l10n.mediaPreviewEdit,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_checking)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error.toString(),
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            _buildVideo(),
          if (!_checking && _error == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: FilledButton(
                    onPressed: _share,
                    child: const Text('Add to story'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideo() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return GestureDetector(
      onTap: _togglePlayback,
      child: Center(
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio == 0 ? 9 / 16 : c.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(c),
              AnimatedOpacity(
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
            ],
          ),
        ),
      ),
    );
  }
}
