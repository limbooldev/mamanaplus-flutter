import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mamana_plus/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pv;
import 'package:video_player/video_player.dart';

import '../../../../shared/ui/ui.dart';

const _thumbnailCount = 7;

const _videoSubTools = <SubEditorMode>[
  SubEditorMode.paint,
  SubEditorMode.text,
  SubEditorMode.cropRotate,
  SubEditorMode.tune,
  SubEditorMode.filter,
  SubEditorMode.blur,
  SubEditorMode.emoji,
];

/// Full-screen video editor after gallery pick. Returns a temp MP4 path, or
/// `null` if the user closes without exporting.
Future<String?> openChatVideoEditor(BuildContext context, String pickedPath) {
  final l10n = AppLocalizations.of(context)!;
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
    imageGeneration: ImageGenerationConfigs(
      captureImageByteFormat: ImageByteFormat.rawStraightRgba,
    ),
    mainEditor: MainEditorConfigs(
      tools: _videoSubTools,
      widgets: MainEditorWidgets(
        removeLayerArea:
            (removeAreaKey, editor, rebuildStream, isLayerBeingTransformed) =>
                VideoEditorRemoveArea(
                  removeAreaKey: removeAreaKey,
                  editor: editor,
                  rebuildStream: rebuildStream,
                  isLayerBeingTransformed: isLayerBeingTransformed,
                ),
      ),
    ),
    paintEditor: const PaintEditorConfigs(
      tools: [
        PaintMode.freeStyle,
        PaintMode.arrow,
        PaintMode.line,
        PaintMode.rect,
        PaintMode.circle,
        PaintMode.dashLine,
        PaintMode.polygon,
        PaintMode.eraser,
      ],
    ),
    videoEditor: const VideoEditorConfigs(
      initialMuted: false,
      initialPlay: false,
      isAudioSupported: true,
      minTrimDuration: Duration(seconds: 1),
      playTimeSmoothingDuration: Duration(milliseconds: 600),
    ),
  );
  return Navigator.of(context).push<String?>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ChatVideoEditorPage(
        pickedPath: pickedPath,
        l10n: l10n,
        configs: configs,
      ),
    ),
  );
}

class _ChatVideoEditorPage extends StatefulWidget {
  const _ChatVideoEditorPage({
    required this.pickedPath,
    required this.l10n,
    required this.configs,
  });

  final String pickedPath;
  final AppLocalizations l10n;
  final ProImageEditorConfigs configs;

  @override
  State<_ChatVideoEditorPage> createState() => _ChatVideoEditorPageState();
}

class _ChatVideoEditorPageState extends State<_ChatVideoEditorPage> {
  final _taskId = DateTime.now().microsecondsSinceEpoch.toString();

  late final pv.EditorVideo _editorVideo;

  VideoPlayerController? _videoPlayerController;
  ProVideoController? _proVideoController;
  pv.VideoMetadata? _videoMetadata;

  bool _isSeeking = false;
  TrimDurationSpan? _tempDurationSpan;
  TrimDurationSpan? _durationSpan;

  String? _outputPath;

  @override
  void initState() {
    super.initState();
    _editorVideo = pv.EditorVideo.file(widget.pickedPath);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _editorVideo.safeFilePath();
    if (!mounted) return;
    final meta = await pv.ProVideoEditor.instance.getMetadata(_editorVideo);
    if (!mounted) return;
    setState(() => _videoMetadata = meta);

    final c = VideoPlayerController.file(File(widget.pickedPath));
    await c.initialize();
    await c.setLooping(false);
    await c.setVolume(widget.configs.videoEditor.initialMuted ? 0 : 1);
    if (widget.configs.videoEditor.initialPlay) {
      await c.play();
    } else {
      await c.pause();
    }
    if (!mounted) {
      c.dispose();
      return;
    }

    setState(() => _videoPlayerController = c);

    c.addListener(_onDurationChange);

    final thumbs = await _loadThumbnails();
    if (!mounted) {
      c.dispose();
      return;
    }

    setState(() {
      _proVideoController = ProVideoController(
        videoPlayer: _buildVideoPlayer(),
        initialResolution: meta.resolution,
        videoDuration: meta.duration,
        fileSize: meta.fileSize,
        bitrate: meta.bitrate,
        thumbnails: thumbs,
      );
    });
  }

  Future<List<ImageProvider>?> _loadThumbnails() async {
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
      return [];
    }
    final ctx = context;
    if (!ctx.mounted) return [];
    final imageWidth = MediaQuery.sizeOf(ctx).width /
        _thumbnailCount *
        MediaQuery.devicePixelRatioOf(ctx);

    final list = await pv.ProVideoEditor.instance.getKeyFrames(
      pv.KeyFramesConfigs(
        video: _editorVideo,
        outputSize: Size.square(imageWidth),
        boxFit: pv.ThumbnailBoxFit.cover,
        maxOutputFrames: _thumbnailCount,
        outputFormat: pv.ThumbnailFormat.jpeg,
      ),
    );
    final temporaryThumbnails = list.map(MemoryImage.new).toList();
    await Future.wait(temporaryThumbnails.map((img) => precacheImage(img, ctx)));
    return temporaryThumbnails;
  }

  void _onDurationChange() {
    final c = _videoPlayerController;
    final meta = _videoMetadata;
    final pvc = _proVideoController;
    if (c == null || meta == null || pvc == null) return;

    final total = meta.duration;
    final pos = c.value.position;
    pvc.setPlayTime(pos);

    if (_durationSpan != null && pos >= _durationSpan!.end) {
      _seekToPosition(_durationSpan!);
    } else if (pos >= total) {
      _seekToPosition(TrimDurationSpan(start: Duration.zero, end: total));
    }
  }

  Future<void> _seekToPosition(TrimDurationSpan span) async {
    final c = _videoPlayerController;
    final pvc = _proVideoController;
    if (c == null || pvc == null) return;

    _durationSpan = span;

    if (_isSeeking) {
      _tempDurationSpan = span;
      return;
    }
    _isSeeking = true;

    pvc.pause();
    pvc.setPlayTime(span.start);

    await c.pause();
    await c.seekTo(span.start);

    _isSeeking = false;

    if (_tempDurationSpan != null) {
      final next = _tempDurationSpan!;
      _tempDurationSpan = null;
      await _seekToPosition(next);
    }
  }

  List<pv.VideoSegment> _buildExportSegments(CompleteParameters parameters) {
    if (parameters.videoClips.length > 1) {
      return parameters.videoClips.map((clip) {
        return pv.VideoSegment(
          video: pv.EditorVideo.autoSource(
            networkUrl: clip.clip.networkUrl,
            assetPath: clip.clip.assetPath,
            byteArray: clip.clip.bytes,
            file: clip.clip.file,
          ),
          startTime: clip.trimSpan?.start,
          endTime: clip.trimSpan?.end,
        );
      }).toList();
    }
    return [
      pv.VideoSegment(
        video: _editorVideo,
        startTime: parameters.startTime,
        endTime: parameters.endTime,
      ),
    ];
  }

  Future<void> _onCompleteWithParameters(CompleteParameters parameters) async {
    final c = _videoPlayerController;
    final pvc = _proVideoController;
    if (c == null || pvc == null) return;

    await c.pause();

    final dir = await getTemporaryDirectory();
    final outPath = p.join(dir.path, 'chat_video_${DateTime.now().millisecondsSinceEpoch}.mp4');

    final segments = _buildExportSegments(parameters);
    final multiClip = segments.length > 1;

    final hasColorAdjustments = parameters.matrixFilterList.isNotEmpty ||
        parameters.matrixTuneAdjustmentsList.isNotEmpty;

    final imageLayers = parameters.layers.isNotEmpty
        ? [
            pv.ImageLayer(
              image: pv.EditorLayerImage.memory(parameters.image),
            ),
          ]
        : const <pv.ImageLayer>[];

    try {
      final exportModel = pv.VideoRenderData.withQualityPreset(
        id: _taskId,
        videoSegments: segments,
        qualityPreset: pv.VideoQualityPreset.p720,
        imageLayers: imageLayers,
        blur: parameters.blur > 0 ? parameters.blur : null,
        colorFilters: hasColorAdjustments
            ? [pv.ColorFilter(matrix: parameters.colorFiltersCombined)]
            : const [],
        startTime: multiClip ? parameters.startTime : null,
        endTime: multiClip ? parameters.endTime : null,
        transform: parameters.isTransformed
            ? pv.ExportTransform(
                width: parameters.cropWidth,
                height: parameters.cropHeight,
                rotateTurns: 4 - parameters.rotateTurns,
                x: parameters.cropX,
                y: parameters.cropY,
                flipX: parameters.flipX,
                flipY: parameters.flipY,
              )
            : null,
        enableAudio: pvc.isAudioEnabled,
        shouldOptimizeForNetworkUse: true,
      );

      final path = await pv.ProVideoEditor.instance.renderVideoToFile(outPath, exportModel);
      if (mounted) setState(() => _outputPath = path);
    } on pv.RenderCanceledException {
      if (mounted) setState(() => _outputPath = null);
    } catch (e) {
      if (mounted) {
        setState(() => _outputPath = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.l10n.videoEditorExportFailed(e.toString()))),
        );
      }
    }
  }

  void _onCloseEditor(EditorMode editorMode) {
    if (editorMode != EditorMode.main) {
      Navigator.of(context).pop();
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pop(_outputPath);
  }

  Widget _buildVideoPlayer() {
    final c = _videoPlayerController;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    return Center(
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio,
        child: VideoPlayer(c),
      ),
    );
  }

  @override
  void dispose() {
    _videoPlayerController?.removeListener(_onDurationChange);
    _videoPlayerController?.dispose();
    _proVideoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pvc = _proVideoController;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: pvc == null
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator.adaptive()),
            )
          : ProImageEditor.video(
              pvc,
              configs: widget.configs,
              callbacks: ProImageEditorCallbacks(
                onCompleteWithParameters: _onCompleteWithParameters,
                onCloseEditor: _onCloseEditor,
                audioEditorCallbacks: const AudioEditorCallbacks(),
                videoEditorCallbacks: VideoEditorCallbacks(
                  onPause: () => _videoPlayerController?.pause(),
                  onPlay: () => _videoPlayerController?.play(),
                  onMuteToggle: (isMuted) {
                    _videoPlayerController?.setVolume(isMuted ? 0 : 1);
                  },
                  onTrimSpanUpdate: (_) {
                    final c = _videoPlayerController;
                    if (c != null && c.value.isPlaying) {
                      _proVideoController?.pause();
                    }
                  },
                  onTrimSpanEnd: _seekToPosition,
                ),
              ),
            ),
    );
  }
}
