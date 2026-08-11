import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../auth/data/auth_repository.dart';
import '../data/task_lifecycle_controller.dart';
import '../data/tasks_controller.dart';
import '../domain/task.dart';
import 'task_detail_screen.dart';

class TaskLifecycleDetailScreen extends ConsumerWidget {
  const TaskLifecycleDetailScreen({super.key, required this.taskId});

  final int taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(
      authRepositoryProvider.select((session) => session.userOrNull?.id),
    );
    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final detail = ref.watch(
      taskDetailControllerProvider((userId: userId, taskId: taskId)),
    );
    final task = detail.value;

    return Column(
      children: [
        Expanded(child: TaskDetailScreen(taskId: taskId)),
        if (task != null) _LifecycleBar(userId: userId, task: task),
      ],
    );
  }
}

class _LifecycleBar extends ConsumerWidget {
  const _LifecycleBar({required this.userId, required this.task});

  final int userId;
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = taskLifecycleControllerProvider;
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    Future<void> run(Future<Task?> Function() operation) async {
      final updated = await operation();
      if (!context.mounted || updated == null) return;
      final message = updated.status == TaskStatus.done
          ? 'Task completed'
          : updated.status == TaskStatus.cancelled
          ? 'Task cancelled'
          : 'Task reopened';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    return Material(
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.failure != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    state.failure!.message ?? 'Could not update task status.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (task.archived)
                FilledButton.tonalIcon(
                  onPressed: state.isSubmitting
                      ? null
                      : () => run(
                          () => controller.reopen(userId: userId, task: task),
                        ),
                  icon: const Icon(Icons.unarchive_outlined),
                  label: const Text('Reopen task'),
                )
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: state.isSubmitting
                          ? null
                          : () => run(
                              () => controller.complete(
                                userId: userId,
                                task: task,
                              ),
                            ),
                      icon: const Icon(Icons.check),
                      label: Text(
                        task.recurrence == null
                            ? 'Complete task'
                            : 'Complete occurrence',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: state.isSubmitting
                          ? null
                          : () => run(
                              () => controller.cancel(
                                userId: userId,
                                task: task,
                              ),
                            ),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel task'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
