import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'app.dart';
import 'core/api_config.dart';
import 'core/database/app_database.dart';
import 'core/dio_client.dart';
import 'core/token_storage.dart';
import 'features/chat/data/chat_remote_datasource.dart';
import 'features/chat/data/chat_repository.dart';
import 'features/chat/data/chat_socket.dart';
import 'features/chat/presentation/cubit/auth_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid || Platform.isIOS) {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }

  final config = ApiConfig.fromEnvironment();
  final tokens = TokenStorage();
  final db = AppDatabase();
  final dio = createDio(config: config, tokens: tokens);
  final remote = ChatRemoteDataSource(dio);
  final socket = ChatSocket();
  final repo = ChatRepository(remote: remote, db: db, socket: socket, tokens: tokens);
  final auth = AuthCubit(config: config, tokens: tokens);
  await auth.restore();

  runApp(
    RepositoryProvider<ChatRepository>.value(
      value: repo,
      child: BlocProvider<AuthCubit>.value(
        value: auth,
        child: MamanaApp(
          authCubit: auth,
          config: config,
          chatRepository: repo,
        ),
      ),
    ),
  );
}
