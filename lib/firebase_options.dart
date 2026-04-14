// Replace this file with the output of `dart run flutterfire_cli:flutterfire configure`
// before using real FCM delivery. Placeholders allow the app to compile.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for mobile. Run FlutterFire configure for production.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase has not been configured for web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase has not been configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB7YiSXx5IYgly_rR8R_z3DGtaLupFGDls',
    appId: '1:1032889903903:android:68b878a6dd17332fe01e2a',
    messagingSenderId: '1032889903903',
    projectId: 'mamana-plus',
    storageBucket: 'mamana-plus.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAWdB1bQTdHJkeVy-J8frtFJOyn7qUyiWI',
    appId: '1:1032889903903:ios:c7b684fa2701b7cde01e2a',
    messagingSenderId: '1032889903903',
    projectId: 'mamana-plus',
    storageBucket: 'mamana-plus.firebasestorage.app',
    androidClientId: '1032889903903-34jfjrht7im89lotfon237evuftcokb6.apps.googleusercontent.com',
    iosClientId: '1032889903903-qoj49epftip8dm7bjdo07egeiu1a09nl.apps.googleusercontent.com',
    iosBundleId: 'com.mamanaplus.ios',
  );

}