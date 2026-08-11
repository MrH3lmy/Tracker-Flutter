import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/result/result.dart';
import '../domain/task.dart';
import 'tasks_controller.dart';
import 'tasks_repository.dart';

class TaskLifecycleState {
  const TaskLifecycleState({this.isSubmitting = false, this.failure});

  final bool isSubmitting;
  final AppFailure? failure;
}

class TaskLifecycleController extends Notifier<TaskLifecycleState> {
  @override
  TaskLifecycleState build() => const TaskLifecycleState();

  Future<Task?> complete({required int userId, required Task task}) {
    return _run(
      userId: userId,
      task: task,
      operation: () => ref.read(tasksRepositoryProvider).completeTask(task.id),
    );
  }

  Future<Task?> cancel({required int userId, required Task task}) {
    return _run(
      userId: userId,
      task: task,
      operation: () => ref
          .read(tasksRepositoryProvider)
          .updateTaskStatus(task.id, TaskStatus.cancelled),
    );
  }

  Future<Task?> reopen({required int userId, required Task task}) {
    return _run(
      userId: userId,
      task: task,
      operation: () => ref
          .read(tasksRepositoryProvider)
          .updateTaskStatus(task.id, TaskStatus.notStarted),
    );
  }

  Future<Task?> _run({
    required int userId,
    required Task task,
    required Future<Result<Task>> Function() operation,
  }) async {
    if (state.isSubmitting) return null;
    state = const TaskLifecycleState(isSubmitting: true);

    final result = await operation();
    final updated = result.valueOrNull;
    if (updated == null) {
      state = TaskLifecycleState(failure: result.failureOrNull);
      return null;
    }

    ref
        .read(
          taskDetailControllerProvider((userId: userId, taskId: task.id)).notifier,
        )
        .replace(updated);
    ref.invalidate(
      taskListControllerProvider((userId: userId, projectId: null)),
    );
    if (task.projectId != null) {
      ref.invalidate(
        taskListControllerProvider((
          userId: userId,
          projectId: task.projectId,
        )),
      );
    }
    ref.invalidate(taskArchiveControllerProvider(userId));
    state = const TaskLifecycleState();
    return updated;
  }
}

final taskLifecycleControllerProvider =
    NotifierProvider.autoDispose<TaskLifecycleController, TaskLifecycleState>(
      TaskLifecycleController.new,
    );
