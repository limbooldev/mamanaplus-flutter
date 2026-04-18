import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/api_config.dart';
import '../../../chat/presentation/cubit/auth_cubit.dart';

/// Returns true when [ref] is an absolute HTTP(S) URL (legacy / external media).
bool socialMediaIsRemoteUrl(String? ref) {
  if (ref == null || ref.isEmpty) return false;
  final u = ref.toLowerCase();
  return u.startsWith('http://') || u.startsWith('https://');
}

/// Backend download URL for a stored [objectKey] (e.g. `social/12/…`, `conv/…`).
String socialMediaDownloadUrl(String apiBase, String objectKey) {
  final b = apiBase.endsWith('/')
      ? apiBase.substring(0, apiBase.length - 1)
      : apiBase;
  return '$b/v1/media/download?object_key=${Uri.encodeComponent(objectKey)}';
}

/// Resolves [ref] to a fetchable URL; pass [apiBase] from [ApiConfig.baseUrl].
String socialMediaResolveUrl(String apiBase, String ref) {
  if (socialMediaIsRemoteUrl(ref)) return ref;
  return socialMediaDownloadUrl(apiBase, ref);
}

/// Thumbnail / inline image: supports plain URLs and private object keys (Bearer).
class SocialPostImage extends StatelessWidget {
  const SocialPostImage({
    super.key,
    required this.mediaRef,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String? mediaRef;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final ref = mediaRef;
    if (ref == null || ref.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined),
      );
    }
    Widget img;
    if (socialMediaIsRemoteUrl(ref)) {
      img = Image.network(
        ref,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey.shade300,
          child: const Icon(Icons.broken_image_outlined),
        ),
      );
    } else {
      final auth = context.watch<AuthCubit>().state;
      if (auth is! AuthAuthenticated) {
        img = Container(
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const Icon(Icons.lock_outline),
        );
      } else {
        final base = context.read<ApiConfig>().baseUrl;
        final url = socialMediaResolveUrl(base, ref);
        img = Image.network(
          url,
          fit: fit,
          headers: {'Authorization': 'Bearer ${auth.accessToken}'},
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey.shade300,
            child: const Icon(Icons.broken_image_outlined),
          ),
        );
      }
    }
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: img);
    }
    return img;
  }
}

/// Inline video from URL or object key (authenticated GET stream).
class SocialPostVideo extends StatefulWidget {
  const SocialPostVideo({super.key, required this.mediaRef});

  final String? mediaRef;

  @override
  State<SocialPostVideo> createState() => _SocialPostVideoState();
}

class _SocialPostVideoState extends State<SocialPostVideo> {
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _init();
    });
  }

  Future<void> _init() async {
    final ref = widget.mediaRef;
    if (ref == null || ref.isEmpty) {
      setState(() => _error = 'no media');
      return;
    }
    if (!mounted) return;
    final base = context.read<ApiConfig>().baseUrl;
    final auth = context.read<AuthCubit>().state;
    final Map<String, String> headers = {};
    String url;
    if (socialMediaIsRemoteUrl(ref)) {
      url = ref;
    } else {
      if (auth is! AuthAuthenticated) {
        setState(() => _error = 'auth');
        return;
      }
      headers['Authorization'] = 'Bearer ${auth.accessToken}';
      url = socialMediaResolveUrl(base, ref);
    }
    final c = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: headers,
    );
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      c.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() => _controller = c);
    } catch (e) {
      await c.dispose();
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        height: 200,
        color: Colors.grey.shade300,
        alignment: Alignment.center,
        child: const Icon(Icons.videocam_off_outlined, size: 48),
      );
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return AspectRatio(
      aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(c),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  c.value.isPlaying ? c.pause() : c.play();
                });
              },
              child: AnimatedOpacity(
                opacity: c.value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: Colors.black26,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.play_arrow,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
