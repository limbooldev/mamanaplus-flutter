import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

/// Client-side limits aligned with backend caps in `internal/storage/limits.go`.
abstract final class MediaUploadLimits {
  static const maxImageDimension = 1280;
  static const imageQuality = 80;
  static const skipImageCompressionBelowBytes = 300 * 1024;
  static const maxVideoDurationMs = 60 * 1000;
  static const maxVideoDurationSec = 60;
  static const largeFileWarningBytes = 10 * 1024 * 1024;
}

class VideoDurationExceededException implements Exception {
  VideoDurationExceededException(this.durationMs);

  final int durationMs;

  @override
  String toString() =>
      'Video is ${(durationMs / 1000).ceil()}s long; max is '
      '${MediaUploadLimits.maxVideoDurationSec}s.';
}

class ProcessedVideoUpload {
  const ProcessedVideoUpload({
    required this.path,
    required this.mimeType,
    required this.durationMs,
  });

  final String path;
  final String mimeType;
  final int durationMs;
}

/// Compresses and validates chat/social media before upload.
abstract final class MediaUploadProcessor {
  static bool isCompressibleImageMime(String mime) {
    final lower = mime.toLowerCase();
    return lower == 'image/jpeg' ||
        lower == 'image/png' ||
        lower == 'image/webp';
  }

  static bool isVideoMime(String mime) {
    final lower = mime.toLowerCase();
    return lower.startsWith('video/') || lower == 'application/mp4';
  }

  /// Returns true when the raw file is large enough to warn before upload.
  static Future<bool> shouldWarnLargeFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    final len = await file.length();
    return len > MediaUploadLimits.largeFileWarningBytes;
  }

  /// Reads video metadata and throws [VideoDurationExceededException] when over limit.
  static Future<int> readVideoDurationMs(String path) async {
    final info = await VideoCompress.getMediaInfo(path);
    final durationMs = info.duration?.toInt() ?? 0;
    if (durationMs > MediaUploadLimits.maxVideoDurationMs) {
      throw VideoDurationExceededException(durationMs);
    }
    return durationMs;
  }

  /// Transcodes video to ~720p medium quality for network upload.
  static Future<ProcessedVideoUpload> compressVideoForUpload(String path) async {
    final durationMs = await readVideoDurationMs(path);

    await VideoCompress.setLogLevel(0);
    final info = await VideoCompress.compressVideo(
      path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
      includeAudio: true,
    );
    if (info == null || info.path == null || info.path!.isEmpty) {
      throw StateError('Video compression failed');
    }

    final outDuration = info.duration?.toInt();
    return ProcessedVideoUpload(
      path: info.path!,
      mimeType: 'video/mp4',
      durationMs: outDuration != null && outDuration > 0
          ? outDuration
          : durationMs,
    );
  }

  /// Resizes/re-encodes image bytes. Skips small JPEGs that are already optimized.
  static Future<({List<int> bytes, String mimeType})> compressImageBytes(
    List<int> bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    if (!isCompressibleImageMime(mimeType)) {
      return (bytes: bytes, mimeType: mimeType);
    }

    final lower = mimeType.toLowerCase();
    if (lower == 'image/jpeg' &&
        bytes.length <= MediaUploadLimits.skipImageCompressionBelowBytes) {
      return (bytes: bytes, mimeType: mimeType);
    }

    final compressed = await FlutterImageCompress.compressWithList(
      Uint8List.fromList(bytes),
      minWidth: MediaUploadLimits.maxImageDimension,
      minHeight: MediaUploadLimits.maxImageDimension,
      quality: MediaUploadLimits.imageQuality,
      format: CompressFormat.jpeg,
    );
    if (compressed.isEmpty) {
      return (bytes: bytes, mimeType: mimeType);
    }
    return (bytes: compressed, mimeType: 'image/jpeg');
  }

  /// Compresses an on-disk image to a temp JPEG file.
  static Future<({String path, String mimeType})> compressImageFile(
    String path, {
    String mimeType = 'image/jpeg',
  }) async {
    final bytes = await File(path).readAsBytes();
    final result = await compressImageBytes(bytes, mimeType: mimeType);
    if (identical(result.bytes, bytes)) {
      return (path: path, mimeType: mimeType);
    }
    final dir = await getTemporaryDirectory();
    final out = File(
      p.join(
        dir.path,
        'upload_img_${DateTime.now().microsecondsSinceEpoch}.jpg',
      ),
    );
    await out.writeAsBytes(result.bytes, flush: true);
    return (path: out.path, mimeType: result.mimeType);
  }
}
