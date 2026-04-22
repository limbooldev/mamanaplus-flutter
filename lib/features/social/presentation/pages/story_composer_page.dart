import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';

import '../../data/social_repository.dart';

/// Pick an image, upload via presign pipeline, attach to the user's story.
class StoryComposerPage extends StatefulWidget {
  const StoryComposerPage({super.key});

  @override
  State<StoryComposerPage> createState() => _StoryComposerPageState();
}

class _StoryComposerPageState extends State<StoryComposerPage> {
  bool _busy = false;
  String? _error;

  Future<void> _pickAndUpload(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = context.read<SocialRepository>();
    try {
      final pick = await ImagePicker().pickImage(source: source, imageQuality: 88);
      if (pick == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final bytes = await File(pick.path).readAsBytes();
      final mime = lookupMimeType(pick.path) ?? 'image/jpeg';
      final key = await repo.uploadSocialMediaBytes(bytes, mime);
      await repo.addStoryMedia(key);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final max = repo.parseStoryMediaLimitError(e);
      setState(() {
        _busy = false;
        _error = max != null
            ? 'Story is full ($max slides max). View or delete slides to add more.'
            : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add to story')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _busy
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  FilledButton.icon(
                    onPressed: () => _pickAndUpload(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Camera'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _pickAndUpload(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ],
              ),
      ),
    );
  }
}
