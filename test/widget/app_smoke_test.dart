import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/config/app_config.dart';
import 'package:tracker_flutter/core/config/app_environment.dart';
import 'package:tracker_flutter/core/di/app_providers.dart';
import 'package:tracker_flutter/core/error/app_failure.dart';
import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/core/router/app_router.dart';
import 'package:tracker_flutter/core/router/session_status.dart';
import 'package:tracker_flutter/features/auth/data/auth_api.dart';
import 'package:tracker_flutter/features/auth/data/client_platform.dart';
import 'package:tracker_flutter/features/auth/data/secure_token_storage.dart';
import 'package:tracker_flutter/features/projects/data/project_selection_store.dart';
import 'package:tracker_flutter/features/projects/data/projects_repository.dart';
import 'package:tracker_flutter/src/app.dart';

import '../helpers/fake_auth_api.dart';
import '../helpers/fake_project_selection_store.dart';
import '../helpers/fake_projects_repository.dart';
import '../helpers/fake_secure_token_storage.dart';

void main() {
  Widget app({
    SessionStatus status = SessionStatus.authenticated,
  }) => ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.fromEnvironment(AppEnvironment.local),
      ),
      // These smoke tests exercise the shell/projects/not-found
      // screens, not the auth flow itself (see features/auth's own
      // tests for that) — fixing the status directly skips needing a
      // full fake auth stack just to reach the authenticated shell.
      sessionStatusProvider.overrideWithValue(status),
      // The authenticated shell renders ProjectsScreen, which reaches
      // authRepositoryProvider (via SelectedProjectController) and
      // projectsRepositoryProvider regardless of the sessionStatus
      // override above — both need fakes so this stays a widget test,
      // not a real network call to a backend that isn't running.
      authApiProvider.overrideWithValue(
        FakeAuthApi()
          ..refreshResult = const Result.failure(UnauthorizedFailure()),
      ),
      secureTokenStorageProvider.overrideWithValue(FakeSecureTokenStorage()),
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

  testWidgets('launches to the projects screen inside the app shell', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle(); // let the splash->home redirect resolve
    expect(find.text('Tracker'), findsWidgets);
    expect(find.text('No projects yet'), findsOneWidget);
  });

  testWidgets('unknown routes render the not-found screen', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final router = ProviderScope.containerOf(
      tester.element(find.byType(TrackerApp)),
    ).read(routerProvider);
    router.go('/does-not-exist');
    await tester.pumpAndSettle();

    expect(find.text('Page not found'), findsOneWidget);
  });
}
