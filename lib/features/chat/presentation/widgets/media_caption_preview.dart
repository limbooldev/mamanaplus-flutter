import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mamana_plus/l10n/app_localizations.dart';
import 'package:video_player/video_player.dart';

import '../../../../shared/ui/ui.dart';
import 'chat_image_editor_flow.dart';
import 'chat_video_editor_flow.dart';

/// Result of [openMediaCaptionPreview]: the picked file path and an optional caption.
typedef MediaCaptionPreviewResult = ({String path, String? caption});

/// Full-screen preview after picking image/video. User can add a caption then send.
Future<MediaCaptionPreviewResult?> openMediaCaptionPreview(
  BuildContext context, {
  required String path,
  required String kind,
}) {
  return Navigator.of(context).push<MediaCaptionPreviewResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => _MediaCaptionPreviewPage(
        initialPath: path,
        kind: kind,
      ),
    ),
  );
}

class _MediaCaptionPreviewPage extends StatefulWidget {
  const _MediaCaptionPreviewPage({
    required this.initialPath,
    required this.kind,
  });

  final String initialPath;
  final String kind;

  @override
  State<_MediaCaptionPreviewPage> createState() =>
      _MediaCaptionPreviewPageState();
}

class _MediaCaptionPreviewPageState extends State<_MediaCaptionPreviewPage> {
  late String _path;
  final _captionController = TextEditingController();
  final _captionFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
  }

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocus.dispose();
    super.dispose();
  }

  bool get _isVideo => widget.kind == 'video';

  Future<void> _openEditor() async {
    if (!mounted) return;
    final ctx = context;
    String? edited;
    if (_isVideo) {
      // ignore: use_build_context_synchronously
      edited = await openChatVideoEditor(ctx, _path);
    } else {
      // ignore: use_build_context_synchronously
      edited = await openChatImageEditor(ctx, _path);
    }
    if (edited != null && mounted) {
      setState(() => _path = edited!);
    }
  }

  void _send() {
    final caption = _captionController.text.trim();
    Navigator.of(context).pop((
      path: _path,
      caption: caption.isEmpty ? null : caption,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
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
            onPressed: _openEditor,
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
          Center(
            child: _isVideo
                ? _LocalVideoPreview(path: _path)
                : InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.file(
                      File(_path),
                      fit: BoxFit.contain,
                    ),
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _captionController,
                        builder: (context, value, _) {
                          return TextField(
                            controller: _captionController,
                            focusNode: _captionFocus,
                            maxLength: 1024,
                            minLines: 1,
                            maxLines: 4,
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.start,
                            textDirection: textDirectionFor(value.text),
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: l10n.mediaCaptionHint,
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                              counterStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: AppColors.primary,
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        tooltip: l10n.mediaPreviewSend,
                        onPressed: _send,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalVideoPreview extends StatefulWidget {
  const _LocalVideoPreview({required this.path});

  final String path;

  @override
  State<_LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<_LocalVideoPreview> {
  VideoPlayerController? _controller;

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
      setState(() => _controller = controller);
    } catch (_) {
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
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
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
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
    );
  }
}
