import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

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
      final uri = Uri.parse(widget.message.source);
      final ctrl = VideoPlayerController.networkUrl(
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
              const SizedBox(
                width: 220,
                height: 140,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
                  width: 220,
                  height: 140,
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
                                : 220,
                            height: _c!.value.size.height > 0
                                ? _c!.value.size.height
                                : 140,
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
            if (widget.isSentByMe)
              TimeAndStatus(
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

/// Voice note with Bearer auth stream.
class ThreadAudioBubble extends StatefulWidget {
  const ThreadAudioBubble({
    super.key,
    required this.message,
    required this.accessToken,
    required this.bubble,
    required this.foreground,
    required this.isSentByMe,
  });

  final AudioMessage message;
  final String accessToken;
  final Color bubble;
  final Color foreground;
  final bool isSentByMe;

  @override
  State<ThreadAudioBubble> createState() => _ThreadAudioBubbleState();
}

class _ThreadAudioBubbleState extends State<ThreadAudioBubble> {
  late final AudioPlayer _player = AudioPlayer();
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(widget.message.source),
          headers: {'Authorization': 'Bearer ${widget.accessToken}'},
        ),
      );
      if (mounted) setState(() => _busy = false);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: widget.foreground),
              )
            else
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snap) {
                  final playing = snap.data?.playing ?? false;
                  return IconButton(
                    icon: Icon(
                      playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      color: widget.foreground,
                      size: 36,
                    ),
                    onPressed: () async {
                      if (playing) {
                        await _player.pause();
                      } else {
                        await _player.seek(Duration.zero);
                        await _player.play();
                      }
                    },
                  );
                },
              ),
            const SizedBox(width: 8),
            Icon(Icons.mic, color: widget.foreground.withValues(alpha: 0.8)),
            const SizedBox(width: 10),
            if (widget.isSentByMe)
              TimeAndStatus(
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
