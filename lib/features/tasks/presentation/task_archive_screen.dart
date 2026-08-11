import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../auth/data/auth_repository.dart';
import '../data/tasks_controller.dart';
import '../domain/task.dart';
import 'tasks_screen.dart';

class TaskArchiveScreen extends ConsumerWidget {
  const TaskArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(
      authRepositoryProvider.select((session) => session.userOrNull?.id),
    );
    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final provider = taskArchiveControllerProvider(userId);
    return AsyncStateView<TaskListState>(
      value: ref.watch(provider),
      onRetry: () => ref.read(provider.notifier).refresh(),
      isEmpty: (state) => state.tasks.isEmpty,
      emptyBuilder: (context) => _EmptyArchive(
        onRefresh: () => ref.read(provider.notifier).refresh(),
      ),
      data: (context, state) => _ArchiveList(
        state: state,
        onRefresh: () => ref.read(provider.notifier).refresh(),
        onLoadMore: () => ref.read(provider.notifier).loadNextPage(),
      ),
    );
  }
}

class _ArchiveList extends StatelessWidget {
  const _ArchiveList({
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
  });

  final TaskListState state;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
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
            return Row(
              children: [
                IconButton(
                  tooltip: 'Back to active tasks',
                  onPressed: () => context.go('/tasks'),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Archive',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Text('${state.tasks.length} of ${state.meta.totalCount}'),
              ],
            );
          }
          if (index == state.tasks.length + 1) {
            if (state.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (state.loadMoreFailure != null) {
              return Center(
                child: OutlinedButton(
                  onPressed: onLoadMore,
                  child: const Text('Try again'),
                ),
              );
            }
            if (!state.hasNext) return const SizedBox(height: AppSpacing.md);
            return Center(
              child: FilledButton.tonal(
                onPressed: onLoadMore,
                child: const Text('Load more'),
              ),
            );
          }

          final task = state.tasks[index - 1];
          return Card(
            child: ListTile(
              title: Text(task.title),
              subtitle: Text(taskStatusLabel(task.status)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/tasks/${task.id}'),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyArchive extends StatelessWidget {
  const _EmptyArchive({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Icon(
            Icons.archive_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Archive is empty',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Completed and cancelled tasks will appear here.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton(
              onPressed: () => context.go('/tasks'),
              child: const Text('Back to active tasks'),
            ),
          ),
        ],
      ),
    );
  }
}
