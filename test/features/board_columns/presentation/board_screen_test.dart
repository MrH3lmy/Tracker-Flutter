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
import 'package:tracker_flutter/features/board_columns/data/board_columns_repository.dart';
import 'package:tracker_flutter/features/board_columns/domain/board_column.dart';
import 'package:tracker_flutter/features/board_columns/presentation/board_screen.dart';
import 'package:tracker_flutter/features/projects/data/project_selection_store.dart';
import 'package:tracker_flutter/features/projects/data/selected_project_controller.dart';
import 'package:tracker_flutter/features/tasks/data/tasks_repository.dart';
import 'package:tracker_flutter/features/tasks/domain/task.dart';

import '../../../helpers/fake_auth_api.dart';
import '../../../helpers/fake_board_columns_repository.dart';
import '../../../helpers/fake_project_selection_store.dart';
import '../../../helpers/fake_secure_token_storage.dart';
import '../../../helpers/fake_tasks_repository.dart';

const _user = User(
  id: 1,
  email: 'a@b.com',
  displayName: null,
  tier: UserTier.free,
  role: UserRole.user,
);

BoardColumn _column(int id, String name, {int position = 1000}) => BoardColumn(
  id: id,
  name: name,
  status: ColumnStatus.unknown,
  position: position,
);

Task _task(int id, String title, int columnId, {int projectId = 1}) =>
    Task.fromJson({
      'id': id,
      'title': title,
      'description': null,
      'riskLevel': 'LOW',
      'projectId': projectId,
      'createdDate': '2026-08-11T01:00:00',
      'updatedDate': '2026-08-11T01:00:00',
      'important': false,
      'status': 'NOT_STARTED',
      'overdue': false,
      'urgent': false,
      'priorityScore': 0,
      'boardColumnId': columnId,
      'position': id,
    });

PaginatedResult<Task> _page(List<Task> tasks, {bool hasNext = false}) =>
    PaginatedResult(
      items: tasks,
      meta: PageMeta(
        page: 0,
        pageSize: 50,
        totalCount: tasks.length + (hasNext ? 1 : 0),
        totalPages: hasNext ? 2 : 1,
        hasNext: hasNext,
      ),
    );

void main() {
  Future<({FakeBoardColumnsRepository columns, FakeTasksRepository tasks})> pump(
    WidgetTester tester, {
    required Result<List<BoardColumn>> columnsResult,
    List<Task> tasks = const [],
  }) async {
    final columnsRepo = FakeBoardColumnsRepository()..fetchResult = columnsResult;
    final tasksRepo = FakeTasksRepository()
      ..fetchTasksHandler =
          ({
            required int page,
            required int size,
            int? projectId,
            required List<TaskStatus> statuses,
          }) async => Result.success(_page(tasks));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          boardColumnsRepositoryProvider.overrideWithValue(columnsRepo),
          tasksRepositoryProvider.overrideWithValue(tasksRepo),
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
        ],
        child: const MaterialApp(home: Scaffold(body: BoardScreen())),
      ),
    );
    return (columns: columnsRepo, tasks: tasksRepo);
  }

  testWidgets('loads columns and renders task cards in their board column', (
    tester,
  ) async {
    await pump(
      tester,
      columnsResult: Result.success([
        _column(1, 'Backlog'),
        _column(2, 'In progress', position: 3000),
      ]),
      tasks: [_task(10, 'Implement list', 1), _task(11, 'Review API', 2)],
    );

    await tester.pumpAndSettle();

    expect(find.text('Backlog'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Implement list'), findsOneWidget);
    expect(find.text('Review API'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no columns', (tester) async {
    await pump(tester, columnsResult: const Result.success([]));
    await tester.pumpAndSettle();

    expect(find.text('No board columns yet'), findsOneWidget);
  });

  testWidgets('shows column load failures through AsyncStateView', (tester) async {
    await pump(
      tester,
      columnsResult: const Result.failure(ServerFailure(statusCode: 500)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
  });

  testWidgets('changing project re-filters tasks without reloading columns', (
    tester,
  ) async {
    final repos = await pump(
      tester,
      columnsResult: Result.success([_column(1, 'Backlog')]),
      tasks: [_task(10, 'Implement list', 1)],
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BoardScreen)),
    );
    container.read(selectedProjectControllerProvider.notifier).select(2);
    await tester.pumpAndSettle();

    expect(repos.columns.fetchCalls, 1);
    expect(repos.tasks.fetchTasksCalls, greaterThanOrEqualTo(2));
    expect(repos.tasks.lastProjectId, 2);
  });
}
