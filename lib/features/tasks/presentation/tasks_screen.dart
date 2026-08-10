import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../auth/data/auth_repository.dart';
import '../data/tasks_controller.dart';
import '../domain/task.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key, required this.projectId});

  final int? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(
      authRepositoryProvider.select((session) => session.userOrNull?.id),
    );

    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final provider = taskListControllerProvider((
      userId: userId,
      projectId: projectId,
    ));
    final value = ref.watch(provider);

    return AsyncStateView<TaskListState>(
      value: value,
      onRetry: () => ref.read(provider.notifier).refresh(),
      isEmpty: (state) => state.tasks.isEmpty,
      emptyBuilder: (context) => _EmptyTasksState(
        projectId: projectId,
        onRefresh: () => ref.read(provider.notifier).refresh(),
      ),
      data: (context, state) => _TaskList(
        state: state,
        projectId: projectId,
        onRefresh: () => ref.read(provider.notifier).refresh(),
        onLoadMore: () => ref.read(provider.notifier).loadNextPage(),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.state,
    required this.projectId,
    required this.onRefresh,
    required this.onLoadMore,
  });

  final TaskListState state;
  final int? projectId;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: state.tasks.length + 2,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tasks', style: theme.textTheme.headlineSmall),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          projectId == null
                              ? 'All active tasks'
                              : 'Active tasks in selected project',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${state.tasks.length} of ${state.meta.totalCount}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: () => context.go('/tasks/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('New task'),
                  ),
                ],
              ),
            );
          }

          if (index == state.tasks.length + 1) {
            return _LoadMoreFooter(state: state, onLoadMore: onLoadMore);
          }

          final task = state.tasks[index - 1];
          return _TaskTile(task: task);
        },
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = <String>[
      taskStatusLabel(task.status),
      if (task.dueDate != null) 'Due ${formatTaskDate(task.dueDate!)}',
      if (task.estimatedMinutes != null) '${task.estimatedMinutes} min',
    ];

    return Card(
      child: ListTile(
        title: Row(
          children: [
            if (task.important) ...[
              Icon(
                Icons.star,
                size: 18,
                color: theme.colorScheme.primary,
                semanticLabel: 'Important',
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Text(details.join(' • ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/tasks/${task.id}'),
      ),
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.state, required this.onLoadMore});

  final TaskListState state;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.loadMoreFailure != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          children: [
            Text(
              state.loadMoreFailure!.message ?? 'Could not load more tasks.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: onLoadMore,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (!state.hasNext) {
      return const SizedBox(height: AppSpacing.md);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: FilledButton.tonal(
          onPressed: onLoadMore,
          child: const Text('Load more'),
        ),
      ),
    );
  }
}

class _EmptyTasksState extends StatelessWidget {
  const _EmptyTasksState({required this.projectId, required this.onRefresh});

  final int? projectId;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Icon(
                  Icons.checklist_outlined,
                  size: 40,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No active tasks',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  projectId == null
                      ? 'Active tasks will show up here.'
                      : 'The selected project has no active tasks.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: () => context.go('/tasks/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Create task'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String taskStatusLabel(TaskStatus status) => switch (status) {
  TaskStatus.backlog => 'Backlog',
  TaskStatus.notStarted => 'Not started',
  TaskStatus.inProgress => 'In progress',
  TaskStatus.waiting => 'Waiting',
  TaskStatus.blocked => 'Blocked',
  TaskStatus.done => 'Done',
  TaskStatus.cancelled => 'Cancelled',
  TaskStatus.unknown => 'Unknown status',
};

String formatTaskDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
