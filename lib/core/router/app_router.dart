import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/board_columns/presentation/board_screen.dart';
import '../../features/not_found/presentation/not_found_screen.dart';
import '../../features/projects/presentation/projects_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/shell/presentation/task_destinations.dart';
import '../../features/tasks/presentation/task_archive_screen.dart';
import '../../features/tasks/presentation/task_edit_screen.dart';
import '../../features/tasks/presentation/task_lifecycle_detail_screen.dart';
import 'session_status.dart';

class AppRoutes {
  const AppRoutes._();

  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const register = '/register';
  static const home = '/';
  static const board = '/board';
  static const tasks = '/tasks';
  static const taskArchive = '/tasks/archive';
  static const taskCreate = '/tasks/new';
  static const taskDetailPattern = '/tasks/:id';
  static const taskEditPattern = '/tasks/:id/edit';

  static String taskDetail(int id) => '/tasks/$id';
  static String taskEdit(int id) => '/tasks/$id/edit';
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final status = ref.read(sessionStatusProvider);
      final path = state.matchedLocation;
      final onAuthRoute =
          path == AppRoutes.signIn || path == AppRoutes.register;
      final onSplash = path == AppRoutes.splash;

      return switch (status) {
        SessionStatus.unknown => onSplash ? null : AppRoutes.splash,
        SessionStatus.unauthenticated => onAuthRoute ? null : AppRoutes.signIn,
        SessionStatus.authenticated =>
          (onAuthRoute || onSplash) ? AppRoutes.home : null,
      };
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(routerState: state, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const ProjectsScreen(),
          ),
          GoRoute(
            path: AppRoutes.board,
            builder: (context, state) => const BoardScreen(),
          ),
          GoRoute(
            path: AppRoutes.tasks,
            builder: (context, state) => const TasksDestination(),
          ),
          GoRoute(
            path: AppRoutes.taskArchive,
            builder: (context, state) => const TaskArchiveScreen(),
          ),
          GoRoute(
            path: AppRoutes.taskCreate,
            builder: (context, state) => const TaskCreateDestination(),
          ),
          GoRoute(
            path: AppRoutes.taskEditPattern,
            builder: (context, state) {
              final taskId = _taskId(state);
              return taskId == null
                  ? const NotFoundScreen(message: 'Invalid task id.')
                  : SafeTaskEditScreen(taskId: taskId);
            },
          ),
          GoRoute(
            path: AppRoutes.taskDetailPattern,
            builder: (context, state) {
              final taskId = _taskId(state);
              return taskId == null
                  ? const NotFoundScreen(message: 'Invalid task id.')
                  : TaskLifecycleDetailScreen(taskId: taskId);
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        NotFoundScreen(message: "No page matches '${state.uri}'."),
  );

  ref.onDispose(() {
    router.dispose();
    refreshNotifier.dispose();
  });

  return router;
});

int? _taskId(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '');

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen<SessionStatus>(sessionStatusProvider, (previous, next) {
      notifyListeners();
    });
  }
}
