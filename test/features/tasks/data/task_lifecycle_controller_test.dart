import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/tasks/data/task_lifecycle_controller.dart';
import 'package:tracker_flutter/features/tasks/data/tasks_controller.dart';
import 'package:tracker_flutter/features/tasks/data/tasks_repository.dart';
import 'package:tracker_flutter/features/tasks/domain/task.dart';

import '../../../helpers/fake_tasks_repository.dart';

Task _task(int id, String status) => Task.fromJson({
  'id': id,
  'title': 'Lifecycle task',
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

ProviderContainer _container(FakeTasksRepository repository) {
  final container = ProviderContainer(
    overrides: [tasksRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _primeDetail(
  ProviderContainer container,
  FakeTasksRepository repository,
  Task task,
) async {
  repository.fetchTaskHandler = (id) async => Result.success(task);
  final provider = taskDetailControllerProvider((userId: 1, taskId: task.id));
  final subscription = container.listen(provider, (previous, next) {});
  addTearDown(subscription.close);
  await container.read(provider.future);
}

void main() {
  test('complete uses the dedicated completion endpoint', () async {
    final original = _task(42, 'IN_PROGRESS');
    final completed = _task(42, 'DONE');
    final repository = FakeTasksRepository()
      ..completeTaskHandler = (id) async => Result.success(completed);
    final container = _container(repository);
    await _primeDetail(container, repository, original);
    final subscription = container.listen(
      taskLifecycleControllerProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);

    final result = await container
        .read(taskLifecycleControllerProvider.notifier)
        .complete(userId: 1, task: original);

    expect(result!.status, TaskStatus.done);
    expect(repository.completeTaskCalls, 1);
    expect(repository.updateTaskStatusCalls, 0);
  });

  test('cancel and reopen use explicit backend status transitions', () async {
    final active = _task(42, 'IN_PROGRESS');
    final cancelled = _task(42, 'CANCELLED');
    final reopened = _task(42, 'NOT_STARTED');
    final repository = FakeTasksRepository()
      ..updateTaskStatusHandler = (id, status) async =>
          Result.success(status == TaskStatus.cancelled ? cancelled : reopened);
    final container = _container(repository);
    await _primeDetail(container, repository, active);
    final subscription = container.listen(
      taskLifecycleControllerProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    final controller = container.read(taskLifecycleControllerProvider.notifier);

    await controller.cancel(userId: 1, task: active);
    expect(repository.lastStatus, TaskStatus.cancelled);
    await controller.reopen(userId: 1, task: cancelled);
    expect(repository.lastStatus, TaskStatus.notStarted);
  });

  test('a second lifecycle tap cannot issue a duplicate mutation', () async {
    final task = _task(42, 'IN_PROGRESS');
    final completer = Completer<Result<Task>>();
    final repository = FakeTasksRepository()
      ..completeTaskHandler = (id) => completer.future;
    final container = _container(repository);
    await _primeDetail(container, repository, task);
    final subscription = container.listen(
      taskLifecycleControllerProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    final controller = container.read(taskLifecycleControllerProvider.notifier);

    final first = controller.complete(userId: 1, task: task);
    final second = await controller.complete(userId: 1, task: task);

    expect(second, isNull);
    expect(repository.completeTaskCalls, 1);
    completer.complete(Result.success(_task(42, 'DONE')));
    expect((await first)!.status, TaskStatus.done);
  });
}
