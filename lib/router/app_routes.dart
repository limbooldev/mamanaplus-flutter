import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Single source of truth for in-app route locations (go_router paths).
abstract final class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const inbox = '/inbox';
  static const groupNew = '/groups/new';

  /// Group info (members); numeric id only — keep distinct from [groupNew].
  static const groupDetailPattern = '/groups/detail/:gid';
  static const groupDetailParamId = 'gid';

  static String groupDetail(int conversationId) => '/groups/detail/$conversationId';

  /// [GoRoute.path] template for a conversation thread.
  static const threadPattern = '/thread/:id';

  /// [GoRouteState.pathParameters] key for [threadPattern].
  static const threadParamId = 'id';

  static String thread(int conversationId) => '/thread/$conversationId';
}

/// Extra passed with [AppNavigation.pushThread].
final class ThreadRouteExtra {
  const ThreadRouteExtra({this.conversationType});

  /// `private` or `group` from [LocalConversation.type].
  final String? conversationType;
}

extension AppNavigation on BuildContext {
  void goSplash() => go(AppRoutes.splash);
  void goLogin() => go(AppRoutes.login);
  void goInbox() => go(AppRoutes.inbox);

  Future<T?> pushNewGroup<T extends Object?>() => push<T>(AppRoutes.groupNew);

  Future<T?> pushGroupDetail<T extends Object?>(int conversationId) =>
      push<T>(AppRoutes.groupDetail(conversationId));

  Future<T?> pushThread<T extends Object?>(
    int conversationId, {
    String? conversationType,
  }) =>
      push<T>(
        AppRoutes.thread(conversationId),
        extra: conversationType != null
            ? ThreadRouteExtra(conversationType: conversationType)
            : null,
      );
}
