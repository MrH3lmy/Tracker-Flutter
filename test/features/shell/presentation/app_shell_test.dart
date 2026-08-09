import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tracker_flutter/core/error/app_failure.dart';
import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/auth/data/auth_api.dart';
import 'package:tracker_flutter/features/auth/data/auth_repository.dart';
import 'package:tracker_flutter/features/auth/data/auth_result.dart';
import 'package:tracker_flutter/features/auth/data/client_platform.dart';
import 'package:tracker_flutter/features/auth/data/secure_token_storage.dart';
import 'package:tracker_flutter/features/auth/domain/user.dart';
import 'package:tracker_flutter/features/shell/presentation/app_shell.dart';

import '../../../helpers/fake_auth_api.dart';
import '../../../helpers/fake_secure_token_storage.dart';

const _user = User(
  id: 1,
  email: 'signed-in@example.com',
  displayName: null,
  tier: UserTier.free,
  role: UserRole.user,
);

void main() {
  Future<FakeAuthApi> pumpSignedIn(WidgetTester tester) async {
    final authApi = FakeAuthApi()
      ..refreshResult = const Result.failure(UnauthorizedFailure())
      ..loginResult = Result.success(
        AuthResult(accessToken: 'access', refreshToken: 'refresh', user: _user),
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWithValue(authApi),
          secureTokenStorageProvider.overrideWithValue(
            FakeSecureTokenStorage(),
          ),
          clientPlatformProvider.overrideWithValue(ClientPlatform.android),
        ],
        // AppShell needs a real GoRouterState (it computes selectedIndex
        // from the matched location) and a GoRouter ancestor for
        // onDestinationSelected's context.go to work, so this pumps it
        // through a minimal router the same way production's ShellRoute
        // does rather than constructing GoRouterState by hand.
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => AppShell(
                  routerState: state,
                  child: const SizedBox.shrink(),
                ),
              ),
              GoRoute(
                path: '/board',
                builder: (context, state) => AppShell(
                  routerState: state,
                  child: const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
    );
    await container.read(authRepositoryProvider.notifier).startupRestoration;
    await container
        .read(authRepositoryProvider.notifier)
        .login(email: _user.email, password: 'password');
    await tester.pumpAndSettle();
    return authApi;
  }

  testWidgets('shows the Projects and Board destinations and the app title', (
    tester,
  ) async {
    await pumpSignedIn(tester);

    expect(find.text('Tracker'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Board'), findsOneWidget);
  });

  testWidgets('tapping the Board destination navigates to /board', (
    tester,
  ) async {
    await pumpSignedIn(tester);

    // Tapped by icon, not by the "Board" label text: at this test surface's
    // default (medium) width, AdaptiveScaffold's NavigationRail only shows
    // a label under the *selected* destination, so the unselected "Board"
    // label exists in the tree but isn't the widget that receives the tap.
    await tester.tap(find.byIcon(Icons.view_column_outlined));
    await tester.pumpAndSettle();

    // No app-level routerProvider is wired up in this focused shell test
    // (unlike app_router_redirect_test.dart), so assert against the
    // GoRouter instance AppShell actually navigated through instead.
    final goRouter = GoRouter.of(tester.element(find.byType(AppShell)));
    expect(goRouter.state.matchedLocation, '/board');
  });

  testWidgets('the account menu shows the signed-in user\'s email', (
    tester,
  ) async {
    await pumpSignedIn(tester);

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();

    expect(find.text('signed-in@example.com'), findsOneWidget);
  });

  testWidgets('sign out calls AuthRepository.logout', (tester) async {
    final authApi = await pumpSignedIn(tester);
    authApi.logoutResult = const Result.success(null);

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(authApi.logoutCalls, 1);
  });

  testWidgets('sign out everywhere calls AuthRepository.logoutAll', (
    tester,
  ) async {
    final authApi = await pumpSignedIn(tester);
    authApi.logoutAllResult = const Result.success(null);

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out everywhere'));
    await tester.pumpAndSettle();

    expect(authApi.logoutAllCalls, 1);
  });
}
