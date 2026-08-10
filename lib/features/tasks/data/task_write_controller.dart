import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_failure.dart';
import '../domain/task.dart';
import '../domain/task_write_input.dart';
import 'tasks_controller.dart';
import 'tasks_repository.dart';

class TaskWriteState {
  const TaskWriteState({
    this.isSubmitting = false,
    this.failure,
    this.warning,
    this.task,
  });

  final bool isSubmitting;
  final AppFailure? failure;
  final AppFailure? warning;
  final Task? task;
}

class TaskWriteController extends Notifier<TaskWriteState> {
  @override
  TaskWriteState build() => const TaskWriteState();

  Future<Task?> create({
    required int userId,
    required TaskWriteInput input,
    int? projectId,
  }) async {
    if (state.isSubmitting) return null;
    state = const TaskWriteState(isSubmitting: true);

    final result = await ref
        .read(tasksRepositoryProvider)
        .createTask(input, projectId: projectId);

    final outcome = result.valueOrNull;
    if (outcome == null) {
      state = TaskWriteState(failure: result.failureOrNull);
      return null;
    }

    _invalidateTaskLists(userId: userId, projectId: projectId);
    state = TaskWriteState(
      task: outcome.task,
      warning: outcome.projectAssignmentFailure,
    );
    return outcome.task;
  }

  Future<Task?> update({
    required int userId,
    required int taskId,
    required int? projectId,
    required TaskWriteInput input,
  }) async {
    if (state.isSubmitting) return null;
    state = const TaskWriteState(isSubmitting: true);

    final detailKey = (userId: userId, taskId: taskId);
    final existing = ref.read(taskDetailControllerProvider(detailKey)).value;
    final safeInput = input.boardColumnId == null
        ? input.withBoardColumnId(existing?.boardColumnId)
        : input;

    final result = await ref
        .read(tasksRepositoryProvider)
        .updateTask(taskId, safeInput);
    final task = result.valueOrNull;
    if (task == null) {
      state = TaskWriteState(failure: result.failureOrNull);
      return null;
    }

    _invalidateTaskLists(userId: userId, projectId: projectId);
    ref.read(taskDetailControllerProvider(detailKey).notifier).replace(task);
    state = TaskWriteState(task: task);
    return task;
  }

  void clearFeedback() {
    if (state.isSubmitting) return;
    state = const TaskWriteState();
  }

  void _invalidateTaskLists({required int userId, required int? projectId}) {
    ref.invalidate(
      taskListControllerProvider((userId: userId, projectId: null)),
    );
    if (projectId != null) {
      ref.invalidate(
        taskListControllerProvider((userId: userId, projectId: projectId)),
      );
    }
  }
}

final taskWriteControllerProvider =
    NotifierProvider.autoDispose<TaskWriteController, TaskWriteState>(
      TaskWriteController.new,
    );
