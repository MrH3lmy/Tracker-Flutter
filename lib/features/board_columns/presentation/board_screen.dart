import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../auth/data/auth_repository.dart';
import '../data/board_columns_controller.dart';
import '../domain/board_column.dart';

/// The Kanban foundation for epic #4 slice 2: the authenticated user's
/// global board-column layout.
///
/// This is deliberately *not* scoped to the selected project — Tracker-BE's
/// board/column model is per-user, not per-project (see
/// `BoardColumnsRepository`'s doc comment) — so nothing here reads
/// `selectedProjectControllerProvider`, and switching the selected project
/// elsewhere in the app has no effect on what renders here.
class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(
      authRepositoryProvider.select((session) => session.userOrNull?.id),
    );

    // The router normally prevents this screen from existing without an
    // authenticated user. Keep a defensive loading boundary here too: it
    // avoids ever binding the UI to an account-less/global column cache
    // during restoration or a logout transition.
    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final columnsProvider = boardColumnsControllerProvider(userId);
    final columnsAsync = ref.watch(columnsProvider);

    return AsyncStateView<List<BoardColumn>>(
      value: columnsAsync,
      onRetry: () => ref.read(columnsProvider.notifier).refresh(),
      isEmpty: (columns) => columns.isEmpty,
      emptyBuilder: (context) => _RefreshableEmptyState(
        onRefresh: () => ref.read(columnsProvider.notifier).refresh(),
      ),
      data: (context, columns) => _BoardColumnsView(
        columns: columns,
        onRefresh: () => ref.read(columnsProvider.notifier).refresh(),
      ),
    );
  }
}

class _BoardColumnsView extends StatelessWidget {
  const _BoardColumnsView({required this.columns, required this.onRefresh});

  final List<BoardColumn> columns;
  final Future<void> Function() onRefresh;

  static const _columnWidth = 260.0;
  static const _columnHeight = 480.0;

  @override
  Widget build(BuildContext context) {
    // Tracker-BE already orders this response by position (and
    // BoardColumnsRepository re-asserts that order defensively) — no
    // client-side sort decision to make here, unlike the Projects list.
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          SizedBox(
            height: _columnHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: columns.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) =>
                  _ColumnCard(column: columns[index], width: _columnWidth),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColumnCard extends StatelessWidget {
  const _ColumnCard({required this.column, required this.width});

  final BoardColumn column;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '${column.name} column, ${_statusLabel(column.status)}',
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
                Text(column.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _statusLabel(column.status),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: Center(
                    child: Text(
                      // Placeholder only — task cards are wired up in the
                      // next slice (paginated task list + task details),
                      // which groups the selected project's tasks across
                      // this same global column layout.
                      'Tasks will appear here in a future update.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
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

/// The empty state still needs to be scrollable (not just centered) for
/// [RefreshIndicator] to recognize a pull-to-refresh gesture with nothing
/// on screen to drag.
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
