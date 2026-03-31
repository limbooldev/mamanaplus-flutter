import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

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
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: _c!.value.aspectRatio == 0 ? 16 / 9 : _c!.value.aspectRatio,
                        child: VideoPlayer(_c!),
                      ),
                      IconButton(
                        icon: Icon(
                          _c!.value.isPlaying ? Icons.pause_circle : Icons.play_circle_fill,
                          size: 48,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            if (_c!.value.isPlaying) {
                              _c!.pause();
                            } else {
                              _c!.play();
                            }
                          });
                        },
                      ),
                    ],
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
