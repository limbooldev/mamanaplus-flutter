import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/api_config.dart';
import 'router/app_routes.dart';
import 'features/chat/data/chat_repository.dart';
import 'features/chat/presentation/cubit/auth_cubit.dart';
import 'features/chat/presentation/pages/group_create_page.dart';
import 'features/chat/presentation/pages/group_detail_page.dart';
import 'features/chat/presentation/pages/inbox_page.dart';
import 'features/chat/presentation/pages/login_page.dart';
import 'features/chat/presentation/pages/thread_page.dart';

String _initialLocationFor(AuthState s) {
  if (s is AuthAuthenticated) return AppRoutes.inbox;
  if (s is AuthLoading || s is AuthInitial) return AppRoutes.splash;
  return AppRoutes.login;
}

/// Root widget: auth-aware routing + WebSocket lifecycle.
///
/// [GoRouter] is created once ([StatefulWidget]) so rebuilds do not reset the
/// route stack and strand the app on `/splash`.
class MamanaApp extends StatefulWidget {
  const MamanaApp({
    super.key,
    required this.authCubit,
    required this.config,
    required this.chatRepository,
  });

  final AuthCubit authCubit;
  final ApiConfig config;
  final ChatRepository chatRepository;

  @override
  State<MamanaApp> createState() => _MamanaAppState();
}

class _MamanaAppState extends State<MamanaApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final auth = widget.authCubit;
    final start = _initialLocationFor(auth.state);
    _router = GoRouter(
      initialLocation: start,
      refreshListenable: auth.notifier,
      redirect: (context, state) {
        final s = auth.state;
        final loc = state.matchedLocation;
        if (s is AuthLoading || s is AuthInitial) {
          return loc == AppRoutes.splash ? null : AppRoutes.splash;
        }
        if (s is AuthUnauthenticated || s is AuthFailure) {
          if (loc == AppRoutes.login) return null;
          return AppRoutes.login;
        }
        if (s is AuthAuthenticated) {
          if (loc == AppRoutes.login || loc == AppRoutes.splash) return AppRoutes.inbox;
          return null;
        }
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          builder: (_, __) => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, __) => const LoginPage(),
        ),
        GoRoute(
          path: AppRoutes.inbox,
          builder: (_, __) => const InboxPage(),
        ),
        GoRoute(
          path: AppRoutes.threadPattern,
          builder: (context, state) {
            final authed = auth.state;
            if (authed is! AuthAuthenticated) {
              return const SizedBox.shrink();
            }
            final id = int.parse(state.pathParameters[AppRoutes.threadParamId]!);
            final extra = state.extra as ThreadRouteExtra?;
            return ThreadPage(
              conversationId: id,
              accessToken: authed.accessToken,
              conversationType: extra?.conversationType,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.groupDetailPattern,
          builder: (context, state) {
            final authed = auth.state;
            if (authed is! AuthAuthenticated) {
              return const SizedBox.shrink();
            }
            final id = int.parse(state.pathParameters[AppRoutes.groupDetailParamId]!);
            return GroupDetailPage(conversationId: id);
          },
        ),
        GoRoute(
          path: AppRoutes.groupNew,
          builder: (_, __) => const GroupCreatePage(),
        ),
      ],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = widget.authCubit.state;
      if (s is AuthAuthenticated) {
        widget.chatRepository.socket.connect(widget.config.wsUrl, s.accessToken);
        widget.chatRepository.registerPush(token: 'stub-device-token');
      }
    });
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  void _syncRouteToAuth(AuthState state) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (state) {
        case AuthAuthenticated():
          _router.go(AppRoutes.inbox);
        case AuthUnauthenticated():
        case AuthFailure():
          _router.go(AppRoutes.login);
        case AuthLoading():
        case AuthInitial():
          _router.go(AppRoutes.splash);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          widget.chatRepository.socket.connect(widget.config.wsUrl, state.accessToken);
          widget.chatRepository.registerPush(token: 'stub-device-token');
        }
        if (state is AuthUnauthenticated) {
          widget.chatRepository.socket.disconnect();
        }
        _syncRouteToAuth(state);
      },
      child: MaterialApp.router(
        title: 'MamanaPlus',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        routerConfig: _router,
      ),
    );
  }
}
