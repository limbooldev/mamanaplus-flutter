import 'package:flutter_test/flutter_test.dart';
import 'package:mamana_plus/features/chat/presentation/widgets/thread_voice_recorder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ThreadVoiceRecorderController', () {
    late FakeVoiceRecorderBackend backend;
    String? sentPath;
    Duration? sentDuration;
    var cancelCount = 0;
    var permissionDeniedCount = 0;

    ThreadVoiceRecorderController newController() {
      backend = FakeVoiceRecorderBackend();
      return ThreadVoiceRecorderController(
        backend: backend,
        createTempVoicePath: () async => '/tmp/voice_test.m4a',
        enablePreviewPlayback: false,
        onSend: (path, duration) async {
          sentPath = path;
          sentDuration = duration;
        },
        onCancel: () => cancelCount++,
        onPermissionDenied: () => permissionDeniedCount++,
      );
    }

    tearDown(() {
      sentPath = null;
      sentDuration = null;
      cancelCount = 0;
      permissionDeniedCount = 0;
    });

    test('beginRecording moves to recording state', () async {
      final c = newController();
      addTearDown(c.dispose);

      await c.beginRecording();

      expect(c.state, VoiceRecorderUiState.recording);
      expect(backend.isRecording, isTrue);
      expect(backend.lastPath, '/tmp/voice_test.m4a');
    });

    test('release without drag sends voice', () async {
      final c = newController();
      addTearDown(c.dispose);

      await c.beginRecording();
      await c.onPointerUp();

      expect(c.state, VoiceRecorderUiState.idle);
      expect(sentPath, '/tmp/voice_test.m4a');
      expect(sentDuration, isNotNull);
      expect(backend.isRecording, isFalse);
    });

    test('slide left past threshold cancels recording', () async {
      final c = newController();
      addTearDown(c.dispose);

      await c.beginRecording();
      c.updateDragFromStart(
        const Offset(-ThreadVoiceRecorderController.cancelDragThreshold, 0),
        isRtl: false,
      );
      expect(c.cancelArmed, isTrue);
      await c.onPointerUp();

      expect(c.state, VoiceRecorderUiState.idle);
      expect(sentPath, isNull);
      expect(cancelCount, 1);
    });

    test('slide up past threshold locks recording', () async {
      final c = newController();
      addTearDown(c.dispose);

      await c.beginRecording();
      c.updateDragFromStart(
        const Offset(0, -ThreadVoiceRecorderController.lockDragThreshold),
        isRtl: false,
      );
      expect(c.lockArmed, isTrue);
      await c.onPointerUp();

      expect(c.state, VoiceRecorderUiState.locked);
      expect(backend.isRecording, isTrue);
      expect(sentPath, isNull);
    });

    test('locked send finishes recording', () async {
      final c = newController();
      addTearDown(c.dispose);

      await c.beginRecording();
      c.updateDragFromStart(
        const Offset(0, -ThreadVoiceRecorderController.lockDragThreshold),
        isRtl: false,
      );
      await c.onPointerUp();
      await c.sendRecording();

      expect(c.state, VoiceRecorderUiState.idle);
      expect(sentPath, '/tmp/voice_test.m4a');
    });

    test('locked pause enters preview state', () async {
      final c = newController();
      addTearDown(c.dispose);

      await c.beginRecording();
      c.updateDragFromStart(
        const Offset(0, -ThreadVoiceRecorderController.lockDragThreshold),
        isRtl: false,
      );
      await c.onPointerUp();
      await c.enterPreview();

      expect(c.state, VoiceRecorderUiState.preview);
      expect(backend.isRecording, isFalse);
    });

    test('permission denied does not start recording', () async {
      final c = newController();
      addTearDown(c.dispose);
      backend.permissionGranted = false;

      await c.beginRecording();

      expect(c.state, VoiceRecorderUiState.idle);
      expect(permissionDeniedCount, 1);
      expect(backend.isRecording, isFalse);
    });

    test('auto sends when max recording duration is reached', () async {
      final c = newController();
      addTearDown(c.dispose);

      await c.beginRecording();
      expect(c.state, VoiceRecorderUiState.recording);

      final maxSeconds = ThreadVoiceRecorderController.maxRecordingDuration.inSeconds;
      for (var i = 0; i < maxSeconds; i++) {
        c.tickRecordingSecondForTest();
      }
      await Future<void>.delayed(Duration.zero);

      expect(c.state, VoiceRecorderUiState.idle);
      expect(sentPath, '/tmp/voice_test.m4a');
      expect(sentDuration, ThreadVoiceRecorderController.maxRecordingDuration);
      expect(backend.isRecording, isFalse);
    });

    test('formatVoiceDuration formats mm:ss', () {
      expect(formatVoiceDuration(const Duration(seconds: 37)), '0:37');
      expect(formatVoiceDuration(const Duration(minutes: 1, seconds: 5)), '1:05');
    });
  });
}
