import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final _plugin = FlutterLocalNotificationsPlugin();
bool _initialized = false;

Future<void> initNotificationDismiss() async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return;
  }
  if (_initialized) {
    return;
  }
  await _plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );
  _initialized = true;
}

/// Removes push notifications for [conversationId] from the system tray.
///
/// Android: cancels by tag `conv-<id>` (matches backend FCM notification tag).
/// iOS: clears all delivered notifications (APNs collapse id is not exposed to Flutter).
Future<void> dismissConversationNotification(int conversationId) async {
  if (!_initialized) {
    return;
  }
  if (Platform.isAndroid) {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.cancel(0, tag: 'conv-$conversationId');
  } else if (Platform.isIOS) {
    await _plugin.cancelAll();
  }
}
