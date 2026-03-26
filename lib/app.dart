import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/api_config.dart';
import 'features/chat/data/chat_repository.dart';
import 'features/chat/presentation/cubit/auth_cubit.dart';
import 'features/chat/presentation/pages/group_create_page.dart';
import 'features/chat/presentation/pages/inbox_page.dart';
import 'features/chat/presentation/pages/login_page.dart';
import 'features/chat/presentation/pages/thread_page.dart';

String _initialLocationFor(AuthState s) {
  if (s is AuthAuthenticated) return '/inbox';
  if (s is AuthLoading || s is AuthInitial) return '/splash';
  return '/login';
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
          return loc == '/splash' ? null : '/splash';
        }
        if (s is AuthUnauthenticated || s is AuthFailure) {
          if (loc == '/login') return null;
          return '/login';
        }
        if (s is AuthAuthenticated) {
          if (loc == '/login' || loc == '/splash') return '/inbox';
          return null;
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, __) => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginPage(),
        ),
        GoRoute(
          path: '/inbox',
          builder: (_, __) => const InboxPage(),
        ),
        GoRoute(
          path: '/thread/:id',
          builder: (context, state) {
            final authed = auth.state;
            if (authed is! AuthAuthenticated) {
              return const SizedBox.shrink();
            }
            final id = int.parse(state.pathParameters['id']!);
            return ThreadPage(conversationId: id, accessToken: authed.accessToken);
          },
        ),
        GoRoute(
          path: '/groups/new',
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
