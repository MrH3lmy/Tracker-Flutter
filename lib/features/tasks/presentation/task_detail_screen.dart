import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../auth/data/auth_repository.dart';
import '../data/tasks_controller.dart';
import '../domain/task.dart';
import 'tasks_screen.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});

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
    final value = ref.watch(provider);

    return AsyncStateView<Task>(
      value: value,
      onRetry: () => ref.read(provider.notifier).refresh(),
      data: (context, task) => _TaskDetail(task: task),
    );
  }
}

class _TaskDetail extends StatelessWidget {
  const _TaskDetail({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/tasks');
              }
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to tasks'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(task.title, style: theme.textTheme.headlineSmall),
            ),
            if (task.important)
              Icon(
                Icons.star,
                color: theme.colorScheme.primary,
                semanticLabel: 'Important',
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            Chip(label: Text(taskStatusLabel(task.status))),
            if (task.overdue) const Chip(label: Text('Overdue')),
            if (task.urgent) const Chip(label: Text('Urgent')),
            if (task.priorityScore > 0)
              Chip(label: Text('Priority ${task.priorityScore}')),
          ],
        ),
        if (task.description?.trim().isNotEmpty == true) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Description', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(task.description!),
        ],
        const SizedBox(height: AppSpacing.lg),
        _DetailCard(
          title: 'Schedule',
          rows: [
            if (task.startDate != null)
              ('Start', formatTaskDate(task.startDate!)),
            if (task.dueDate != null) ('Due', formatTaskDate(task.dueDate!)),
            if (task.followUpDate != null)
              ('Follow-up', formatTaskDate(task.followUpDate!)),
            if (task.daysLeft != null) ('Days left', '${task.daysLeft}'),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _DetailCard(
          title: 'Work',
          rows: [
            if (task.estimatedMinutes != null)
              ('Estimate', '${task.estimatedMinutes} min'),
            if (task.actualMinutes != null)
              ('Actual', '${task.actualMinutes} min'),
            ('Risk', _riskLabel(task.riskLevel)),
            if (task.effort != null) ('Effort', _effortLabel(task.effort!)),
            if (task.track != null) ('Track', task.track!),
            if (task.phase != null) ('Phase', task.phase!),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _DetailCard(
          title: 'Structure',
          rows: [
            if (task.projectId != null) ('Project', '#${task.projectId}'),
            if (task.parentTaskId != null)
              ('Parent task', '#${task.parentTaskId}'),
            if (task.boardColumnId != null)
              ('Board column', '#${task.boardColumnId}'),
            ('Subtasks', '${task.completedSubtaskCount}/${task.subtaskCount}'),
            if (task.dependencyIds.isNotEmpty)
              ('Dependencies', task.dependencyIds.join(', ')),
            if (task.blockingTaskIds.isNotEmpty)
              ('Blocks', task.blockingTaskIds.join(', ')),
          ],
        ),
        if (task.blockedReason != null || task.waitingOn != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _DetailCard(
            title: 'Blockers',
            rows: [
              if (task.blockedReason != null)
                ('Blocked reason', task.blockedReason!),
              if (task.waitingOn != null) ('Waiting on', task.waitingOn!),
            ],
          ),
        ],
        if (task.recurrence != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _DetailCard(
            title: 'Recurrence',
            rows: [
              ('Frequency', _recurrenceLabel(task.recurrence!.frequency)),
              ('Interval', '${task.recurrence!.interval}'),
              if (task.recurrence!.nextDueDate != null)
                ('Next due', formatTaskDate(task.recurrence!.nextDueDate!)),
              ('Current streak', '${task.recurrence!.currentStreak}'),
              ('Longest streak', '${task.recurrence!.longestStreak}'),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        row.$1,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                    Expanded(child: Text(row.$2)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _riskLabel(TaskRiskLevel value) => switch (value) {
  TaskRiskLevel.low => 'Low',
  TaskRiskLevel.medium => 'Medium',
  TaskRiskLevel.high => 'High',
  TaskRiskLevel.critical => 'Critical',
  TaskRiskLevel.unknown => 'Unknown',
};

String _effortLabel(TaskEffort value) => switch (value) {
  TaskEffort.quick => 'Quick',
  TaskEffort.medium => 'Medium',
  TaskEffort.deepWork => 'Deep work',
  TaskEffort.large => 'Large',
  TaskEffort.unknown => 'Unknown',
};

String _recurrenceLabel(RecurrenceFrequency value) => switch (value) {
  RecurrenceFrequency.daily => 'Daily',
  RecurrenceFrequency.weekly => 'Weekly',
  RecurrenceFrequency.monthly => 'Monthly',
  RecurrenceFrequency.annual => 'Annual',
  RecurrenceFrequency.unknown => 'Unknown',
};
