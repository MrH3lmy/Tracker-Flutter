import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../auth/data/auth_repository.dart';
import '../data/task_write_controller.dart';
import '../data/tasks_controller.dart';
import '../domain/task.dart';
import '../domain/task_write_input.dart';
import 'tasks_screen.dart';

class TaskCreateScreen extends StatelessWidget {
  const TaskCreateScreen({super.key, required this.projectId});

  final int? projectId;

  @override
  Widget build(BuildContext context) => TaskFormScreen(projectId: projectId);
}

class TaskEditScreen extends ConsumerWidget {
  const TaskEditScreen({super.key, required this.taskId});

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
      data: (context, task) => TaskFormScreen(
        key: ValueKey('task-form-${task.id}-${task.updatedDate}'),
        task: task,
        projectId: task.projectId,
      ),
    );
  }
}

class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.task, required this.projectId});

  final Task? task;
  final int? projectId;

  bool get isEditing => task != null;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _estimateController;
  late final TextEditingController _riskReasonController;
  late final TextEditingController _trackController;
  late final TextEditingController _phaseController;
  late final TextEditingController _blockedReasonController;
  late final TextEditingController _waitingOnController;
  late final TaskWriteInput _preserved;

  late TaskStatus _status;
  late TaskArea _area;
  late TaskEffort _effort;
  late TaskRiskLevel _riskLevel;
  late bool _important;
  DateTime? _startDate;
  DateTime? _dueDate;
  DateTime? _followUpDate;
  String? _crossFieldError;

  @override
  void initState() {
    super.initState();
    _preserved = widget.task == null
        ? TaskWriteInput.defaults()
        : TaskWriteInput.fromTask(widget.task!);
    _titleController = TextEditingController(text: _preserved.title);
    _descriptionController = TextEditingController(
      text: _preserved.description ?? '',
    );
    _estimateController = TextEditingController(
      text: _preserved.estimatedMinutes?.toString() ?? '',
    );
    _riskReasonController = TextEditingController(
      text: _preserved.riskReason ?? '',
    );
    _trackController = TextEditingController(text: _preserved.track ?? '');
    _phaseController = TextEditingController(text: _preserved.phase ?? '');
    _blockedReasonController = TextEditingController(
      text: _preserved.blockedReason ?? '',
    );
    _waitingOnController = TextEditingController(
      text: _preserved.waitingOn ?? '',
    );
    _status = _preserved.status;
    _area = _preserved.area;
    _effort = _preserved.effort;
    _riskLevel = _preserved.riskLevel;
    _important = _preserved.important;
    _startDate = _preserved.startDate;
    _dueDate = _preserved.dueDate;
    _followUpDate = _preserved.followUpDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _estimateController.dispose();
    _riskReasonController.dispose();
    _trackController.dispose();
    _phaseController.dispose();
    _blockedReasonController.dispose();
    _waitingOnController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_validateDates()) return;

    final userId = ref.read(authRepositoryProvider).userOrNull?.id;
    if (userId == null) return;

    final estimate = _estimateController.text.trim().isEmpty
        ? null
        : int.tryParse(_estimateController.text.trim());
    final input = TaskWriteInput(
      title: _titleController.text,
      description: _descriptionController.text,
      dueDate: _dueDate,
      startDate: _startDate,
      estimatedMinutes: estimate,
      actualMinutes: _preserved.actualMinutes,
      riskLevel: _riskLevel,
      riskReason: _riskReasonController.text,
      track: _trackController.text,
      phase: _phaseController.text,
      parentTaskId: _preserved.parentTaskId,
      important: _important,
      status: _status,
      area: _area,
      effort: _effort,
      blockedReason: _blockedReasonController.text,
      waitingOn: _waitingOnController.text,
      followUpDate: _followUpDate,
      recurrence: _preserved.recurrence,
    );

    final controller = ref.read(taskWriteControllerProvider.notifier);
    final saved = widget.task == null
        ? await controller.create(
            userId: userId,
            input: input,
            projectId: widget.projectId,
          )
        : await controller.update(
            userId: userId,
            taskId: widget.task!.id,
            projectId: widget.projectId,
            input: input,
          );

    if (!mounted || saved == null) return;
    final warning = ref.read(taskWriteControllerProvider).warning;
    if (warning != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Task created, but it could not be added to the selected project.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditing ? 'Task updated' : 'Task created'),
        ),
      );
    }
    context.go('/tasks/${saved.id}');
  }

  bool _validateDates() {
    String? error;
    if (_startDate != null &&
        _dueDate != null &&
        _startDate!.isAfter(_dueDate!)) {
      error = 'Start date must be on or before due date.';
    } else if (_startDate != null &&
        _followUpDate != null &&
        _followUpDate!.isBefore(_startDate!)) {
      error = 'Follow-up date must be on or after start date.';
    }
    setState(() => _crossFieldError = error);
    return error == null;
  }

  Future<void> _pickDate(_DateField field) async {
    final current = switch (field) {
      _DateField.start => _startDate,
      _DateField.due => _dueDate,
      _DateField.followUp => _followUpDate,
    };
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
    );
    if (picked == null || !mounted) return;
    setState(() {
      switch (field) {
        case _DateField.start:
          _startDate = picked;
        case _DateField.due:
          _dueDate = picked;
        case _DateField.followUp:
          _followUpDate = picked;
      }
      _crossFieldError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final writeState = ref.watch(taskWriteControllerProvider);
    final validation = writeState.failure is ValidationFailure
        ? writeState.failure as ValidationFailure
        : null;
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: writeState.isSubmitting
                    ? null
                    : () => widget.task == null
                          ? context.go('/tasks')
                          : context.go('/tasks/${widget.task!.id}'),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  widget.isEditing ? 'Edit task' : 'New task',
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          if (widget.projectId != null && !widget.isEditing) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This task will be added to the selected project.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _titleController,
            autofocus: !widget.isEditing,
            maxLength: 255,
            decoration: InputDecoration(
              labelText: 'Title',
              errorText: validation?.fieldErrors['title'],
            ),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) return 'Title is required';
              if (trimmed.length > 255) {
                return 'Title must be at most 255 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: AppSpacing.md),
          _DateRow(
            label: 'Start date',
            value: _startDate,
            onPick: () => _pickDate(_DateField.start),
            onClear: () => setState(() => _startDate = null),
          ),
          _DateRow(
            label: 'Due date',
            value: _dueDate,
            onPick: () => _pickDate(_DateField.due),
            onClear: () => setState(() => _dueDate = null),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _estimateController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Estimate (minutes)',
              errorText: validation?.fieldErrors['estimatedMinutes'],
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final parsed = int.tryParse(value.trim());
              if (parsed == null || parsed < 0) {
                return 'Estimate must be 0 or more';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<TaskStatus>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              for (final status in activeTaskStatuses)
                DropdownMenuItem(
                  value: status,
                  child: Text(taskStatusLabel(status)),
                ),
            ],
            onChanged: writeState.isSubmitting
                ? null
                : (value) => setState(() => _status = value ?? _status),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<TaskArea>(
            initialValue: _area,
            decoration: const InputDecoration(labelText: 'Area'),
            items: [
              for (final area in TaskArea.values)
                DropdownMenuItem(value: area, child: Text(_areaLabel(area))),
            ],
            onChanged: writeState.isSubmitting
                ? null
                : (value) => setState(() => _area = value ?? _area),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<TaskEffort>(
            initialValue: _effort,
            decoration: const InputDecoration(labelText: 'Effort'),
            items: [
              for (final effort in TaskEffort.values.where(
                (value) => value != TaskEffort.unknown,
              ))
                DropdownMenuItem(
                  value: effort,
                  child: Text(_effortLabel(effort)),
                ),
            ],
            onChanged: writeState.isSubmitting
                ? null
                : (value) => setState(() => _effort = value ?? _effort),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<TaskRiskLevel>(
            initialValue: _riskLevel,
            decoration: const InputDecoration(labelText: 'Risk'),
            items: [
              for (final risk in TaskRiskLevel.values.where(
                (value) => value != TaskRiskLevel.unknown,
              ))
                DropdownMenuItem(value: risk, child: Text(_riskLabel(risk))),
            ],
            onChanged: writeState.isSubmitting
                ? null
                : (value) => setState(() => _riskLevel = value ?? _riskLevel),
          ),
          if (_riskLevel == TaskRiskLevel.high ||
              _riskLevel == TaskRiskLevel.critical) ...[
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _riskReasonController,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'Risk reason',
                errorText: validation?.fieldErrors['riskReason'],
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Risk reason is required for high or critical risk'
                  : null,
            ),
          ],
          if (_status == TaskStatus.blocked) ...[
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _blockedReasonController,
              decoration: const InputDecoration(labelText: 'Blocked reason'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Blocked reason is required when blocked'
                  : null,
            ),
          ],
          if (_status == TaskStatus.waiting) ...[
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _waitingOnController,
              decoration: const InputDecoration(labelText: 'Waiting on'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Waiting on is required when waiting'
                  : null,
            ),
            _DateRow(
              label: 'Follow-up date',
              value: _followUpDate,
              onPick: () => _pickDate(_DateField.followUp),
              onClear: () => setState(() => _followUpDate = null),
              required: true,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _trackController,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Track'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _phaseController,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Phase'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Important'),
            value: _important,
            onChanged: writeState.isSubmitting
                ? null
                : (value) => setState(() => _important = value),
          ),
          if (_preserved.recurrence != null && widget.isEditing) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Recurrence is preserved by this edit. Recurrence editing will be added in a later slice.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (_crossFieldError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _crossFieldError!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          if (writeState.failure != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _failureMessage(writeState.failure!),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: writeState.isSubmitting ? null : _submit,
            child: writeState.isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.isEditing ? 'Save changes' : 'Create task'),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

enum _DateField { start, due, followUp }

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
    this.required = false,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  value == null
                      ? '$label${required ? ' *' : ''}'
                      : '$label: ${formatTaskDate(value!)}',
                ),
              ),
            ),
          ),
          if (value != null)
            IconButton(
              tooltip: 'Clear $label',
              onPressed: onClear,
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
    );
  }
}

String _areaLabel(TaskArea value) => switch (value) {
  TaskArea.work => 'Work',
  TaskArea.study => 'Study',
  TaskArea.personal => 'Personal',
  TaskArea.health => 'Health',
  TaskArea.family => 'Family',
};

String _effortLabel(TaskEffort value) => switch (value) {
  TaskEffort.quick => 'Quick',
  TaskEffort.medium => 'Medium',
  TaskEffort.deepWork => 'Deep work',
  TaskEffort.large => 'Large',
  TaskEffort.unknown => 'Unknown',
};

String _riskLabel(TaskRiskLevel value) => switch (value) {
  TaskRiskLevel.low => 'Low',
  TaskRiskLevel.medium => 'Medium',
  TaskRiskLevel.high => 'High',
  TaskRiskLevel.critical => 'Critical',
  TaskRiskLevel.unknown => 'Unknown',
};

String _failureMessage(AppFailure failure) =>
    failure.message ??
    (failure is ValidationFailure
        ? 'Please check the highlighted fields and try again.'
        : 'Could not save the task. Please try again.');