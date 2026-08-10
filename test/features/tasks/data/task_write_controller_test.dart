import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/tasks/data/task_write_controller.dart';
import 'package:tracker_flutter/features/tasks/data/tasks_repository.dart';
import 'package:tracker_flutter/features/tasks/domain/task.dart';
import 'package:tracker_flutter/features/tasks/domain/task_write_input.dart';

import '../../../helpers/fake_tasks_repository.dart';

Task _task(int id) => Task.fromJson({
  'id': id,
  'title': 'Created task',
  'description': null,
  'riskLevel': 'LOW',
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
  test('a second create tap while submitting cannot issue another POST', () async {
    final completer = Completer<Result<TaskCreateOutcome>>();
    final repository = FakeTasksRepository()
      ..createTaskHandler = (input, projectId) => completer.future;
    final container = ProviderContainer(
      overrides: [tasksRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      taskWriteControllerProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);

    final controller = container.read(taskWriteControllerProvider.notifier);
    final first = controller.create(
      userId: 1,
      input: TaskWriteInput.defaults(),
      projectId: 7,
    );
    final second = await controller.create(
      userId: 1,
      input: TaskWriteInput.defaults(),
      projectId: 7,
    );

    expect(second, isNull);
    expect(repository.createTaskCalls, 1);
    expect(container.read(taskWriteControllerProvider).isSubmitting, isTrue);

    completer.complete(
      Result.success(
        TaskCreateOutcome(task: _task(10), projectAssignmentFailure: null),
      ),
    );
    expect((await first)!.id, 10);
    expect(container.read(taskWriteControllerProvider).isSubmitting, isFalse);
  });
}
