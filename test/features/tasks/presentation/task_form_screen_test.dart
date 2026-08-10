import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/auth/data/auth_api.dart';
import 'package:tracker_flutter/features/auth/data/auth_result.dart';
import 'package:tracker_flutter/features/auth/data/client_platform.dart';
import 'package:tracker_flutter/features/auth/data/secure_token_storage.dart';
import 'package:tracker_flutter/features/auth/domain/user.dart';
import 'package:tracker_flutter/features/tasks/data/tasks_repository.dart';
import 'package:tracker_flutter/features/tasks/domain/task.dart';
import 'package:tracker_flutter/features/tasks/presentation/task_form_screen.dart';

import '../../../helpers/fake_auth_api.dart';
import '../../../helpers/fake_secure_token_storage.dart';
import '../../../helpers/fake_tasks_repository.dart';

const _user = User(
  id: 7,
  email: 'writer@example.com',
  displayName: null,
  tier: UserTier.free,
  role: UserRole.user,
);

Task _createdTask(int id, String title, {int? projectId = 55}) =>
    Task.fromJson({
      'id': id,
      'title': title,
      'description': null,
      'riskLevel': 'LOW',
      'projectId': projectId,
      'createdDate': '2026-08-11T01:00:00',
      'updatedDate': '2026-08-11T01:00:00',
      'important': false,
      'status': 'BACKLOG',
      'area': 'PERSONAL',
      'effort': 'MEDIUM',
      'overdue': false,
      'urgent': false,
      'priorityScore': 0,
      'position': 1000,
    });

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required FakeTasksRepository repository,
  }) async {
    final router = GoRouter(
      initialLocation: '/tasks/new',
      routes: [
        GoRoute(
          path: '/tasks/new',
          builder: (context, state) => const Scaffold(
            body: TaskCreateScreen(projectId: 55),
          ),
        ),
        GoRoute(
          path: '/tasks/:id',
          builder: (context, state) =>
              Scaffold(body: Text('detail ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);

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
            FakeSecureTokenStorage(initialToken: 'stored-refresh'),
          ),
          clientPlatformProvider.overrideWithValue(ClientPlatform.android),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollToSubmit(WidgetTester tester) => tester.dragUntilVisible(
    find.widgetWithText(FilledButton, 'Create task'),
    find.byType(ListView),
    const Offset(0, -400),
  );

  testWidgets('title is required before a create request can be sent', (
    tester,
  ) async {
    final repo = FakeTasksRepository();
    await pump(tester, repository: repo);
    await scrollToSubmit(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Create task'));
    await tester.pump();

    expect(find.text('Title is required'), findsOneWidget);
    expect(repo.createTaskCalls, 0);
  });

  testWidgets(
    'successful create keeps selected project scope and opens detail',
    (tester) async {
      final repo = FakeTasksRepository()
        ..createTaskHandler = (input, projectId) async => Result.success(
          TaskCreateOutcome(
            task: _createdTask(44, input.title.trim(), projectId: projectId),
            projectAssignmentFailure: null,
          ),
        );
      await pump(tester, repository: repo);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Created from Flutter',
      );
      await scrollToSubmit(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Create task'));
      await tester.pumpAndSettle();

      expect(repo.createTaskCalls, 1);
      expect(repo.lastProjectId, 55);
      expect(repo.lastWriteInput!.title, 'Created from Flutter');
      expect(find.text('detail 44'), findsOneWidget);
    },
  );
}
