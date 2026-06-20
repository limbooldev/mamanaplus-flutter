import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mamana_plus/l10n/app_localizations.dart';

import '../../../chat/presentation/widgets/chat_image_editor_flow.dart';

/// Full-screen preview after picking a story image. User can edit then share.
Future<String?> openStoryImagePreview(BuildContext context, String path) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => _StoryImagePreviewPage(initialPath: path),
    ),
  );
}

class _StoryImagePreviewPage extends StatefulWidget {
  const _StoryImagePreviewPage({required this.initialPath});

  final String initialPath;

  @override
  State<_StoryImagePreviewPage> createState() => _StoryImagePreviewPageState();
}

class _StoryImagePreviewPageState extends State<_StoryImagePreviewPage> {
  late String _path;

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
  }

  Future<void> _openEditor() async {
    if (!mounted) return;
    final edited = await openChatImageEditor(context, _path);
    if (edited != null && mounted) {
      setState(() => _path = edited);
    }
  }

  void _share() {
    Navigator.of(context).pop(_path);
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
            child: InteractiveViewer(
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
}
