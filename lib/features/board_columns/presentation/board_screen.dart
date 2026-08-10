import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../auth/data/auth_repository.dart';
import '../../projects/data/selected_project_controller.dart';
import '../../tasks/data/tasks_controller.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/tasks_screen.dart';
import '../data/board_columns_controller.dart';
import '../domain/board_column.dart';

/// Tracker-BE owns one global board layout per user. Tasks themselves may be
/// project-scoped, so this screen keeps the columns global while filtering
/// the task feed by the currently selected project when one exists.
class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(
      authRepositoryProvider.select((session) => session.userOrNull?.id),
    );
    final projectId = ref.watch(selectedProjectControllerProvider);

    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final columnsProvider = boardColumnsControllerProvider(userId);
    final tasksProvider = taskListControllerProvider((
      userId: userId,
      projectId: projectId,
    ));

    return AsyncStateView<List<BoardColumn>>(
      value: ref.watch(columnsProvider),
      onRetry: () => ref.read(columnsProvider.notifier).refresh(),
      isEmpty: (columns) => columns.isEmpty,
      emptyBuilder: (context) => _RefreshableEmptyState(
        onRefresh: () => ref.read(columnsProvider.notifier).refresh(),
      ),
      data: (context, columns) => AsyncStateView<TaskListState>(
        value: ref.watch(tasksProvider),
        onRetry: () => ref.read(tasksProvider.notifier).refresh(),
        data: (context, tasksState) => _BoardColumnsView(
          columns: columns,
          tasksState: tasksState,
          projectId: projectId,
          onRefresh: () async {
            await Future.wait([
              ref.read(columnsProvider.notifier).refresh(),
              ref.read(tasksProvider.notifier).refresh(),
            ]);
          },
          onLoadMore: () => ref.read(tasksProvider.notifier).loadNextPage(),
        ),
      ),
    );
  }
}

class _BoardColumnsView extends StatelessWidget {
  const _BoardColumnsView({
    required this.columns,
    required this.tasksState,
    required this.projectId,
    required this.onRefresh,
    required this.onLoadMore,
  });

  final List<BoardColumn> columns;
  final TaskListState tasksState;
  final int? projectId;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;

  static const _columnWidth = 280.0;
  static const _columnHeight = 520.0;

  @override
  Widget build(BuildContext context) {
    final tasksByColumn = <int, List<Task>>{
      for (final column in columns) column.id: <Task>[],
    };
    var unassignedCount = 0;
    for (final task in tasksState.tasks) {
      final columnId = task.boardColumnId;
      final bucket = columnId == null ? null : tasksByColumn[columnId];
      if (bucket == null) {
        unassignedCount++;
      } else {
        bucket.add(task);
      }
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            projectId == null ? 'All active tasks' : 'Selected project board',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${tasksState.tasks.length} of ${tasksState.meta.totalCount} tasks loaded',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (unassignedCount > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$unassignedCount loaded task${unassignedCount == 1 ? '' : 's'} '
              'do not currently belong to a board column.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: _columnHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: columns.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) {
                final column = columns[index];
                return _ColumnCard(
                  column: column,
                  tasks: tasksByColumn[column.id] ?? const <Task>[],
                  width: _columnWidth,
                );
              },
            ),
          ),
          if (tasksState.isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (tasksState.loadMoreFailure != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                children: [
                  Text(
                    tasksState.loadMoreFailure!.message ??
                        'Could not load more tasks.',
                  ),
                  TextButton(onPressed: onLoadMore, child: const Text('Try again')),
                ],
              ),
            )
          else if (tasksState.hasNext)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Center(
                child: FilledButton.tonal(
                  onPressed: onLoadMore,
                  child: const Text('Load more tasks'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ColumnCard extends StatelessWidget {
  const _ColumnCard({
    required this.column,
    required this.tasks,
    required this.width,
  });

  final BoardColumn column;
  final List<Task> tasks;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '${column.name} column, ${tasks.length} tasks',
      child: SizedBox(
        width: width,
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(AppRadius.md),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(column.name, style: theme.textTheme.titleMedium),
                    ),
                    Text('${tasks.length}', style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _statusLabel(column.status),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: tasks.isEmpty
                      ? Center(
                          child: Text(
                            'No tasks',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: tasks.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppSpacing.xs),
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                ),
                                title: Text(
                                  task.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: task.dueDate == null
                                    ? null
                                    : Text('Due ${formatTaskDate(task.dueDate!)}'),
                                onTap: () => context.push('/tasks/${task.id}'),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _statusLabel(ColumnStatus status) => switch (status) {
    ColumnStatus.backlog => 'Backlog',
    ColumnStatus.notStarted => 'Not started',
    ColumnStatus.inProgress => 'In progress',
    ColumnStatus.waiting => 'Waiting',
    ColumnStatus.blocked => 'Blocked',
    ColumnStatus.done => 'Done',
    ColumnStatus.cancelled => 'Cancelled',
    ColumnStatus.unknown => 'Unknown status',
  };
}

class _RefreshableEmptyState extends StatelessWidget {
  const _RefreshableEmptyState({required this.onRefresh});

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
                  Icons.view_column_outlined,
                  size: 40,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No board columns yet',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your board columns will show up here.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
