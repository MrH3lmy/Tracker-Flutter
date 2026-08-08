import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/not_found/presentation/not_found_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import 'session_status.dart';

class AppRoutes {
  const AppRoutes._();

  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const register = '/register';
  static const home = '/';
}

/// A stable router instance whose redirect logic is refreshed when session
/// state changes. Recreating [GoRouter] on every authentication transition
/// would discard navigation state and could leak the previous router.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    // Single choke point for route guarding, run on every navigation
    // (including the very first one). [SessionStatus.unknown] covers the
    // window while a stored/cookie credential is still being checked at
    // startup — routes are held on the splash screen rather than briefly
    // rendering the authenticated shell or bouncing to sign-in first.
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
