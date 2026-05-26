import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../shared/ui/ui.dart';

/// UI phase for the inline voice recorder.
enum VoiceRecorderUiState { idle, recording, locked, preview }

/// Abstraction over [AudioRecorder] for tests.
abstract class VoiceRecorderBackend {
  Future<bool> hasPermission();
  Future<void> start({required String path});
  Future<String?> stop();
  Future<void> cancel();
  Stream<Amplitude> onAmplitudeChanged({Duration period = const Duration(milliseconds: 100)});
  void dispose();
}

class _RecordPackageBackend implements VoiceRecorderBackend {
  _RecordPackageBackend() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start({required String path}) => _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Stream<Amplitude> onAmplitudeChanged({Duration period = const Duration(milliseconds: 100)}) =>
      _recorder.onAmplitudeChanged(period);

  @override
  void dispose() => unawaited(_recorder.dispose());
}

/// Test double — no platform channels.
class FakeVoiceRecorderBackend implements VoiceRecorderBackend {
  var permissionGranted = true;
  var isRecording = false;
  String? lastPath;
  final _amplitudeController = StreamController<Amplitude>.broadcast();

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<void> start({required String path}) async {
    isRecording = true;
    lastPath = path;
  }

  @override
  Future<String?> stop() async {
    isRecording = false;
    return lastPath;
  }

  @override
  Future<void> cancel() async {
    isRecording = false;
    lastPath = null;
  }

  @override
  Stream<Amplitude> onAmplitudeChanged({Duration period = const Duration(milliseconds: 100)}) =>
      _amplitudeController.stream;

  void emitAmplitude(double db) {
    _amplitudeController.add(Amplitude(current: db, max: db));
  }

  @override
  void dispose() => unawaited(_amplitudeController.close());
}

/// Holds recording logic; shared by mic trigger and active bar widgets.
class ThreadVoiceRecorderController extends ChangeNotifier {
  ThreadVoiceRecorderController({
    required this.onSend,
    this.onCancel,
    this.onPermissionDenied,
    VoiceRecorderBackend? backend,
    Future<String> Function()? createTempVoicePath,
    this.enablePreviewPlayback = true,
  })  : _backend = backend ?? _RecordPackageBackend(),
        _createTempVoicePath = createTempVoicePath ?? _defaultTempVoicePath;

  final Future<void> Function(String path, Duration duration) onSend;
  final VoidCallback? onCancel;
  final VoidCallback? onPermissionDenied;
  final VoiceRecorderBackend _backend;
  final Future<String> Function() _createTempVoicePath;

  /// When false, [enterPreview] skips [AudioPlayer] (for unit tests).
  final bool enablePreviewPlayback;

  static Future<String> _defaultTempVoicePath() async {
    final dir = await getTemporaryDirectory();
    return p.join(dir.path, 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
  }

  static const cancelDragThreshold = 80.0;
  static const lockDragThreshold = 80.0;

  VoiceRecorderUiState _state = VoiceRecorderUiState.idle;
  VoiceRecorderUiState get state => _state;
  bool get isActive => _state != VoiceRecorderUiState.idle;

  String? _filePath;
  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  Timer? _timer;
  Stopwatch? _stopwatch;
  int _recordSession = 0;
  StreamSubscription<Amplitude>? _amplitudeSub;
  final List<double> _amplitudeSamples = [];
  List<double> get amplitudeSamples => List.unmodifiable(_amplitudeSamples);

  Offset _dragOffset = Offset.zero;
  Offset get dragOffset => _dragOffset;

  bool _cancelArmed = false;
  bool get cancelArmed => _cancelArmed;

  bool _lockArmed = false;
  bool get lockArmed => _lockArmed;

  // Preview playback
  AudioPlayer? _previewPlayer;
  StreamSubscription<Duration>? _previewPositionSub;
  StreamSubscription<PlayerState>? _previewStateSub;
  var _previewPlaying = false;
  bool get previewPlaying => _previewPlaying;
  var _previewPosition = Duration.zero;
  Duration get previewPosition => _previewPosition;
  var _previewDuration = Duration.zero;
  Duration get previewDuration => _previewDuration;

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch?.stop();
    unawaited(_amplitudeSub?.cancel());
    unawaited(_disposePreviewPlayer());
    _backend.dispose();
    super.dispose();
  }

  Future<void> beginRecording() async {
    if (_state != VoiceRecorderUiState.idle) return;
    final session = ++_recordSession;
    _setState(VoiceRecorderUiState.recording);
    final ok = await _backend.hasPermission();
    if (session != _recordSession) return;
    if (!ok) {
      _resetToIdle();
      onPermissionDenied?.call();
      return;
    }
    try {
      _filePath = await _createTempVoicePath();
      await _backend.start(path: _filePath!);
    } catch (_) {
      if (session != _recordSession) return;
      await _stopTimerAndAmplitude();
      await _backend.cancel();
      _filePath = null;
      _resetToIdle();
      return;
    }
    if (session != _recordSession || _state == VoiceRecorderUiState.idle) return;

    await _stopTimerAndAmplitude();
    _duration = Duration.zero;
    _amplitudeSamples.clear();
    _dragOffset = Offset.zero;
    _cancelArmed = false;
    _lockArmed = false;
    _amplitudeSub = _backend.onAmplitudeChanged().listen((amp) {
      final normalized = _normalizeAmplitude(amp.current);
      _amplitudeSamples.add(normalized);
      const maxSamples = 48;
      if (_amplitudeSamples.length > maxSamples) {
        _amplitudeSamples.removeAt(0);
      }
      // Waveform is only visible in locked mode; avoid rebuilding the composer ~10×/s while holding.
      if (_state == VoiceRecorderUiState.locked) {
        notifyListeners();
      }
    });
    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final sw = _stopwatch;
      if (sw == null) return;
      _duration = sw.elapsed;
      notifyListeners();
    });
    notifyListeners();
  }

  /// [totalOffset] is finger position minus pointer-down position.
  void updateDragFromStart(Offset totalOffset, {required bool isRtl}) {
    if (_state != VoiceRecorderUiState.recording) return;
    _dragOffset = totalOffset;
    // LTR: slide left to cancel; RTL: slide right to cancel.
    final cancelSlide = isRtl ? totalOffset.dx : -totalOffset.dx;
    final up = -totalOffset.dy;
    final wasCancel = _cancelArmed;
    final wasLock = _lockArmed;
    _cancelArmed = cancelSlide >= cancelDragThreshold;
    _lockArmed = up >= lockDragThreshold;
    if (_cancelArmed && !wasCancel) _hapticMedium();
    if (_lockArmed && !wasLock) _hapticMedium();
    notifyListeners();
  }

  Future<void> onPointerUp() async {
    if (_state != VoiceRecorderUiState.recording) return;
    if (_cancelArmed) {
      await _discardRecording();
      return;
    }
    if (_lockArmed) {
      _dragOffset = Offset.zero;
      _cancelArmed = false;
      _lockArmed = false;
      _setState(VoiceRecorderUiState.locked);
      return;
    }
    await _finishAndSend();
  }

  Future<void> cancelRecording() async {
    await _discardRecording();
  }

  Future<void> sendRecording() async {
    if (_state == VoiceRecorderUiState.preview) {
      await _sendCurrentFile();
      return;
    }
    if (_state == VoiceRecorderUiState.locked) {
      await _finishAndSend();
    }
  }

  Future<void> enterPreview() async {
    if (_state != VoiceRecorderUiState.locked) return;
    await _stopTimerAndAmplitude();
    final path = _filePath;
    if (path == null) return;
    await _backend.stop();
    _setState(VoiceRecorderUiState.preview);
    if (enablePreviewPlayback) {
      await _initPreviewPlayer(path);
    } else {
      _previewDuration = _duration;
      notifyListeners();
    }
  }

  Future<void> togglePreviewPlay() async {
    final player = _previewPlayer;
    if (player == null) return;
    if (_previewPlaying) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> seekPreview(double progress) async {
    final player = _previewPlayer;
    final dur = _previewDuration;
    if (player == null || dur.inMilliseconds <= 0) return;
    await player.seek(Duration(milliseconds: (progress * dur.inMilliseconds).round()));
  }

  void _setState(VoiceRecorderUiState next) {
    _state = next;
    notifyListeners();
  }

  Future<void> _finishAndSend() async {
    await _stopTimerAndAmplitude();
    final path = await _backend.stop() ?? _filePath;
    if (path == null || path.isEmpty) {
      _resetToIdle();
      return;
    }
    final dur = _duration;
    _resetToIdle();
    await onSend(path, dur);
  }

  Future<void> _sendCurrentFile() async {
    final path = _filePath;
    if (path == null) {
      _resetToIdle();
      return;
    }
    final dur = _previewDuration.inMilliseconds > 0 ? _previewDuration : _duration;
    await _disposePreviewPlayer();
    _resetToIdle();
    await onSend(path, dur);
  }

  static void _hapticMedium() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static void _hapticSelection() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  Future<void> _discardRecording() async {
    _hapticSelection();
    await _stopTimerAndAmplitude();
    await _disposePreviewPlayer();
    await _backend.cancel();
    final path = _filePath;
    _filePath = null;
    _resetToIdle();
    onCancel?.call();
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  Future<void> _stopTimerAndAmplitude() async {
    _timer?.cancel();
    _timer = null;
    _stopwatch?.stop();
    _stopwatch = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
  }

  Future<void> _initPreviewPlayer(String path) async {
    await _disposePreviewPlayer();
    final player = AudioPlayer();
    _previewPlayer = player;
    try {
      await player.setAudioSource(AudioSource.uri(Uri.file(path)));
      _previewDuration = player.duration ?? _duration;
      _previewPosition = Duration.zero;
      _previewPlaying = false;
      _previewPositionSub = player.positionStream.listen((pos) {
        _previewPosition = pos;
        notifyListeners();
      });
      _previewStateSub = player.playerStateStream.listen((st) {
        _previewPlaying = st.playing;
        if (st.processingState == ProcessingState.completed) {
          _previewPlaying = false;
          _previewPosition = Duration.zero;
          unawaited(player.seek(Duration.zero));
        }
        notifyListeners();
      });
      notifyListeners();
    } catch (_) {
      await _disposePreviewPlayer();
    }
  }

  Future<void> _disposePreviewPlayer() async {
    await _previewPositionSub?.cancel();
    await _previewStateSub?.cancel();
    _previewPositionSub = null;
    _previewStateSub = null;
    await _previewPlayer?.dispose();
    _previewPlayer = null;
    _previewPlaying = false;
    _previewPosition = Duration.zero;
    _previewDuration = Duration.zero;
  }

  void _resetToIdle() {
    _recordSession++;
    _timer?.cancel();
    _timer = null;
    _stopwatch?.stop();
    _stopwatch = null;
    _state = VoiceRecorderUiState.idle;
    _filePath = null;
    _duration = Duration.zero;
    _dragOffset = Offset.zero;
    _cancelArmed = false;
    _lockArmed = false;
    _amplitudeSamples.clear();
    notifyListeners();
  }

  static double _normalizeAmplitude(double db) {
    // dBFS typically -60..0; map to 0..1
    const minDb = -50.0;
    const maxDb = 0.0;
    final clamped = db.clamp(minDb, maxDb);
    return ((clamped - minDb) / (maxDb - minDb)).clamp(0.08, 1.0);
  }
}

String formatVoiceDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Mic trigger — press-and-hold to record; place in composer row when idle.
class ThreadVoiceRecorderMic extends StatefulWidget {
  const ThreadVoiceRecorderMic({
    super.key,
    required this.controller,
    required this.primaryColor,
  });

  final ThreadVoiceRecorderController controller;
  final Color primaryColor;

  @override
  State<ThreadVoiceRecorderMic> createState() => _ThreadVoiceRecorderMicState();
}

class _ThreadVoiceRecorderMicState extends State<ThreadVoiceRecorderMic> {
  Offset? _pointerDown;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant ThreadVoiceRecorderMic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Color get _micColor {
    final c = widget.controller;
    if (c.state == VoiceRecorderUiState.recording && c.cancelArmed) {
      return AppColors.error;
    }
    return widget.primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Listener(
      key: const ValueKey('voice-recorder-mic-listener'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) async {
        _pointerDown = e.position;
        await widget.controller.beginRecording();
      },
      onPointerMove: (e) {
        final start = _pointerDown;
        if (start == null) return;
        if (widget.controller.state == VoiceRecorderUiState.recording) {
          widget.controller.updateDragFromStart(
            e.position - start,
            isRtl: isRtl,
          );
        }
      },
      onPointerUp: (_) {
        _pointerDown = null;
        unawaited(widget.controller.onPointerUp());
      },
      onPointerCancel: (_) {
        _pointerDown = null;
        unawaited(widget.controller.onPointerUp());
      },
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: Icon(Icons.mic, color: _micColor, size: 26),
      ),
    );
  }
}

/// Full-width recording / locked / preview bar.
class ThreadVoiceRecorderBar extends StatelessWidget {
  const ThreadVoiceRecorderBar({
    super.key,
    required this.controller,
    required this.isDark,
    required this.primaryColor,
    required this.onSurfaceColor,
  });

  final ThreadVoiceRecorderController controller;
  final bool isDark;
  final Color primaryColor;
  final Color onSurfaceColor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        switch (controller.state) {
          case VoiceRecorderUiState.recording:
            return ThreadVoiceRecorderHoldContent(
              controller: controller,
              onSurfaceColor: onSurfaceColor,
            );
          case VoiceRecorderUiState.locked:
            return _LockedBar(
              controller: controller,
              primaryColor: primaryColor,
              onSurfaceColor: onSurfaceColor,
            );
          case VoiceRecorderUiState.preview:
            return _PreviewBar(
              controller: controller,
              primaryColor: primaryColor,
              onSurfaceColor: onSurfaceColor,
            );
          case VoiceRecorderUiState.idle:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

/// Timer + slide-to-cancel row (mic stays in composer for gesture continuity).
class ThreadVoiceRecorderHoldContent extends StatelessWidget {
  const ThreadVoiceRecorderHoldContent({
    super.key,
    required this.controller,
    required this.onSurfaceColor,
  });

  final ThreadVoiceRecorderController controller;
  final Color onSurfaceColor;

  @override
  Widget build(BuildContext context) {
    final cancelArmed = controller.cancelArmed;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final cancelSlide = isRtl ? controller.dragOffset.dx : -controller.dragOffset.dx;
    final slideX = cancelSlide.clamp(0.0, 120.0);

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          _PulsingDot(color: AppColors.error),
          const SizedBox(width: 8),
          Text(
            formatVoiceDuration(controller.duration),
            style: TextStyle(
              color: cancelArmed ? AppColors.error : onSurfaceColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Transform.translate(
            offset: Offset(isRtl ? slideX : -slideX, 0),
            child: Opacity(
              opacity: (1.0 - slideX / 120).clamp(0.3, 1.0),
              child: Text(
                isRtl ? 'Slide to cancel >' : '< Slide to cancel',
                style: TextStyle(
                  color: cancelArmed
                      ? AppColors.error
                      : onSurfaceColor.withValues(alpha: 0.55),
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lock pill + mic offset while recording (held).
class ThreadVoiceRecorderMicCluster extends StatelessWidget {
  const ThreadVoiceRecorderMicCluster({
    super.key,
    required this.controller,
    required this.isDark,
    required this.primaryColor,
  });

  final ThreadVoiceRecorderController controller;
  final bool isDark;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 100,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final lockArmed = controller.lockArmed;
              if (lockArmed) return const SizedBox.shrink();
              final slideY = (-controller.dragOffset.dy).clamp(0.0, 80.0);
              return Positioned(
                bottom: 52 + slideY,
                child: _LockHint(lockArmed: lockArmed, isDark: isDark),
              );
            },
          ),
          ThreadVoiceRecorderMic(
            key: const ValueKey('voice-recorder-mic'),
            controller: controller,
            primaryColor: primaryColor,
          ),
        ],
      ),
    );
  }
}

class _LockHint extends StatelessWidget {
  const _LockHint({required this.lockArmed, required this.isDark});

  final bool lockArmed;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: lockArmed ? 1 : 0.85,
      duration: const Duration(milliseconds: 150),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFF3A3A3C),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              lockArmed ? Icons.lock : Icons.lock_open_outlined,
              color: Colors.white70,
              size: 16,
            ),
            const SizedBox(height: 2),
            Icon(Icons.keyboard_arrow_up, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ac, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

class _LockedBar extends StatelessWidget {
  const _LockedBar({
    required this.controller,
    required this.primaryColor,
    required this.onSurfaceColor,
  });

  final ThreadVoiceRecorderController controller;
  final Color primaryColor;
  final Color onSurfaceColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: onSurfaceColor.withValues(alpha: 0.6)),
            onPressed: () => unawaited(controller.cancelRecording()),
          ),
          Expanded(
            child: Row(
              children: [
                _AmplitudeWaveform(
                  samples: controller.amplitudeSamples,
                  color: onSurfaceColor.withValues(alpha: 0.45),
                  activeColor: primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  formatVoiceDuration(controller.duration),
                  style: TextStyle(
                    color: onSurfaceColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.pause, color: onSurfaceColor.withValues(alpha: 0.85)),
            onPressed: () => unawaited(controller.enterPreview()),
          ),
          _SendCircle(
            color: primaryColor,
            onPressed: () => unawaited(controller.sendRecording()),
          ),
        ],
      ),
    );
  }
}

class _PreviewBar extends StatelessWidget {
  const _PreviewBar({
    required this.controller,
    required this.primaryColor,
    required this.onSurfaceColor,
  });

  final ThreadVoiceRecorderController controller;
  final Color primaryColor;
  final Color onSurfaceColor;

  @override
  Widget build(BuildContext context) {
    final dur = controller.previewDuration;
    final pos = controller.previewPosition;
    final maxMs = math.max(1, dur.inMilliseconds);
    final progress = (pos.inMilliseconds / maxMs).clamp(0.0, 1.0);
    final remaining = dur - pos;

    return SizedBox(
      height: 52,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: onSurfaceColor.withValues(alpha: 0.6)),
            onPressed: () => unawaited(controller.cancelRecording()),
          ),
          IconButton(
            icon: Icon(
              controller.previewPlaying ? Icons.pause : Icons.play_arrow,
              color: onSurfaceColor,
            ),
            onPressed: () => unawaited(controller.togglePreviewPlay()),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: progress,
                      activeColor: primaryColor,
                      inactiveColor: onSurfaceColor.withValues(alpha: 0.25),
                      onChanged: (v) => unawaited(controller.seekPreview(v)),
                    ),
                  ),
                ),
                Text(
                  formatVoiceDuration(remaining),
                  style: TextStyle(color: onSurfaceColor, fontSize: 14),
                ),
              ],
            ),
          ),
          _SendCircle(
            color: primaryColor,
            onPressed: () => unawaited(controller.sendRecording()),
          ),
        ],
      ),
    );
  }
}

class _SendCircle extends StatelessWidget {
  const _SendCircle({required this.color, required this.onPressed});

  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Icon(Icons.send, color: AppColors.onPrimary, size: 22),
          ),
        ),
      ),
    );
  }
}

class _AmplitudeWaveform extends StatelessWidget {
  const _AmplitudeWaveform({
    required this.samples,
    required this.color,
    required this.activeColor,
  });

  final List<double> samples;
  final Color color;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 28,
        child: CustomPaint(
          painter: _WaveformPainter(
            samples: samples.isEmpty ? List.filled(24, 0.15) : samples,
            color: color,
            activeColor: activeColor,
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.samples,
    required this.color,
    required this.activeColor,
  });

  final List<double> samples;
  final Color color;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final barW = 3.0;
    final gap = 2.0;
    final count = (size.width / (barW + gap)).floor().clamp(8, 48);
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final sampleIdx =
          samples.isEmpty ? 0 : ((i / count) * samples.length).floor().clamp(0, samples.length - 1);
      final level = samples.isEmpty ? 0.15 : samples[sampleIdx];
      final h = (level * size.height).clamp(4.0, size.height);
      final x = i * (barW + gap);
      paint.color = i >= count - 4 ? activeColor : color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (size.height - h) / 2, barW, h),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.samples != samples;
}
