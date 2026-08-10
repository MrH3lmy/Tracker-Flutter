import 'task.dart';

class TaskWriteInput {
  const TaskWriteInput({
    required this.title,
    required this.description,
    required this.dueDate,
    required this.startDate,
    required this.estimatedMinutes,
    required this.actualMinutes,
    required this.riskLevel,
    required this.riskReason,
    required this.track,
    required this.phase,
    required this.parentTaskId,
    required this.important,
    required this.status,
    required this.area,
    required this.effort,
    required this.blockedReason,
    required this.waitingOn,
    required this.followUpDate,
    required this.recurrence,
  });

  factory TaskWriteInput.defaults() => const TaskWriteInput(
    title: '',
    description: null,
    dueDate: null,
    startDate: null,
    estimatedMinutes: null,
    actualMinutes: null,
    riskLevel: TaskRiskLevel.low,
    riskReason: null,
    track: null,
    phase: null,
    parentTaskId: null,
    important: false,
    status: TaskStatus.backlog,
    area: TaskArea.personal,
    effort: TaskEffort.medium,
    blockedReason: null,
    waitingOn: null,
    followUpDate: null,
    recurrence: null,
  );

  factory TaskWriteInput.fromTask(Task task) => TaskWriteInput(
    title: task.title,
    description: task.description,
    dueDate: task.dueDate,
    startDate: task.startDate,
    estimatedMinutes: task.estimatedMinutes,
    actualMinutes: task.actualMinutes,
    riskLevel: task.riskLevel == TaskRiskLevel.unknown
        ? TaskRiskLevel.low
        : task.riskLevel,
    riskReason: task.riskReason,
    track: task.track,
    phase: task.phase,
    parentTaskId: task.parentTaskId,
    important: task.important,
    status: activeTaskStatuses.contains(task.status)
        ? task.status
        : TaskStatus.backlog,
    area: task.area ?? TaskArea.personal,
    effort: task.effort == null || task.effort == TaskEffort.unknown
        ? TaskEffort.medium
        : task.effort!,
    blockedReason: task.blockedReason,
    waitingOn: task.waitingOn,
    followUpDate: task.followUpDate,
    recurrence: task.recurrence,
  );

  final String title;
  final String? description;
  final DateTime? dueDate;
  final DateTime? startDate;
  final int? estimatedMinutes;

  /// Not exposed in the first write form, but preserved on PUT so editing a
  /// different field cannot silently erase already-recorded actual time.
  final int? actualMinutes;
  final TaskRiskLevel riskLevel;
  final String? riskReason;
  final String? track;
  final String? phase;

  /// Parent/dependencies/recurrence editing are later concerns. Parent and
  /// recurrence are carried forward on PUT; dependencyIds is intentionally
  /// omitted from the request so Tracker-BE keeps the existing dependencies.
  final int? parentTaskId;
  final bool important;
  final TaskStatus status;
  final TaskArea area;
  final TaskEffort effort;
  final String? blockedReason;
  final String? waitingOn;
  final DateTime? followUpDate;
  final TaskRecurrence? recurrence;

  Map<String, dynamic> toRequestJson() => {
    'title': title.trim(),
    'description': _trimOrNull(description),
    'dueDate': _dateOnly(dueDate),
    'startDate': _dateOnly(startDate),
    'estimatedMinutes': estimatedMinutes,
    'actualMinutes': actualMinutes,
    'riskLevel': taskRiskLevelApiValue(riskLevel),
    'riskReason': _trimOrNull(riskReason),
    'track': _trimOrNull(track),
    'phase': _trimOrNull(phase),
    'parentTaskId': parentTaskId,
    'important': important,
    'status': taskStatusApiValue(status),
    'area': taskAreaApiValue(area),
    'effort': taskEffortApiValue(effort),
    'blockedReason': _trimOrNull(blockedReason),
    'waitingOn': _trimOrNull(waitingOn),
    'followUpDate': _dateOnly(followUpDate),
    'boardColumnId': null,
    'position': null,
    // Null means "leave dependency set unchanged" on UpdateTaskRequest.
    // On create there is no existing set, so it is also the right default.
    'dependencyIds': null,
    'recurrence': recurrence?.toRequestJson(),
  };

  static String? _dateOnly(DateTime? value) {
    if (value == null) return null;
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static String? _trimOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
