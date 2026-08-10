import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/error/app_failure.dart';
import 'package:tracker_flutter/core/network/pagination/page_meta.dart';
import 'package:tracker_flutter/core/network/pagination/paginated_result.dart';
import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/tasks/data/tasks_controller.dart';
import 'package:tracker_flutter/features/tasks/data/tasks_repository.dart';
import 'package:tracker_flutter/features/tasks/domain/task.dart';

import '../../../helpers/fake_tasks_repository.dart';

Task _task(int id, {String? title}) => Task.fromJson({
  'id': id,
  'title': title ?? 'Task $id',
  'description': null,
  'riskLevel': 'LOW',
  'createdDate': '2026-08-11T01:00:00',
  'updatedDate': '2026-08-11T01:00:00',
  'important': false,
  'status': 'NOT_STARTED',
  'overdue': false,
  'urgent': false,
  'priorityScore': 0,
  'boardColumnId': 2,
  'position': id,
});

PaginatedResult<Task> _page(
  int page,
  List<Task> tasks, {
  required int totalCount,
  required bool hasNext,
}) => PaginatedResult(
  items: tasks,
  meta: PageMeta(
    page: page,
    pageSize: 50,
    totalCount: totalCount,
    totalPages: hasNext ? page + 2 : page + 1,
    hasNext: hasNext,
  ),
);

void main() {
  ({ProviderContainer container, FakeTasksRepository repo}) build() {
    final repo = FakeTasksRepository();
    final container = ProviderContainer(
      overrides: [tasksRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return (container: container, repo: repo);
  }

  const listKey = (userId: 7, projectId: 99);
  final listProvider = taskListControllerProvider(listKey);

  void keepListAlive(ProviderContainer container) {
    final subscription = container.listen(listProvider, (previous, next) {});
    addTearDown(subscription.close);
  }

  test('first page is bounded and scoped to the selected project', () async {
    final built = build();
    built.repo.fetchTasksHandler =
        ({
          required int page,
          required int size,
          int? projectId,
          required List<TaskStatus> statuses,
        }) async =>
            Result.success(_page(0, [_task(1)], totalCount: 1, hasNext: false));
    keepListAlive(built.container);

    final state = await built.container.read(listProvider.future);

    expect(state.tasks.single.id, 1);
    expect(built.repo.lastPage, 0);
    expect(built.repo.lastSize, TaskListController.pageSize);
    expect(built.repo.lastProjectId, 99);
  });

  test(
    'loadNextPage appends the next bounded page without duplicates',
    () async {
      final built = build();
      built.repo.fetchTasksHandler =
          ({
            required int page,
            required int size,
            int? projectId,
            required List<TaskStatus> statuses,
          }) async {
            if (page == 0) {
              return Result.success(
                _page(0, [_task(1), _task(2)], totalCount: 3, hasNext: true),
              );
            }
            return Result.success(
              _page(
                1,
                [_task(2, title: 'Updated Task 2'), _task(3)],
                totalCount: 3,
                hasNext: false,
              ),
            );
          };
      keepListAlive(built.container);
      await built.container.read(listProvider.future);

      await built.container.read(listProvider.notifier).loadNextPage();

      final state = built.container.read(listProvider).value!;
      expect(state.tasks.map((task) => task.id), [1, 2, 3]);
      expect(state.tasks[1].title, 'Updated Task 2');
      expect(state.hasNext, isFalse);
      expect(built.repo.lastPage, 1);
    },
  );

  test('load-more failure keeps loaded tasks visible and retryable', () async {
    final built = build();
    var failNext = true;
    built.repo.fetchTasksHandler =
        ({
          required int page,
          required int size,
          int? projectId,
          required List<TaskStatus> statuses,
        }) async {
          if (page == 0) {
            return Result.success(
              _page(0, [_task(1)], totalCount: 2, hasNext: true),
            );
          }
          if (failNext) {
            return const Result.failure(ServerFailure(statusCode: 500));
          }
          return Result.success(
            _page(1, [_task(2)], totalCount: 2, hasNext: false),
          );
        };
    keepListAlive(built.container);
    await built.container.read(listProvider.future);

    await built.container.read(listProvider.notifier).loadNextPage();
    var state = built.container.read(listProvider).value!;
    expect(state.tasks.single.id, 1);
    expect(state.loadMoreFailure, isA<ServerFailure>());

    failNext = false;
    await built.container.read(listProvider.notifier).loadNextPage();
    state = built.container.read(listProvider).value!;
    expect(state.tasks.map((task) => task.id), [1, 2]);
    expect(state.loadMoreFailure, isNull);
  });

  test('initial repository failure surfaces as AsyncError', () async {
    final built = build();
    built.repo.fetchTasksHandler =
        ({
          required int page,
          required int size,
          int? projectId,
          required List<TaskStatus> statuses,
        }) async => const Result.failure(OfflineFailure());
    keepListAlive(built.container);

    await expectLater(
      built.container.read(listProvider.future),
      throwsA(isA<OfflineFailure>()),
    );
    expect(
      built.container.read(listProvider),
      isA<AsyncError<TaskListState>>(),
    );
  });

  test('task detail loads and refreshes the requested id', () async {
    final built = build();
    var title = 'Before';
    built.repo.fetchTaskHandler = (id) async =>
        Result.success(_task(id, title: title));
    final provider = taskDetailControllerProvider((userId: 7, taskId: 42));
    final subscription = built.container.listen(provider, (previous, next) {});
    addTearDown(subscription.close);

    expect((await built.container.read(provider.future)).title, 'Before');
    title = 'After';
    await built.container.read(provider.notifier).refresh();

    expect(built.container.read(provider).value!.title, 'After');
    expect(built.repo.fetchTaskCalls, 2);
  });
}
