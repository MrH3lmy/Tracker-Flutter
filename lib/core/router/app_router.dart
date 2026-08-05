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

/// [routerProvider] rebuilds the [GoRouter] if [sessionStatusProvider]
/// changes, so once the authentication epic replaces that provider with a
/// real session controller, guarded routes redirect automatically without
/// further router changes.
final routerProvider = Provider<GoRouter>((ref) {
  ref.watch(sessionStatusProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    // Single choke point for route guarding: every route is currently
    // public, so `status` isn't branched on yet, but every navigation
    // already passes through here.
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
});
