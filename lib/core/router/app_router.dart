import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/not_found/presentation/not_found_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import 'session_status.dart';

class AppRoutes {
  const AppRoutes._();

  static const home = '/';
}

/// A stable router instance whose redirect logic is refreshed when session
/// state changes. Recreating [GoRouter] on every authentication transition
/// would discard navigation state and could leak the previous router.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refreshNotifier,
    // Single choke point for route guarding: every route is currently
    // public, so the placeholder status is only read for now. Epic #3 will
    // add the authenticated/unauthenticated redirects here.
    redirect: (context, state) {
      ref.read(sessionStatusProvider);
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
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

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen<SessionStatus>(sessionStatusProvider, (previous, next) {
      notifyListeners();
    });
  }
}
