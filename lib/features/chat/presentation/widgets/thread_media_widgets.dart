import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../../data/chat_repository.dart';
import 'message_status_icon.dart';

/// Inline chat thumbnails use fixed dimensions so the message list does not
/// reflow while images/videos decode or stream.
const double kChatInlineImageW = 220;
const double kChatInlineImageH = 160;
const double kChatInlineVideoW = 220;
const double kChatInlineVideoH = 140;
const double kChatAudioBubbleMinW = 220;

/// Caption text shown below inline image/video bubbles when present.
Widget? buildMediaCaptionWidget(String? caption, Color foreground) {
  final text = caption?.trim();
  if (text == null || text.isEmpty) return null;
  return Padding(
    padding: const EdgeInsets.only(top: 4, left: 2, right: 2, bottom: 2),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kChatInlineImageW),
      child: Text(
        text,
        style: TextStyle(color: foreground, fontSize: 14),
      ),
    ),
  );
}

/// Parses `object_key` from our `/v1/media/download?object_key=…` URLs (used by voice playback + tests).
String? parseObjectKeyFromMediaDownloadUrl(String source) {
  final uri = Uri.tryParse(source);
  if (uri == null) return null;
  if (!uri.isScheme('http') && !uri.isScheme('https')) return null;
  final key = uri.queryParameters['object_key'];
  if (key == null || key.isEmpty) return null;
  return key;
}

Future<void> openChatFullscreenImage(
  BuildContext context, {
  required String url,
  required String accessToken,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => _ChatFullscreenImagePage(
        url: url,
        accessToken: accessToken,
      ),
    ),
  );
}

Future<void> openChatFullscreenVideo(
  BuildContext context, {
  required String url,
  required String accessToken,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => _ChatFullscreenVideoPage(
        url: url,
        accessToken: accessToken,
      ),
    ),
  );
}

class _ChatFullscreenImagePage extends StatelessWidget {
  const _ChatFullscreenImagePage({
    required this.url,
    required this.accessToken,
  });

  final String url;
  final String accessToken;

  @override
  Widget build(BuildContext context) {
    final headers = {'Authorization': 'Bearer $accessToken'};
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Image.network(
                      url,
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      fit: BoxFit.contain,
                      headers: headers,
                      loadingBuilder: (c, child, p) => p == null
                          ? child
                          : const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white70,
                              ),
                            ),
                      errorBuilder: (_, __, ___) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            url,
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatFullscreenVideoPage extends StatefulWidget {
  const _ChatFullscreenVideoPage({
    required this.url,
    required this.accessToken,
  });

  final String url;
  final String accessToken;

  @override
  State<_ChatFullscreenVideoPage> createState() => _ChatFullscreenVideoPageState();
}

const _playbackSpeeds = <double>[0.25, 0.5, 1.0, 1.5, 2.0];

String _formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString();
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    return '${d.inHours}:${m.padLeft(2, '0')}:$s';
  }
  return '$m:$s';
}

String _speedLabel(double s) {
  if (s == 1.0 || s == 2.0) return '${s.toStringAsFixed(0)}x';
  if (s == 0.25 || s == 0.5 || s == 1.5) return '${s}x';
  return '${s}x';
}

class _ChatFullscreenVideoPageState extends State<_ChatFullscreenVideoPage> {
  VideoPlayerController? _c;
  bool _loading = true;
  String? _err;
  double _speed = 1.0;
  bool _muted = false;
  bool _sliderDragging = false;
  double _sliderDragProgress = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final uri = Uri.parse(widget.url);
      final ctrl = VideoPlayerController.networkUrl(
        uri,
        httpHeaders: {'Authorization': 'Bearer ${widget.accessToken}'},
      );
      await ctrl.initialize();
      if (!mounted) return;
      await ctrl.setPlaybackSpeed(_speed);
      await ctrl.setVolume(_muted ? 0 : 1);
      ctrl.addListener(_onVideoUpdate);
      setState(() {
        _c = ctrl;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = '$e';
      });
    }
  }

  void _onVideoUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _setSpeed(double speed) async {
    final c = _c;
    if (c == null) return;
    await c.setPlaybackSpeed(speed);
    if (mounted) setState(() => _speed = speed);
  }

  Future<void> _setMuted(bool muted) async {
    final c = _c;
    if (c == null) return;
    await c.setVolume(muted ? 0 : 1);
    if (mounted) setState(() => _muted = muted);
  }

  @override
  void dispose() {
    _c?.removeListener(_onVideoUpdate);
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ready = c != null && !_loading && _err == null;
    final duration = ready ? c.value.duration : Duration.zero;
    final position = ready ? c.value.position : Duration.zero;
    final maxMs = duration.inMilliseconds;
    final progress = maxMs > 0
        ? (position.inMilliseconds / maxMs).clamp(0.0, 1.0)
        : 0.0;
    final sliderValue = _sliderDragging ? _sliderDragProgress : progress;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Center(
                    child: _loading
                        ? const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          )
                        : _err != null
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  _err!,
                                  style: const TextStyle(color: Colors.white70),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : c != null
                                ? AspectRatio(
                                    aspectRatio: c.value.aspectRatio == 0
                                        ? 16 / 9
                                        : c.value.aspectRatio,
                                    child: VideoPlayer(c),
                                  )
                                : const SizedBox.shrink(),
                  ),
                ),
                if (ready && maxMs > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              _formatDuration(position),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14,
                            ),
                          ),
                          child: Slider(
                            value: sliderValue.clamp(0.0, 1.0),
                            onChangeStart: (_) {
                              setState(() {
                                _sliderDragging = true;
                                _sliderDragProgress = progress;
                              });
                            },
                            onChanged: (v) {
                              setState(() => _sliderDragProgress = v);
                              c.seekTo(
                                Duration(
                                  milliseconds: (v * maxMs).round(),
                                ),
                              );
                            },
                            onChangeEnd: (_) {
                              setState(() {
                                _sliderDragging = false;
                              });
                            },
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                c.value.isPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                                size: 40,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                if (c.value.isPlaying) {
                                  c.pause();
                                } else {
                                  c.play();
                                }
                                setState(() {});
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                _muted ? Icons.volume_off : Icons.volume_up,
                                color: Colors.white70,
                              ),
                              onPressed: () => _setMuted(!_muted),
                            ),
                            const Spacer(),
                            PopupMenuButton<double>(
                              initialValue: _speed,
                              tooltip: 'Speed',
                              color: const Color(0xFF2C2C2C),
                              onSelected: _setSpeed,
                              itemBuilder: (context) => _playbackSpeeds
                                  .map(
                                    (sp) => PopupMenuItem<double>(
                                      value: sp,
                                      child: Text(
                                        _speedLabel(sp),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _speedLabel(_speed),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.white70,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline video with Bearer auth (same-origin API download).
class ThreadVideoBubble extends StatefulWidget {
  const ThreadVideoBubble({
    super.key,
    required this.message,
    required this.accessToken,
    required this.bubble,
    required this.foreground,
    required this.isSentByMe,
  });

  final VideoMessage message;
  final String accessToken;
  final Color bubble;
  final Color foreground;
  final bool isSentByMe;

  @override
  State<ThreadVideoBubble> createState() => _ThreadVideoBubbleState();
}

class _ThreadVideoBubbleState extends State<ThreadVideoBubble> {
  VideoPlayerController? _c;
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final source = widget.message.source;
      final uri = Uri.parse(source);
      // Pending media bubbles point at a local file:// URL while the upload is
      // still running. Switch the player to a `.file()` controller in that case
      // — `networkUrl` would throw on a non-http scheme.
      final ctrl = uri.scheme == 'file'
          ? VideoPlayerController.file(File(uri.toFilePath()))
          : VideoPlayerController.networkUrl(
              uri,
              httpHeaders: {'Authorization': 'Bearer ${widget.accessToken}'},
            );
      await ctrl.initialize();
      if (!mounted) return;
      await ctrl.setVolume(0);
      await ctrl.pause();
      await ctrl.seekTo(Duration.zero);
      if (!mounted) return;
      setState(() {
        _c = ctrl;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = '$e';
      });
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<ChatTheme>();
    final captionWidget = buildMediaCaptionWidget(
      widget.message.metadata?['caption'] as String?,
      widget.foreground,
    );
    return Align(
      alignment: widget.isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: widget.bubble,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loading)
              SizedBox(
                width: kChatInlineVideoW,
                height: kChatInlineVideoH,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.foreground.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_err != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_err!, style: TextStyle(color: widget.foreground)),
              )
            else if (_c != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: kChatInlineVideoW,
                  height: kChatInlineVideoH,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      openChatFullscreenVideo(
                        context,
                        url: widget.message.source,
                        accessToken: widget.accessToken,
                      );
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: _c!.value.size.width > 0
                                ? _c!.value.size.width
                                : kChatInlineVideoW,
                            height: _c!.value.size.height > 0
                                ? _c!.value.size.height
                                : kChatInlineVideoH,
                            child: VideoPlayer(_c!),
                          ),
                        ),
                        Icon(
                          Icons.play_circle_fill,
                          size: 52,
                          color: Colors.white.withValues(alpha: 0.92),
                          shadows: const [
                            Shadow(blurRadius: 8, color: Colors.black54),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (captionWidget != null) captionWidget,
            if (widget.isSentByMe)
              CustomTimeAndStatus(
                time: widget.message.resolvedTime,
                status: widget.message.resolvedStatus,
                showTime: true,
                showStatus: true,
                textStyle: theme.typography.labelSmall.copyWith(
                  color: widget.foreground.withValues(alpha: 0.9),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Voice note: local `file://` pending uploads stream directly; server messages are
/// downloaded via [ChatRepository] (Dio + auth) then played from disk (reliable on iOS).
class ThreadAudioBubble extends StatefulWidget {
  const ThreadAudioBubble({
    super.key,
    required this.message,
    required this.chatRepository,
    required this.accessToken,
    required this.bubble,
    required this.foreground,
    required this.isSentByMe,
    this.voiceCacheOverride,
  });

  final AudioMessage message;
  final ChatRepository chatRepository;
  final String accessToken;
  final Color bubble;
  final Color foreground;
  final bool isSentByMe;

  /// In tests, bypasses [ChatRepository.downloadVoiceToCache].
  final Future<File> Function(String objectKey)? voiceCacheOverride;

  @override
  State<ThreadAudioBubble> createState() => _ThreadAudioBubbleState();
}

class _ThreadAudioBubbleState extends State<ThreadAudioBubble> {
  static final ValueNotifier<_ThreadAudioBubbleState?> _activeVoiceBubble =
      ValueNotifier<_ThreadAudioBubbleState?>(null);

  late final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  var _loading = true;
  String? _loadError;
  var _sliderDragging = false;
  var _sliderDragProgress = 0.0;

  void _onActiveVoiceBubbleChanged() {
    final active = _activeVoiceBubble.value;
    if (active != this && _player.playing) {
      unawaited(
        _player.pause().then((_) {
          if (mounted) setState(() {});
        }),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _activeVoiceBubble.addListener(_onActiveVoiceBubbleChanged);
    _playerStateSub = _player.playerStateStream.listen(_onPlayerState);
    _positionSub = _player.positionStream.listen(_onPositionTick);
    _load();
  }

  var _resettingAfterComplete = false;

  void _onPlayerState(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      unawaited(_resetAfterPlaybackComplete());
    }
  }

  void _onPositionTick(Duration position) {
    final d = _player.duration;
    if (d == null || d.inMilliseconds <= 0 || _resettingAfterComplete) return;
    if (!_player.playing) return;
    if (position.inMilliseconds < d.inMilliseconds) return;
    unawaited(_resetAfterPlaybackComplete());
  }

  Future<void> _resetAfterPlaybackComplete() async {
    if (_resettingAfterComplete) return;
    _resettingAfterComplete = true;
    try {
      await _player.pause();
      await _player.seek(Duration.zero);
    } catch (_) {}
    finally {
      _resettingAfterComplete = false;
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(ThreadAudioBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.source != widget.message.source) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      await _player.stop();
      final uri = Uri.parse(widget.message.source);
      if (uri.scheme == 'file') {
        await _player.setAudioSource(AudioSource.uri(uri));
      } else if (uri.isScheme('http') || uri.isScheme('https')) {
        final key = parseObjectKeyFromMediaDownloadUrl(widget.message.source);
        if (key != null && key.isNotEmpty) {
          final file = widget.voiceCacheOverride != null
              ? await widget.voiceCacheOverride!(key)
              : await widget.chatRepository.downloadVoiceToCache(key);
          await _player.setAudioSource(AudioSource.uri(Uri.file(file.path)));
        } else {
          final token =
              await widget.chatRepository.getFreshAccessToken() ?? widget.accessToken;
          await _player.setAudioSource(
            AudioSource.uri(
              uri,
              headers: {'Authorization': 'Bearer $token'},
            ),
          );
        }
      } else {
        throw UnsupportedError('Unsupported audio URI scheme: ${uri.scheme}');
      }
      if (mounted) setState(() => _loading = false);
    } catch (e, st) {
      debugPrint('ThreadAudioBubble load failed: $e\n$st');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  Future<void> _togglePlay() async {
    try {
      final playing = _player.playing;
      if (playing) {
        await _player.pause();
      } else {
        _activeVoiceBubble.value = this;
        await _player.seek(Duration.zero);
        await _player.play();
      }
      if (mounted) setState(() {});
    } catch (e, st) {
      debugPrint('ThreadAudioBubble play failed: $e\n$st');
      if (mounted) {
        setState(() => _loadError = e.toString());
      }
    }
  }

  Future<void> _seekToProgress(double v, int maxMs) async {
    try {
      await _player.seek(Duration(milliseconds: (v * maxMs).round()));
    } catch (e, st) {
      debugPrint('ThreadAudioBubble seek failed: $e\n$st');
      if (mounted) setState(() => _loadError = e.toString());
    }
  }

  @override
  void dispose() {
    if (_activeVoiceBubble.value == this) {
      _activeVoiceBubble.value = null;
    }
    _activeVoiceBubble.removeListener(_onActiveVoiceBubbleChanged);
    unawaited(_playerStateSub?.cancel() ?? Future<void>.value());
    unawaited(_positionSub?.cancel() ?? Future<void>.value());
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<ChatTheme>();
    return Align(
      alignment: widget.isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.bubble,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: kChatAudioBubbleMinW),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (_loading)
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.foreground,
                        ),
                      ),
                    )
                  else if (_loadError != null)
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.error_outline, color: Colors.red.shade700, size: 28),
                    )
                  else
                    StreamBuilder<PlayerState>(
                      stream: _player.playerStateStream,
                      builder: (context, snap) {
                        final s = snap.data;
                        final playing = s?.playing ?? false;
                        final ps = s?.processingState ?? ProcessingState.idle;
                        // Some platforms leave `playing` true at EOF; `completed` + position handle that.
                        final showPause =
                            playing && ps != ProcessingState.completed;
                        return IconButton(
                          icon: Icon(
                            showPause ? Icons.pause_circle_filled : Icons.play_circle_fill,
                            color: widget.foreground,
                            size: 36,
                          ),
                          onPressed: _togglePlay,
                        );
                      },
                    ),
                  const SizedBox(width: 4),
                  Icon(Icons.mic, color: widget.foreground.withValues(alpha: 0.8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _loadError != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _loadError!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.labelSmall.copyWith(
                                  color: widget.foreground.withValues(alpha: 0.85),
                                ),
                              ),
                              TextButton(
                                onPressed: _loading ? null : _load,
                                child: const Text('Retry'),
                              ),
                            ],
                          )
                        : Align(
                            alignment: Alignment.centerRight,
                            child: widget.isSentByMe
                                ? CustomTimeAndStatus(
                                    time: widget.message.resolvedTime,
                                    status: widget.message.resolvedStatus,
                                    showTime: true,
                                    showStatus: true,
                                    textStyle: theme.typography.labelSmall.copyWith(
                                      color: widget.foreground.withValues(alpha: 0.9),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                  ),
                ],
              ),
              if (!_loading && _loadError == null)
                StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  initialData: _player.position,
                  builder: (context, posSnap) {
                    return StreamBuilder<Duration?>(
                      stream: _player.durationStream,
                      initialData: _player.duration,
                      builder: (context, durSnap) {
                        final position = posSnap.data ?? Duration.zero;
                        final duration = durSnap.data ?? Duration.zero;
                        final maxMs = duration.inMilliseconds;
                        if (maxMs <= 0) return const SizedBox.shrink();
                        final progress = maxMs > 0
                            ? (position.inMilliseconds / maxMs).clamp(0.0, 1.0)
                            : 0.0;
                        final sliderValue = _sliderDragging ? _sliderDragProgress : progress;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: theme.typography.labelSmall.copyWith(
                                      color: widget.foreground.withValues(alpha: 0.75),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatDuration(duration),
                                    style: theme.typography.labelSmall.copyWith(
                                      color: widget.foreground.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                ),
                                child: Slider(
                                  value: sliderValue.clamp(0.0, 1.0),
                                  onChangeStart: (_) {
                                    setState(() {
                                      _sliderDragging = true;
                                      _sliderDragProgress = progress;
                                    });
                                  },
                                  onChanged: (v) {
                                    setState(() => _sliderDragProgress = v);
                                    unawaited(_seekToProgress(v, maxMs));
                                  },
                                  onChangeEnd: (_) {
                                    setState(() => _sliderDragging = false);
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
