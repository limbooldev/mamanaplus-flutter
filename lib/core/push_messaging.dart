import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../firebase_options.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/chat/presentation/cubit/auth_cubit.dart';
import '../router/app_routes.dart';

bool _firebaseReady = false;
bool _pushListenersBound = false;

/// Background handler must be a top-level or static function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<bool> initializeFirebaseCore() async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return false;
  }
  if (_firebaseReady) {
    return true;
  }
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseReady = true;
    return true;
  } catch (e, st) {
    debugPrint('Firebase.initializeApp failed: $e\n$st');
    return false;
  }
}

/// Registers FCM token with backend, wires taps and refresh.
Future<void> setupPushForAuthenticatedUser({
  required ChatRepository chatRepository,
  required AuthCubit authCubit,
  required GoRouter router,
}) async {
  if (!_firebaseReady) {
    return;
  }
  final messaging = FirebaseMessaging.instance;
  await messaging.setAutoInitEnabled(true);
  // iOS: required for alerts. Android 13+: maps to POST_NOTIFICATIONS runtime prompt.
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  final token = await messaging.getToken();
  if (token != null && token.isNotEmpty) {
    await chatRepository.registerPush(token: token);
  }
  if (!_pushListenersBound) {
    _pushListenersBound = true;
    messaging.onTokenRefresh.listen((t) {
      if (authCubit.state is AuthAuthenticated) {
        chatRepository.registerPush(token: t);
      }
    });
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (authCubit.state is! AuthAuthenticated) {
        return;
      }
      final cid = int.tryParse(message.data['conversation_id'] ?? '');
      if (cid == null) {
        return;
      }
      chatRepository.syncConversationsFromRemote();
    });
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      _openConversationFromData(m.data, authCubit: authCubit, router: router);
    });
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openConversationFromData(
          initial.data,
          authCubit: authCubit,
          router: router,
        );
      });
    }
  }
}

void _openConversationFromData(
  Map<String, dynamic> data, {
  required AuthCubit authCubit,
  required GoRouter router,
}) {
  if (authCubit.state is! AuthAuthenticated) {
    return;
  }
  final raw = data['conversation_id'];
  final sid = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
  if (sid == null || sid <= 0) {
    return;
  }
  router.go(AppRoutes.thread(sid));
}
