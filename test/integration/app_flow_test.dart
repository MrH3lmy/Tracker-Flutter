import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/config/app_config.dart';
import 'package:tracker_flutter/core/config/app_environment.dart';
import 'package:tracker_flutter/core/di/app_providers.dart';
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
import 'package:tracker_flutter/features/projects/data/project_selection_store.dart';
import 'package:tracker_flutter/features/projects/data/projects_repository.dart';
import 'package:tracker_flutter/features/projects/data/selected_project_controller.dart';
import 'package:tracker_flutter/features/projects/domain/project.dart';
import 'package:tracker_flutter/features/tasks/data/tasks_repository.dart';
import 'package:tracker_flutter/features/tasks/domain/task.dart';
import 'package:tracker_flutter/features/tasks/domain/task_write_input.dart';
import 'package:tracker_flutter/src/app.dart';

import '../helpers/fake_auth_api.dart';
import '../helpers/fake_board_columns_repository.dart';
import '../helpers/fake_project_selection_store.dart';
import '../helpers/fake_projects_repository.dart';
import '../helpers/fake_secure_token_storage.dart';
import '../helpers/fake_tasks_repository.dart';

/// Exercises epic #4's first four slices at the widget-test level: launch ->
/// session restore -> sign in -> select a project -> inspect global board
/// columns -> browse the selected project's bounded task list -> open task
/// details -> edit a task -> create a task in the selected project. Only
/// network repositories are faked; routing, authentication state, project
/// selection, pagination state, write state, and screens are real.
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

BoardColumn _column(int id, String name, int position) => BoardColumn(
  id: id,
  name: name,
  status: ColumnStatus.unknown,
  position: position,
);

Task _task(int id, String title, {int projectId = 1}) => Task.fromJson({
  'id': id,
  'title': title,
  'description': 'Task detail body',
  'dueDate': '2026-08-15',
  'estimatedMinutes': 45,
  'riskLevel': 'LOW',
  'projectId': projectId,
  'createdDate': '2026-08-11T01:00:00',
  'updatedDate': '2026-08-11T01:00:00',
  'important': false,
  'status': 'IN_PROGRESS',
  'area': 'PERSONAL',
  'effort': 'MEDIUM',
  'overdue': false,
  'urgent': false,
  'priorityScore': 10,
  'priorityCategory': 'SCHEDULE',
  'ageFlag': 'NEW',
  'boardColumnId': 2,
  'position': id,
});

void main() {
  testWidgets(
    'launch -> sign in -> project -> board -> tasks -> detail -> edit -> create',
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
      final columnsRepo = FakeBoardColumnsRepository()
        ..fetchResult = Result.success([
          _column(1, 'Backlog', 1000),
          _column(2, 'In Progress', 3000),
          _column(3, 'Done', 6000),
        ]);
      final storedTasks = <int, Task>{42: _task(42, 'Build task details')};
      var nextTaskId = 100;

      Future<Result<PaginatedResult<Task>>> fetchTasks({
        required int page,
        required int size,
        int? projectId,
        required List<TaskStatus> statuses,
      }) async {
        expect(projectId, 1);
        expect(page, 0);
        expect(size, 50);
        final items = storedTasks.values.where((task) {
          return task.projectId == projectId && statuses.contains(task.status);
        }).toList(growable: false);
        return Result.success(
          PaginatedResult(
            items: items,
            meta: PageMeta(
              page: 0,
              pageSize: 50,
              totalCount: items.length,
              totalPages: items.isEmpty ? 0 : 1,
              hasNext: false,
            ),
          ),
        );
      }

      Future<Result<Task>> fetchTask(int id) async {
        final task = storedTasks[id];
        if (task == null) {
          return const Result.failure(UnknownFailure(message: 'Missing task'));
        }
        return Result.success(task);
      }

      Future<Result<Task>> updateTask(int id, TaskWriteInput input) async {
        final existing = storedTasks[id]!;
        final updated = _task(
          id,
          input.title.trim(),
          projectId: existing.projectId ?? 1,
        );
        storedTasks[id] = updated;
        return Result.success(updated);
      }

      Future<Result<TaskCreateOutcome>> createTask(
        TaskWriteInput input,
        int? projectId,
      ) async {
        final created = _task(
          nextTaskId++,
          input.title.trim(),
          projectId: projectId ?? 1,
        );
        storedTasks[created.id] = created;
        return Result.success(
          TaskCreateOutcome(task: created, projectAssignmentFailure: null),
        );
      }

      final tasksRepo = FakeTasksRepository()
        ..fetchTasksHandler = fetchTasks
        ..fetchTaskHandler = fetchTask
        ..updateTaskHandler = updateTask
        ..createTaskHandler = createTask;

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
            boardColumnsRepositoryProvider.overrideWithValue(columnsRepo),
            tasksRepositoryProvider.overrideWithValue(tasksRepo),
          ],
          child: const TrackerApp(),
        ),
      );

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsWidgets);

      await tester.enterText(find.byType(TextFormField).first, _user.email);
      await tester.enterText(
        find.byType(TextFormField).last,
        'correct-horse-battery',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Tracker'), findsOneWidget);
      expect(find.text('Website relaunch'), findsOneWidget);
      expect(find.text('Q3 planning'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TrackerApp)),
      );
      expect(container.read(selectedProjectControllerProvider), isNull);

      await tester.tap(find.text('Website relaunch'));
      await tester.pump();
      expect(find.text('Website relaunch selected'), findsOneWidget);
      expect(container.read(selectedProjectControllerProvider), 1);
      expect(await selectionStore.readSelectedProjectId(_user.id), 1);

      await tester.tap(find.byIcon(Icons.view_column_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Backlog'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(columnsRepo.fetchCalls, 1);

      await tester.tap(find.byIcon(Icons.checklist_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Active tasks in selected project'), findsOneWidget);
      expect(find.text('Build task details'), findsOneWidget);
      expect(find.text('1 of 1'), findsOneWidget);
      expect(tasksRepo.lastProjectId, 1);

      await tester.tap(find.text('Build task details'));
      await tester.pumpAndSettle();

      expect(find.text('Task detail body'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(tasksRepo.fetchTaskCalls, 1);

      await tester.tap(find.text('Edit task'));
      await tester.pumpAndSettle();
      expect(find.text('Edit task'), findsOneWidget);

      final editTitle = find.byType(TextFormField).first;
      await tester.enterText(editTitle, 'Build task details v2');
      final saveButton = find.widgetWithText(FilledButton, 'Save changes');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(tasksRepo.updateTaskCalls, 1);
      expect(find.text('Build task details v2'), findsOneWidget);
      expect(find.text('Task updated'), findsOneWidget);

      await tester.tap(find.text('Back to tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Build task details v2'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'New task'));
      await tester.pumpAndSettle();
      expect(find.text('New task'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).first,
        'Create from Flutter',
      );
      final createButton = find.widgetWithText(FilledButton, 'Create task');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(tasksRepo.createTaskCalls, 1);
      expect(tasksRepo.lastProjectId, 1);
      expect(find.text('Create from Flutter'), findsOneWidget);
      expect(find.text('Task created'), findsOneWidget);
    },
  );
}
