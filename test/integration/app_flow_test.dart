import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/config/app_config.dart';
import 'package:tracker_flutter/core/config/app_environment.dart';
import 'package:tracker_flutter/core/di/app_providers.dart';
import 'package:tracker_flutter/core/error/app_failure.dart';
import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/auth/data/auth_api.dart';
import 'package:tracker_flutter/features/auth/data/auth_result.dart';
import 'package:tracker_flutter/features/auth/data/client_platform.dart';
import 'package:tracker_flutter/features/auth/data/secure_token_storage.dart';
import 'package:tracker_flutter/features/auth/domain/user.dart';
import 'package:tracker_flutter/features/projects/data/project_selection_store.dart';
import 'package:tracker_flutter/features/projects/data/projects_repository.dart';
import 'package:tracker_flutter/features/projects/data/selected_project_controller.dart';
import 'package:tracker_flutter/features/projects/domain/project.dart';
import 'package:tracker_flutter/src/app.dart';

import '../helpers/fake_auth_api.dart';
import '../helpers/fake_project_selection_store.dart';
import '../helpers/fake_projects_repository.dart';
import '../helpers/fake_secure_token_storage.dart';

/// Exercises the epic #4 slice 1 flow end to end at the widget-test level:
/// launch -> session restore -> sign in -> authenticated shell -> projects
/// load -> select a project. There is no live Tracker-BE reachable from a
/// widget test, so only the network boundary (AuthApi/ProjectsRepository)
/// is faked here — every provider, every screen, and every state
/// transition in between (SessionState, ProjectsController,
/// SelectedProjectController, the router's redirect logic) is real. A true
/// device/backend integration run is `integration_test/app_test.dart`.
const _user = User(
  id: 1,
  email: 'a@b.com',
  displayName: null,
  tier: UserTier.free,
  role: UserRole.user,
);

Project _project(int id, String name) => Project(
  id: id,
  name: name,
  description: null,
  status: ProjectStatus.active,
  startDate: null,
  targetDate: null,
  area: null,
  goal: null,
  ownerUserId: 1,
  createdDate: DateTime.parse('2026-01-01T00:00:00'),
);

void main() {
  testWidgets(
    'launch -> sign in -> authenticated shell -> projects load -> select project',
    (tester) async {
      final authApi = FakeAuthApi()
        ..refreshResult = const Result.failure(UnauthorizedFailure())
        ..loginResult = Result.success(
          AuthResult(
            accessToken: 'access-1',
            refreshToken: 'refresh-1',
            user: _user,
          ),
        );
      final projectsRepo = FakeProjectsRepository()
        ..fetchResult = Result.success([
          _project(1, 'Website relaunch'),
          _project(2, 'Q3 planning'),
        ]);
      final selectionStore = FakeProjectSelectionStore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig.fromEnvironment(AppEnvironment.local),
            ),
            authApiProvider.overrideWithValue(authApi),
            secureTokenStorageProvider.overrideWithValue(
              FakeSecureTokenStorage(),
            ),
            clientPlatformProvider.overrideWithValue(ClientPlatform.android),
            projectsRepositoryProvider.overrideWithValue(projectsRepo),
            projectSelectionStoreProvider.overrideWithValue(selectionStore),
          ],
          child: const TrackerApp(),
        ),
      );

      // 1. Launch: session restoration is in flight -> held on splash.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);

      // 2. Restoration settles with no stored credential -> sign-in screen.
      // ("Sign in" appears twice: the heading and the submit button.)
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsWidgets);

      // 3. Sign in.
      await tester.enterText(find.byType(TextFormField).first, _user.email);
      await tester.enterText(
        find.byType(TextFormField).last,
        'correct-horse-battery',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      // 4. Authenticated shell renders, and the projects load automatically.
      expect(find.text('Tracker'), findsOneWidget);
      expect(find.text('Website relaunch'), findsOneWidget);
      expect(find.text('Q3 planning'), findsOneWidget);

      // 5. Select a project.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TrackerApp)),
      );
      expect(container.read(selectedProjectControllerProvider), isNull);

      await tester.tap(find.text('Website relaunch'));
      await tester.pump();

      expect(find.text('Website relaunch selected'), findsOneWidget);
      expect(container.read(selectedProjectControllerProvider), 1);
      expect(await selectionStore.readSelectedProjectId(_user.id), 1);
    },
  );
}
