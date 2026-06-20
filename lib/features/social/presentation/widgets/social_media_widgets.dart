import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/api_config.dart';
import '../../../../shared/ui/ui.dart';
import '../../../chat/presentation/cubit/auth_cubit.dart';
import '../../data/social_repository.dart';

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

/// Resolves a cached media file path when already on disk (no download).
Future<File?> socialLookupCachedMediaFile(String objectKey) async {
  final root = await getTemporaryDirectory();
  final dir = Directory(p.join(root.path, 'media_cache'));
  final ext = p.extension(objectKey);
  final fallback = ext.isNotEmpty ? ext.replaceFirst('.', '') : 'mp4';
  final suffix = ext.isNotEmpty ? ext : '.$fallback';
  final safe = objectKey.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final file = File(p.join(dir.path, '$safe$suffix'));
  if (file.existsSync() && file.lengthSync() > 0) return file;
  return null;
}

/// Thumbnail / inline image: supports plain URLs and private object keys (Bearer).
///
/// Images are shown immediately via [Image.network]. For object keys, a disk
/// cache is populated in the background so subsequent opens within the same
/// session prefer [Image.file] over a network request.
class SocialPostImage extends StatefulWidget {
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
  State<SocialPostImage> createState() => _SocialPostImageState();
}

class _SocialPostImageState extends State<SocialPostImage> {
  File? _cachedFile;

  @override
  void initState() {
    super.initState();
    _warmCache();
  }

  @override
  void didUpdateWidget(SocialPostImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaRef != widget.mediaRef) {
      _cachedFile = null;
      _warmCache();
    }
  }

  /// Download to disk in the background; once done swap Image.network → Image.file.
  Future<void> _warmCache() async {
    final ref = widget.mediaRef;
    if (ref == null || ref.isEmpty || socialMediaIsRemoteUrl(ref)) return;
    try {
      final file = await context.read<SocialRepository>().downloadImageToCache(ref);
      if (mounted && file.existsSync()) {
        setState(() => _cachedFile = file);
      }
    } catch (_) {
      // Cache miss is non-fatal; Image.network below continues to serve the image.
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = widget.mediaRef;
    if (ref == null || ref.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined),
      );
    }

    final placeholder = Container(color: Colors.grey.shade200);
    final error = Container(
      color: Colors.grey.shade300,
      child: const Icon(Icons.broken_image_outlined),
    );

    Widget img;
    if (_cachedFile != null) {
      img = Image.file(
        _cachedFile!,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => error,
      );
    } else if (socialMediaIsRemoteUrl(ref)) {
      img = Image.network(
        ref,
        fit: widget.fit,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder,
        errorBuilder: (_, __, ___) => error,
      );
    } else {
      // Object key: show via authenticated network immediately while cache warms.
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
          fit: widget.fit,
          headers: {'Authorization': 'Bearer ${auth.accessToken}'},
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : placeholder,
          errorBuilder: (_, __, ___) => error,
        );
      }
    }

    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: img);
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

  @override
  void didUpdateWidget(SocialPostVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaRef != widget.mediaRef) {
      _controller?.dispose();
      _controller = null;
      _error = null;
      _init();
    }
  }

  Future<void> _warmCache(String objectKey) async {
    try {
      await context.read<SocialRepository>().downloadImageToCache(objectKey);
    } catch (_) {
      // Cache miss is non-fatal; network playback continues.
    }
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

    File? cachedFile;
    if (!socialMediaIsRemoteUrl(ref)) {
      cachedFile = await socialLookupCachedMediaFile(ref);
      if (cachedFile == null) {
        unawaited(_warmCache(ref));
      }
    }

    final c = cachedFile != null
        ? VideoPlayerController.file(cachedFile)
        : VideoPlayerController.networkUrl(
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

/// Circular profile photo with initials fallback (object key or remote URL).
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.displayName,
    this.avatarMediaKey,
    this.size = 48,
    this.isGroup = false,
  });

  final String displayName;
  final String? avatarMediaKey;
  final double size;
  final bool isGroup;

  String get _initial {
    final t = displayName.trim();
    if (t.isEmpty) return '?';
    return t[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final key = avatarMediaKey?.trim();
    if (key != null && key.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: SocialPostImage(mediaRef: key, fit: BoxFit.cover),
        ),
      );
    }
    final fontSize = size * 0.375;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isGroup
              ? [AppColors.primaryDeep, AppColors.primary]
              : [AppColors.primary, AppColors.primary.withValues(alpha: 0.75)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _initial,
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
