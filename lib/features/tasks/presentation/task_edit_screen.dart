import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../auth/data/auth_repository.dart';
import '../data/tasks_controller.dart';
import '../domain/task.dart';
import 'task_form_screen.dart';

/// Route-level guard for callers that type `/tasks/:id/edit` directly.
/// Lifecycle/archive changes belong to the next slice, so terminal or
/// unknown-status tasks cannot be silently mapped back to an active status.
class SafeTaskEditScreen extends ConsumerWidget {
  const SafeTaskEditScreen({super.key, required this.taskId});

  final int taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(
      authRepositoryProvider.select((session) => session.userOrNull?.id),
    );
    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final provider = taskDetailControllerProvider((
      userId: userId,
      taskId: taskId,
    ));
    return AsyncStateView<Task>(
      value: ref.watch(provider),
      onRetry: () => ref.read(provider.notifier).refresh(),
      data: (context, task) {
        if (!activeTaskStatuses.contains(task.status)) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: Text(
                'Editing completed, cancelled, or unknown-status tasks will be available with lifecycle controls in the next slice.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }
        return TaskFormScreen(
          key: ValueKey('task-form-${task.id}-${task.updatedDate}'),
          task: task,
          projectId: task.projectId,
        );
      },
    );
  }
}
