import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/error/app_failure.dart';
import 'package:tracker_flutter/core/network/pagination/page_meta.dart';
import 'package:tracker_flutter/core/network/pagination/paginated_result.dart';
import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/auth/data/auth_api.dart';
import 'package:tracker_flutter/features/auth/data/auth_result.dart';
import 'package:tracker_flutter/features/auth/data/client_platform.dart';
import 'package:tracker_flutter/features/auth/data/secure_token_storage.dart';
import 'package:tracker_flutter/features/auth/domain/user.dart';
import 'package:tracker_flutter/features/tasks/data/tasks_repository.dart';
import 'package:tracker_flutter/features/tasks/domain/task.dart';
import 'package:tracker_flutter/features/tasks/presentation/tasks_screen.dart';

import '../../../helpers/fake_auth_api.dart';
import '../../../helpers/fake_secure_token_storage.dart';
import '../../../helpers/fake_tasks_repository.dart';

const _user = User(
  id: 7,
  email: 'tasks@example.com',
  displayName: null,
  tier: UserTier.free,
  role: UserRole.user,
);

Task _task(int id, String title) => Task.fromJson({
  'id': id,
  'title': title,
  'description': null,
  'dueDate': '2026-08-15',
  'estimatedMinutes': 30,
  'riskLevel': 'LOW',
  'createdDate': '2026-08-11T01:00:00',
  'updatedDate': '2026-08-11T01:00:00',
  'important': id == 1,
  'status': 'IN_PROGRESS',
  'overdue': false,
  'urgent': false,
  'priorityScore': 0,
  'boardColumnId': 3,
  'position': id,
});

PaginatedResult<Task> _page(
  int page,
  List<Task> items, {
  required int totalCount,
  required bool hasNext,
}) => PaginatedResult(
  items: items,
  meta: PageMeta(
    page: page,
    pageSize: 50,
    totalCount: totalCount,
    totalPages: hasNext ? page + 2 : page + 1,
    hasNext: hasNext,
  ),
);

void main() {
  Future<FakeTasksRepository> pump(
    WidgetTester tester, {
    required FakeTasksRepository repository,
    int? projectId,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksRepositoryProvider.overrideWithValue(repository),
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
        ],
        child: MaterialApp(
          home: Scaffold(body: TasksScreen(projectId: projectId)),
        ),
      ),
    );
    return repository;
  }

  testWidgets('renders the first page and an explicit load-more action', (
    tester,
  ) async {
    final repo = FakeTasksRepository()
      ..fetchTasksHandler =
          ({
            required int page,
            required int size,
            int? projectId,
            required List<TaskStatus> statuses,
          }) async => Result.success(
            _page(
              0,
              [_task(1, 'First task'), _task(2, 'Second task')],
              totalCount: 3,
              hasNext: true,
            ),
          );

    await pump(tester, repository: repo);
    await tester.pumpAndSettle();

    expect(find.text('First task'), findsOneWidget);
    expect(find.text('Second task'), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Load more'), findsOneWidget);
    expect(find.text('New task'), findsOneWidget);
  });

  testWidgets('load more appends the next page', (tester) async {
    final repo = FakeTasksRepository()
      ..fetchTasksHandler =
          ({
            required int page,
            required int size,
            int? projectId,
            required List<TaskStatus> statuses,
          }) async => Result.success(
            page == 0
                ? _page(
                    0,
                    [_task(1, 'First task')],
                    totalCount: 2,
                    hasNext: true,
                  )
                : _page(
                    1,
                    [_task(2, 'Second task')],
                    totalCount: 2,
                    hasNext: false,
                  ),
          );

    await pump(tester, repository: repo);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Load more'));
    await tester.pumpAndSettle();

    expect(find.text('First task'), findsOneWidget);
    expect(find.text('Second task'), findsOneWidget);
    expect(find.text('2 of 2'), findsOneWidget);
    expect(repo.fetchTasksCalls, 2);
  });

  testWidgets('project id is passed to the paginated query', (tester) async {
    final repo = FakeTasksRepository()
      ..fetchTasksHandler =
          ({
            required int page,
            required int size,
            int? projectId,
            required List<TaskStatus> statuses,
          }) async => Result.success(
            _page(0, [_task(1, 'Project task')], totalCount: 1, hasNext: false),
          );

    await pump(tester, repository: repo, projectId: 55);
    await tester.pumpAndSettle();

    expect(repo.lastProjectId, 55);
    expect(find.text('Active tasks in selected project'), findsOneWidget);
  });

  testWidgets('empty state includes a create action', (tester) async {
    final emptyRepo = FakeTasksRepository()
      ..fetchTasksHandler =
          ({
            required int page,
            required int size,
            int? projectId,
            required List<TaskStatus> statuses,
          }) async =>
              Result.success(_page(0, const [], totalCount: 0, hasNext: false));

    await pump(tester, repository: emptyRepo);
    await tester.pumpAndSettle();
    expect(find.text('No active tasks'), findsOneWidget);
    expect(find.text('Create task'), findsOneWidget);
  });

  testWidgets('repository failure uses the shared error presentation', (
    tester,
  ) async {
    final repo = FakeTasksRepository()
      ..fetchTasksHandler =
          ({
            required int page,
            required int size,
            int? projectId,
            required List<TaskStatus> statuses,
          }) async => const Result.failure(OfflineFailure());

    await pump(tester, repository: repo);
    await tester.pumpAndSettle();

    expect(
      find.text("You're offline. Check your connection and try again."),
      findsOneWidget,
    );
  });
}
