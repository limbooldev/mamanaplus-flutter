import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../data/social_repository.dart';
import 'story_image_preview.dart';

/// Upload a local image file to the user's story.
Future<void> uploadStoryImageFromPath(SocialRepository repo, String path) async {
  final bytes = await File(path).readAsBytes();
  final mime = lookupMimeType(path) ?? 'image/jpeg';
  final key = await repo.uploadSocialMediaBytes(bytes, mime);
  await repo.addStoryMedia(key);
}

String? storyUploadErrorMessage(SocialRepository repo, Object error) {
  final max = repo.parseStoryMediaLimitError(error);
  if (max != null) {
    return 'Story is full ($max slides max). View or delete slides to add more.';
  }
  return error.toString();
}

Future<ImageSource?> _pickStorySource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
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
              'Add to story',
              style: Theme.of(ctx).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Camera'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Pick, preview/edit, upload a story slide. Returns `true` when added.
Future<bool> showAddStorySheet(
  BuildContext context,
  SocialRepository repo,
) async {
  final source = await _pickStorySource(context);
  if (source == null || !context.mounted) return false;

  final pick = await ImagePicker().pickImage(source: source, imageQuality: 88);
  if (pick == null || !context.mounted) return false;

  final path = await openStoryImagePreview(context, pick.path);
  if (path == null || !context.mounted) return false;

  try {
    if (!context.mounted) return false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    await uploadStoryImageFromPath(repo, path);
    if (context.mounted) Navigator.of(context).pop();
    return true;
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      final message = storyUploadErrorMessage(repo, e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message ?? 'Could not add story')),
      );
    }
    return false;
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
