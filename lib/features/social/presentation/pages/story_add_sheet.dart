import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/media/media_upload_processor.dart';
import '../../data/social_repository.dart';
import 'story_image_preview.dart';
import 'story_video_preview.dart';

enum _StoryPickKind {
  imageCamera,
  imageGallery,
  videoCamera,
  videoGallery,
}

String? storyUploadErrorMessage(SocialRepository repo, Object error) {
  if (error is VideoDurationExceededException) {
    return error.toString();
  }
  final max = repo.parseStoryMediaLimitError(error);
  if (max != null) {
    return 'Story is full ($max slides max). View or delete slides to add more.';
  }
  return error.toString();
}

Future<_StoryPickKind?> _pickStorySource(BuildContext context) {
  return showModalBottomSheet<_StoryPickKind>(
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
              onPressed: () => Navigator.pop(ctx, _StoryPickKind.imageCamera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Camera'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, _StoryPickKind.imageGallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery photo'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, _StoryPickKind.videoCamera),
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Record video'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, _StoryPickKind.videoGallery),
              icon: const Icon(Icons.video_library_outlined),
              label: const Text('Gallery video'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<bool> _uploadStoryPick(
  BuildContext context,
  SocialRepository repo,
  _StoryPickKind kind,
) async {
  final picker = ImagePicker();
  String? path;

  switch (kind) {
    case _StoryPickKind.imageCamera:
    case _StoryPickKind.imageGallery:
      final source = kind == _StoryPickKind.imageCamera
          ? ImageSource.camera
          : ImageSource.gallery;
      final pick = await picker.pickImage(source: source, imageQuality: 88);
      if (pick == null || !context.mounted) return false;
      path = await openStoryImagePreview(context, pick.path);
    case _StoryPickKind.videoCamera:
    case _StoryPickKind.videoGallery:
      final source = kind == _StoryPickKind.videoCamera
          ? ImageSource.camera
          : ImageSource.gallery;
      final pick = await picker.pickVideo(
        source: source,
        maxDuration: const Duration(
          seconds: MediaUploadLimits.maxStoryVideoDurationSec,
        ),
      );
      if (pick == null || !context.mounted) return false;
      path = await openStoryVideoPreview(context, pick.path);
  }

  if (path == null || !context.mounted) return false;

  try {
    if (!context.mounted) return false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    if (kind == _StoryPickKind.videoCamera ||
        kind == _StoryPickKind.videoGallery) {
      await repo.uploadStoryVideoFromPath(path);
    } else {
      await repo.uploadStoryImageFromPath(path);
    }
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

/// Pick, preview/edit, upload a story slide. Returns `true` when added.
Future<bool> showAddStorySheet(
  BuildContext context,
  SocialRepository repo,
) async {
  final kind = await _pickStorySource(context);
  if (kind == null || !context.mounted) return false;
  return _uploadStoryPick(context, repo, kind);
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
