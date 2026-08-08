import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/error/app_failure.dart';
import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/auth/data/auth_api.dart';
import 'package:tracker_flutter/features/auth/data/client_platform.dart';
import 'package:tracker_flutter/features/auth/data/secure_token_storage.dart';
import 'package:tracker_flutter/features/projects/data/project_selection_store.dart';
import 'package:tracker_flutter/features/projects/data/projects_repository.dart';
import 'package:tracker_flutter/features/projects/domain/project.dart';
import 'package:tracker_flutter/features/projects/presentation/projects_screen.dart';

import '../../../helpers/fake_auth_api.dart';
import '../../../helpers/fake_project_selection_store.dart';
import '../../../helpers/fake_projects_repository.dart';
import '../../../helpers/fake_secure_token_storage.dart';

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
  Future<FakeProjectsRepository> pump(
    WidgetTester tester, {
    required Result<List<Project>> fetchResult,
  }) async {
    final projectsRepo = FakeProjectsRepository()..fetchResult = fetchResult;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsRepositoryProvider.overrideWithValue(projectsRepo),
          // SelectedProjectController reads authRepositoryProvider
          // unconditionally, so its dependencies need overriding even
          // though these tests don't exercise sign-in themselves.
          authApiProvider.overrideWithValue(
            FakeAuthApi()
              ..refreshResult = const Result.failure(UnauthorizedFailure()),
          ),
          secureTokenStorageProvider.overrideWithValue(
            FakeSecureTokenStorage(),
          ),
          clientPlatformProvider.overrideWithValue(ClientPlatform.android),
          projectSelectionStoreProvider.overrideWithValue(
            FakeProjectSelectionStore(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ProjectsScreen())),
      ),
    );
    return projectsRepo;
  }

  testWidgets('shows a loading indicator, then the project list', (
    tester,
  ) async {
    await pump(
      tester,
      fetchResult: Result.success([_project(1, 'Alpha'), _project(2, 'Beta')]),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('sorts projects by name for a stable order', (tester) async {
    await pump(
      tester,
      fetchResult: Result.success([_project(2, 'Zeta'), _project(1, 'Alpha')]),
    );
    await tester.pumpAndSettle();

    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title! as Text).data)
        .toList();
    expect(titles, ['Alpha', 'Zeta']);
  });

  testWidgets('shows the empty state when there are no projects', (
    tester,
  ) async {
    await pump(tester, fetchResult: const Result.success([]));
    await tester.pumpAndSettle();

    expect(find.text('No projects yet'), findsOneWidget);
  });

  testWidgets('shows an error state with a retry action, which recovers', (
    tester,
  ) async {
    final repo = await pump(
      tester,
      fetchResult: const Result.failure(ServerFailure(statusCode: 500)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );

    repo.fetchResult = Result.success([_project(1, 'Alpha')]);
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('an offline failure shows the offline message, no retry button', (
    tester,
  ) async {
    await pump(tester, fetchResult: const Result.failure(OfflineFailure()));
    await tester.pumpAndSettle();

    expect(
      find.text("You're offline. Check your connection and try again."),
      findsOneWidget,
    );
  });

  testWidgets('tapping a project selects it and shows a confirmation', (
    tester,
  ) async {
    await pump(
      tester,
      fetchResult: Result.success([_project(1, 'Alpha'), _project(2, 'Beta')]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alpha'));
    await tester.pump();

    expect(find.text('Alpha selected'), findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.ancestor(of: find.text('Alpha'), matching: find.byType(ListTile)),
    );
    expect(tile.selected, isTrue);
  });

  testWidgets('pull-to-refresh re-fetches the list', (tester) async {
    final repo = await pump(
      tester,
      fetchResult: Result.success([_project(1, 'Alpha')]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);

    repo.fetchResult = Result.success([
      _project(1, 'Alpha'),
      _project(2, 'Beta'),
    ]);
    await tester.fling(find.text('Alpha'), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Beta'), findsOneWidget);
    expect(repo.fetchCalls, greaterThanOrEqualTo(2));
  });
}
