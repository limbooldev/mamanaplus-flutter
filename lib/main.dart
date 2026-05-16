import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'app.dart';
import 'package:provider/provider.dart';

import 'core/api_config.dart';
import 'core/crash_reporting.dart';
import 'core/database/app_database.dart';
import 'core/token_storage.dart';
import 'features/chat/data/chat_mute_prefs.dart';
import 'features/chat/data/chat_remote_datasource.dart';
import 'features/chat/data/chat_repository.dart';
import 'features/chat/data/chat_socket.dart';
import 'features/chat/presentation/cubit/auth_cubit.dart';
import 'features/chat/presentation/cubit/theme_cubit.dart';
import 'features/social/data/social_repository.dart';
import 'features/social/data/story_seen_local_store.dart';
import 'core/notification_dismiss.dart';
import 'core/push_messaging.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (_) {}

  var firebaseReady = false;
  if (Platform.isAndroid || Platform.isIOS) {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    firebaseReady = await initializeFirebaseCore();
    await initNotificationDismiss();
  }
  setupCrashReporting(firebaseInitialized: firebaseReady);

  await runZonedGuarded(
    () async {
      final config = ApiConfig.fromEnvironment();
      final tokens = TokenStorage();
      final db = AppDatabase();
      final auth = AuthCubit(config: config, tokens: tokens);
      final dio = auth.apiDio;
      final remote = ChatRemoteDataSource(dio);
      final socket = ChatSocket();
      final repo = ChatRepository(
        remote: remote,
        db: db,
        socket: socket,
        tokens: tokens,
      );
      auth.beforeLogout = () async {
        await repo.unregisterPush();
      };
      await auth.restore();

      final prefs = await SharedPreferences.getInstance();
      final themeCubit = ThemeCubit(prefs);
      final mutePrefs = ChatMutePrefs(prefs);
      final storySeenStore = StorySeenLocalStore(prefs);

      runApp(
        Provider<ApiConfig>.value(
          value: config,
          child: Provider<StorySeenLocalStore>.value(
            value: storySeenStore,
            child: Provider<ChatMutePrefs>.value(
              value: mutePrefs,
              child: RepositoryProvider<ChatRepository>.value(
                value: repo,
                child: MultiBlocProvider(
                  providers: [
                    BlocProvider<AuthCubit>.value(value: auth),
                    BlocProvider<ThemeCubit>.value(value: themeCubit),
                  ],
                  child: RepositoryProvider<SocialRepository>(
                    create: (ctx) => SocialRepository(
                      ctx.read<AuthCubit>().apiDio,
                      mediaApi: remote,
                      tokens: tokens,
                    ),
                    child: MamanaApp(
                      authCubit: auth,
                      config: config,
                      chatRepository: repo,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    (Object error, StackTrace stack) {
      reportUncaughtAsyncError(
        error,
        stack,
        firebaseReady: firebaseReady,
      );
    },
  );
}
