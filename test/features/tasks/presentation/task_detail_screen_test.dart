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
import 'package:tracker_flutter/features/tasks/data/tasks_repository.dart';
import 'package:tracker_flutter/features/tasks/domain/task.dart';
import 'package:tracker_flutter/features/tasks/presentation/task_detail_screen.dart';

import '../../../helpers/fake_auth_api.dart';
import '../../../helpers/fake_secure_token_storage.dart';
import '../../../helpers/fake_tasks_repository.dart';

const _user = User(
  id: 7,
  email: 'detail@example.com',
  displayName: null,
  tier: UserTier.free,
  role: UserRole.user,
);

Task _task() => Task.fromJson({
  'id': 42,
  'title': 'Inspect pagination contract',
  'description': 'Verify the client never truncates the task list.',
  'dueDate': '2026-08-15',
  'startDate': '2026-08-11',
  'estimatedMinutes': 60,
  'actualMinutes': 20,
  'riskLevel': 'HIGH',
  'track': 'Flutter',
  'phase': 'Slice 3',
  'projectId': 99,
  'createdDate': '2026-08-11T01:00:00',
  'updatedDate': '2026-08-11T01:30:00',
  'important': true,
  'status': 'IN_PROGRESS',
  'effort': 'DEEP_WORK',
  'daysLeft': 4,
  'overdue': false,
  'urgent': true,
  'priorityScore': 90,
  'priorityCategory': 'DO_NOW',
  'ageFlag': 'NEW',
  'boardColumnId': 3,
  'position': 10,
  'dependencyIds': [1],
  'blockingTaskIds': [8],
  'subtaskIds': [100, 101],
  'subtaskCount': 2,
  'completedSubtaskCount': 1,
  'subtaskProgressPercent': 50,
  'recurrence': null,
});

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required FakeTasksRepository repository,
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
        child: const MaterialApp(
          home: Scaffold(body: TaskDetailScreen(taskId: 42)),
        ),
      ),
    );
  }

  testWidgets('renders task details from GET /tasks/{id}', (tester) async {
    final repo = FakeTasksRepository()
      ..fetchTaskHandler = (id) async => Result.success(_task());

    await pump(tester, repository: repo);
    await tester.pumpAndSettle();

    expect(find.text('Inspect pagination contract'), findsOneWidget);
    expect(
      find.text('Verify the client never truncates the task list.'),
      findsOneWidget,
    );
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Urgent'), findsOneWidget);
    expect(find.text('Priority 90'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Structure'), findsOneWidget);
    expect(repo.fetchTaskCalls, 1);
  });

  testWidgets('failure uses shared error state and retry', (tester) async {
    var fail = true;
    final repo = FakeTasksRepository()
      ..fetchTaskHandler = (id) async => fail
          ? const Result.failure(ServerFailure(statusCode: 500))
          : Result.success(_task());

    await pump(tester, repository: repo);
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong. Please try again.'), findsOneWidget);

    fail = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Inspect pagination contract'), findsOneWidget);
    expect(repo.fetchTaskCalls, 2);
  });
}
