import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mamana_plus/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../../../../shared/ui/ui.dart';

class _ChatImageEditorOutcome {
  String? outputPath;
}

/// Full-screen image editor after gallery/camera pick. Returns a temp JPEG path,
/// or `null` if the user closes without exporting.
Future<String?> openChatImageEditor(BuildContext context, String pickedPath) async {
  final l10n = AppLocalizations.of(context)!;
  final outcome = _ChatImageEditorOutcome();
  final baseTheme = Theme.of(context);
  final configs = ProImageEditorConfigs(
    theme: baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(primary: AppColors.primary),
    ),
    i18n: I18n(
      cancel: l10n.buttonCancel,
      undo: l10n.imageEditorUndo,
      redo: l10n.imageEditorRedo,
      done: l10n.imageEditorDone,
      doneLoadingMsg: l10n.imageEditorApplyingChanges,
    ),
  );

  return Navigator.of(context).push<String?>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) {
        return ProImageEditor.file(
          File(pickedPath),
          configs: configs,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (bytes) async {
              outcome.outputPath = null;
              if (bytes.isEmpty) return;
              final dir = await getTemporaryDirectory();
              final out = p.join(dir.path, 'chat_edit_${DateTime.now().millisecondsSinceEpoch}.jpg');
              await File(out).writeAsBytes(bytes);
              outcome.outputPath = out;
            },
            onCloseEditor: (_) {
              if (ctx.mounted) {
                Navigator.of(ctx).pop(outcome.outputPath);
              }
            },
          ),
        );
      },
    ),
  );
}
