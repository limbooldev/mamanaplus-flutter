import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Single source of truth for in-app route locations (go_router paths).
abstract final class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const inbox = '/inbox';
  static const groupNew = '/groups/new';

  /// [GoRoute.path] template for a conversation thread.
  static const threadPattern = '/thread/:id';

  /// [GoRouteState.pathParameters] key for [threadPattern].
  static const threadParamId = 'id';

  static String thread(int conversationId) => '/thread/$conversationId';
}

extension AppNavigation on BuildContext {
  void goSplash() => go(AppRoutes.splash);
  void goLogin() => go(AppRoutes.login);
  void goInbox() => go(AppRoutes.inbox);

  Future<T?> pushNewGroup<T extends Object?>() => push<T>(AppRoutes.groupNew);

  Future<T?> pushThread<T extends Object?>(int conversationId) =>
      push<T>(AppRoutes.thread(conversationId));
}
