import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/error/app_failure.dart';
import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/auth/data/auth_api.dart';
import 'package:tracker_flutter/features/auth/data/auth_result.dart';
import 'package:tracker_flutter/features/auth/data/client_platform.dart';
import 'package:tracker_flutter/features/auth/data/secure_token_storage.dart';
import 'package:tracker_flutter/features/auth/domain/user.dart';
import 'package:tracker_flutter/features/board_columns/data/board_columns_repository.dart';
import 'package:tracker_flutter/features/board_columns/domain/board_column.dart';
import 'package:tracker_flutter/features/board_columns/presentation/board_screen.dart';
import 'package:tracker_flutter/features/projects/data/project_selection_store.dart';
import 'package:tracker_flutter/features/projects/data/projects_repository.dart';
import 'package:tracker_flutter/features/projects/data/selected_project_controller.dart';
import 'package:tracker_flutter/features/projects/domain/project.dart';

import '../../../helpers/fake_auth_api.dart';
import '../../../helpers/fake_board_columns_repository.dart';
import '../../../helpers/fake_project_selection_store.dart';
import '../../../helpers/fake_projects_repository.dart';
import '../../../helpers/fake_secure_token_storage.dart';

const _user = User(
  id: 1,
  email: 'a@b.com',
  displayName: null,
  tier: UserTier.free,
  role: UserRole.user,
);

// Status defaults to `unknown` (label "Unknown status") deliberately, not a
// real backend value: Tracker-BE's seeded columns are literally named after
// their status ("Backlog" / BACKLOG, "Done" / DONE, ...), so pairing a test
// column's name with its matching status would make the name and the
// status-label Text widgets collide in `find.text()` lookups below.
BoardColumn _column(int id, String name, {int position = 1000}) => BoardColumn(
  id: id,
  name: name,
  status: ColumnStatus.unknown,
  position: position,
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
  Future<FakeBoardColumnsRepository> pump(
    WidgetTester tester, {
    required Result<List<BoardColumn>> fetchResult,
    FakeProjectsRepository? projectsRepo,
  }) async {
    final columnsRepo = FakeBoardColumnsRepository()..fetchResult = fetchResult;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          boardColumnsRepositoryProvider.overrideWithValue(columnsRepo),
          // BoardScreen scopes its column provider to the authenticated
          // user id, so these widget tests restore a real authenticated
          // session rather than creating an account-less column cache.
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
          // SelectedProjectController also reads authRepositoryProvider
          // unconditionally, so its dependencies need overriding for the
          // "changing project doesn't affect columns" test below.
          projectSelectionStoreProvider.overrideWithValue(
            FakeProjectSelectionStore(),
          ),
          projectsRepositoryProvider.overrideWithValue(
            projectsRepo ??
                (FakeProjectsRepository()
                  ..fetchResult = const Result.success([])),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: BoardScreen())),
      ),
    );
    return columnsRepo;
  }

  testWidgets('shows a loading indicator, then the board columns', (
    tester,
  ) async {
    await pump(
      tester,
      fetchResult: Result.success([_column(1, 'Backlog'), _column(2, 'Done')]),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Backlog'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no columns', (
    tester,
  ) async {
    await pump(tester, fetchResult: const Result.success([]));
    await tester.pumpAndSettle();

    expect(find.text('No board columns yet'), findsOneWidget);
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

    repo.fetchResult = Result.success([_column(1, 'Backlog')]);
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Backlog'), findsOneWidget);
  });

  testWidgets(
    'an unauthorized failure shows the session-expired message, no retry button',
    (tester) async {
      await pump(
        tester,
        fetchResult: const Result.failure(UnauthorizedFailure()),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Your session has expired. Please sign in again.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Retry'), findsNothing);
    },
  );

  testWidgets('an offline failure shows the offline message', (tester) async {
    await pump(tester, fetchResult: const Result.failure(OfflineFailure()));
    await tester.pumpAndSettle();

    expect(
      find.text("You're offline. Check your connection and try again."),
      findsOneWidget,
    );
  });

  testWidgets('pull-to-refresh re-fetches the columns', (tester) async {
    final repo = await pump(
      tester,
      fetchResult: Result.success([_column(1, 'Backlog')]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Backlog'), findsOneWidget);

    repo.fetchResult = Result.success([
      _column(1, 'Backlog'),
      _column(2, 'Done', position: 6000),
    ]);
    await tester.fling(find.text('Backlog'), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Done'), findsOneWidget);
    expect(repo.fetchCalls, greaterThanOrEqualTo(2));
  });

  testWidgets(
    'columns render in the order the repository returns (position order)',
    (tester) async {
      await pump(
        tester,
        fetchResult: Result.success([
          _column(1, 'Backlog', position: 1000),
          _column(2, 'In Progress', position: 3000),
          _column(3, 'Done', position: 6000),
        ]),
      );
      await tester.pumpAndSettle();

      final names = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      final backlogIndex = names.indexOf('Backlog');
      final inProgressIndex = names.indexOf('In Progress');
      final doneIndex = names.indexOf('Done');
      expect(backlogIndex, lessThan(inProgressIndex));
      expect(inProgressIndex, lessThan(doneIndex));
    },
  );

  testWidgets(
    'changing the selected project does not reload or change the board columns',
    (tester) async {
      final projectsRepo = FakeProjectsRepository()
        ..fetchResult = Result.success([
          _project(1, 'Alpha'),
          _project(2, 'Beta'),
        ]);
      final columnsRepo = await pump(
        tester,
        fetchResult: Result.success([_column(1, 'Backlog')]),
        projectsRepo: projectsRepo,
      );
      await tester.pumpAndSettle();
      expect(find.text('Backlog'), findsOneWidget);
      expect(columnsRepo.fetchCalls, 1);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(BoardScreen)),
      );
      // Selecting a project is a completely independent piece of state
      // (see BoardScreen's doc comment) — it must not trigger, invalidate,
      // or re-scope the board-columns provider in any way.
      container.read(selectedProjectControllerProvider.notifier).select(1);
      await tester.pumpAndSettle();
      container.read(selectedProjectControllerProvider.notifier).select(2);
      await tester.pumpAndSettle();

      expect(find.text('Backlog'), findsOneWidget);
      expect(columnsRepo.fetchCalls, 1);
    },
  );
}
