import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/board_columns/presentation/board_screen.dart';
import '../../features/not_found/presentation/not_found_screen.dart';
import '../../features/notes/presentation/notes_screen.dart';
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
  static const notes = '/notes';
  static const noteCreate = '/notes/new';
  static const noteDetailPattern = '/notes/:id';
  static const noteEditPattern = '/notes/:id/edit';

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
      final onAuthRoute = path == AppRoutes.signIn || path == AppRoutes.register;
      final onSplash = path == AppRoutes.splash;
      return switch (status) {
        SessionStatus.unknown => onSplash ? null : AppRoutes.splash,
        SessionStatus.unauthenticated => onAuthRoute ? null : AppRoutes.signIn,
        SessionStatus.authenticated => (onAuthRoute || onSplash) ? AppRoutes.home : null,
      };
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(path: AppRoutes.register, builder: (_, _) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(routerState: state, child: child),
        routes: [
          GoRoute(path: AppRoutes.home, builder: (_, _) => const ProjectsScreen()),
          GoRoute(path: AppRoutes.board, builder: (_, _) => const BoardScreen()),
          GoRoute(path: AppRoutes.tasks, builder: (_, _) => const TasksDestination()),
          GoRoute(path: AppRoutes.taskArchive, builder: (_, _) => const TaskArchiveScreen()),
          GoRoute(path: AppRoutes.taskCreate, builder: (_, _) => const TaskCreateDestination()),
          GoRoute(
            path: AppRoutes.taskEditPattern,
            builder: (_, state) {
              final id = _id(state);
              return id == null
                  ? const NotFoundScreen(message: 'Invalid task id.')
                  : SafeTaskEditScreen(taskId: id);
            },
          ),
          GoRoute(
            path: AppRoutes.taskDetailPattern,
            builder: (_, state) {
              final id = _id(state);
              return id == null
                  ? const NotFoundScreen(message: 'Invalid task id.')
                  : TaskLifecycleDetailScreen(taskId: id);
            },
          ),
          GoRoute(path: AppRoutes.notes, builder: (_, _) => const NotesScreen()),
          GoRoute(path: AppRoutes.noteCreate, builder: (_, _) => const NoteFormScreen()),
          GoRoute(
            path: AppRoutes.noteEditPattern,
            builder: (_, state) {
              final id = _id(state);
              return id == null
                  ? const NotFoundScreen(message: 'Invalid note id.')
                  : NoteFormScreen(noteId: id);
            },
          ),
          GoRoute(
            path: AppRoutes.noteDetailPattern,
            builder: (_, state) {
              final id = _id(state);
              return id == null
                  ? const NotFoundScreen(message: 'Invalid note id.')
                  : NoteDetailScreen(noteId: id);
            },
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => NotFoundScreen(message: "No page matches '${state.uri}'."),
  );

  ref.onDispose(() {
    router.dispose();
    refreshNotifier.dispose();
  });
  return router;
});

int? _id(GoRouterState state) => int.tryParse(state.pathParameters['id'] ?? '');

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen<SessionStatus>(sessionStatusProvider, (previous, next) => notifyListeners());
  }
}
