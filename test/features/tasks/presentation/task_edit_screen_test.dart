import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/auth/data/auth_api.dart';
import 'package:tracker_flutter/features/auth/data/auth_result.dart';
import 'package:tracker_flutter/features/auth/data/client_platform.dart';
import 'package:tracker_flutter/features/auth/data/secure_token_storage.dart';
import 'package:tracker_flutter/features/auth/domain/user.dart';
import 'package:tracker_flutter/features/tasks/data/tasks_repository.dart';
import 'package:tracker_flutter/features/tasks/domain/task.dart';
import 'package:tracker_flutter/features/tasks/presentation/task_edit_screen.dart';

import '../../../helpers/fake_auth_api.dart';
import '../../../helpers/fake_secure_token_storage.dart';
import '../../../helpers/fake_tasks_repository.dart';

const _user = User(
  id: 7,
  email: 'editor@example.com',
  displayName: null,
  tier: UserTier.free,
  role: UserRole.user,
);

Task _task(String status) => Task.fromJson({
  'id': 42,
  'title': 'Terminal task',
  'description': null,
  'riskLevel': 'LOW',
  'createdDate': '2026-08-11T01:00:00',
  'updatedDate': '2026-08-11T01:00:00',
  'important': false,
  'status': status,
  'area': 'PERSONAL',
  'effort': 'MEDIUM',
  'overdue': false,
  'urgent': false,
  'priorityScore': 0,
  'position': 1000,
});

void main() {
  testWidgets('a completed task cannot be edited through a direct route', (
    tester,
  ) async {
    final repo = FakeTasksRepository()
      ..fetchTaskHandler = (id) async => Result.success(_task('DONE'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksRepositoryProvider.overrideWithValue(repo),
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
        child: const MaterialApp(
          home: Scaffold(body: SafeTaskEditScreen(taskId: 42)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('lifecycle controls in the next slice'),
      findsOneWidget,
    );
    expect(find.text('Save changes'), findsNothing);
  });
}
