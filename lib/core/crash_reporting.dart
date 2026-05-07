import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Installs global handlers after [Firebase.initializeApp] succeeds on mobile.
void setupCrashReporting({required bool firebaseInitialized}) {
  if (!firebaseInitialized || (!Platform.isAndroid && !Platform.isIOS)) {
    return;
  }

  FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

  FlutterError.onError = (FlutterErrorDetails details) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}

/// [runZonedGuarded] callback for async errors in the root zone.
void reportUncaughtAsyncError(
  Object error,
  StackTrace stack, {
  required bool firebaseReady,
}) {
  if (!firebaseReady) return;
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
}

/// Non-fatal Crashlytics event when Firebase Core is already initialized.
void reportCaughtError(Object error, StackTrace? stack) {
  if (Firebase.apps.isEmpty) return;
  FirebaseCrashlytics.instance.recordError(
    error,
    stack ?? StackTrace.current,
    fatal: false,
  );
}
