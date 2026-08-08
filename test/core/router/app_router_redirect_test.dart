import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/config/app_config.dart';
import 'package:tracker_flutter/core/config/app_environment.dart';
import 'package:tracker_flutter/core/di/app_providers.dart';
import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/core/router/app_router.dart';
import 'package:tracker_flutter/core/router/session_status.dart';
import 'package:tracker_flutter/features/auth/data/auth_api.dart';
import 'package:tracker_flutter/features/auth/data/auth_result.dart';
import 'package:tracker_flutter/features/auth/data/client_platform.dart';
import 'package:tracker_flutter/features/auth/data/secure_token_storage.dart';
import 'package:tracker_flutter/features/auth/domain/user.dart';
import 'package:tracker_flutter/features/projects/data/project_selection_store.dart';
import 'package:tracker_flutter/features/projects/data/projects_repository.dart';
import 'package:tracker_flutter/src/app.dart';

import '../../helpers/fake_auth_api.dart';
import '../../helpers/fake_project_selection_store.dart';
import '../../helpers/fake_projects_repository.dart';
import '../../helpers/fake_secure_token_storage.dart';

const _user = User(
  id: 1,
  email: 'a@b.com',
  displayName: null,
  tier: UserTier.free,
  role: UserRole.user,
);

void main() {
  Widget app(SessionStatus status) => ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.fromEnvironment(AppEnvironment.local),
      ),
      sessionStatusProvider.overrideWithValue(status),
      // An `authenticated` status renders the shell -> ProjectsScreen,
      // which scopes its project provider to authRepositoryProvider's
      // user id regardless of the sessionStatus override above — a
      // stored native token makes AuthRepository authenticate on startup
      // without an explicit login call.
      authApiProvider.overrideWithValue(
        FakeAuthApi()
          ..refreshResult = Result.success(
            const AuthResult(
              accessToken: 'access',
              refreshToken: 'refresh',
              user: _user,
            ),
          ),
      ),
      secureTokenStorageProvider.overrideWithValue(
        FakeSecureTokenStorage(initialToken: 'stored-token'),
      ),
      clientPlatformProvider.overrideWithValue(ClientPlatform.android),
      projectSelectionStoreProvider.overrideWithValue(
        FakeProjectSelectionStore(),
      ),
      projectsRepositoryProvider.overrideWithValue(
        FakeProjectsRepository()..fetchResult = const Result.success([]),
      ),
    ],
    child: const TrackerApp(),
  );

  testWidgets('unknown holds the app on the splash screen', (tester) async {
    await tester.pumpWidget(app(SessionStatus.unknown));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Tracker'), findsNothing);
  });

  testWidgets('unauthenticated redirects to the sign-in screen', (
    tester,
  ) async {
    await tester.pumpWidget(app(SessionStatus.unauthenticated));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets(
    'authenticated users are bounced away from the sign-in route back to home',
    (tester) async {
      await tester.pumpWidget(app(SessionStatus.authenticated));
      await tester.pumpAndSettle();

      final router = ProviderScope.containerOf(
        tester.element(find.byType(TrackerApp)),
      ).read(routerProvider);
      router.go(AppRoutes.signIn);
      await tester.pumpAndSettle();

      expect(find.text('Tracker'), findsWidgets);
      expect(find.text('Sign in'), findsNothing);
    },
  );

  testWidgets('unauthenticated users cannot navigate straight to home', (
    tester,
  ) async {
    await tester.pumpWidget(app(SessionStatus.unauthenticated));
    await tester.pumpAndSettle();

    final router = ProviderScope.containerOf(
      tester.element(find.byType(TrackerApp)),
    ).read(routerProvider);
    router.go(AppRoutes.home);
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
  });
}
