import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../data/social_repository.dart';

/// Pick an image, upload via presign pipeline, attach to the user's story.
Future<bool> pickAndUploadStoryMedia(
  SocialRepository repo,
  ImageSource source,
) async {
  final pick = await ImagePicker().pickImage(source: source, imageQuality: 88);
  if (pick == null) return false;
  final bytes = await File(pick.path).readAsBytes();
  final mime = lookupMimeType(pick.path) ?? 'image/jpeg';
  final key = await repo.uploadSocialMediaBytes(bytes, mime);
  await repo.addStoryMedia(key);
  return true;
}

String? storyUploadErrorMessage(SocialRepository repo, Object error) {
  final max = repo.parseStoryMediaLimitError(error);
  if (max != null) {
    return 'Story is full ($max slides max). View or delete slides to add more.';
  }
  return error.toString();
}

/// Camera / gallery bottom sheet for adding a story slide. Returns `true` when added.
Future<bool> showAddStorySheet(
  BuildContext context,
  SocialRepository repo,
) async {
  final added = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => _AddStorySheetBody(repo: repo),
  );
  return added == true;
}

class _AddStorySheetBody extends StatefulWidget {
  const _AddStorySheetBody({required this.repo});

  final SocialRepository repo;

  @override
  State<_AddStorySheetBody> createState() => _AddStorySheetBodyState();
}

class _AddStorySheetBodyState extends State<_AddStorySheetBody> {
  bool _busy = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final added = await pickAndUploadStoryMedia(widget.repo, source);
      if (!mounted) return;
      if (added) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _busy = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = storyUploadErrorMessage(widget.repo, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: _busy
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add to story',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Camera'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ],
              ),
      ),
    );
  }
}

/// View existing story or add another slide.
Future<void> showViewOrAddStorySheet({
  required BuildContext context,
  required SocialRepository repo,
  required VoidCallback onView,
  required Future<void> Function() onAdd,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your story',
              style: Theme.of(ctx).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                onView();
              },
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('View story'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await onAdd();
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add to story'),
            ),
          ],
        ),
      ),
    ),
  );
}
