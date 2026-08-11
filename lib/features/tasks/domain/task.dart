enum TaskStatus {
  backlog,
  notStarted,
  inProgress,
  waiting,
  blocked,
  done,
  cancelled,
  unknown,
}

enum TaskArea { work, study, personal, health, family }

enum TaskEffort { quick, medium, deepWork, large, unknown }

enum TaskRiskLevel { low, medium, high, critical, unknown }

enum TaskPriorityCategory { doNow, schedule, delegate, delete, unknown }

enum TaskAgeFlag { newTask, aging, stale, unknown }

enum RecurrenceFrequency { daily, weekly, monthly, annual, unknown }

class TaskRecurrence {
  const TaskRecurrence({
    required this.frequency,
    required this.rawFrequency,
    required this.interval,
    required this.daysOfWeek,
    required this.dayOfMonth,
    required this.annualDate,
    required this.nextDueDate,
    required this.lastCompletedDate,
    required this.currentStreak,
    required this.longestStreak,
  });

  factory TaskRecurrence.fromJson(Map<String, dynamic> json) {
    final rawFrequency = json['frequency'] as String?;
    return TaskRecurrence(
      frequency: _recurrenceFrequencyFromJson(rawFrequency),
      rawFrequency: rawFrequency,
      interval: (json['interval'] as num?)?.toInt() ?? 1,
      daysOfWeek: ((json['daysOfWeek'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
      dayOfMonth: (json['dayOfMonth'] as num?)?.toInt(),
      annualDate: json['annualDate'] as String?,
      nextDueDate: _dateFromJson(json['nextDueDate'] as String?),
      lastCompletedDate: _dateFromJson(json['lastCompletedDate'] as String?),
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
    );
  }

  final RecurrenceFrequency frequency;

  /// The exact backend enum value. Keeping this lets an edit round-trip a
  /// recurrence value introduced by a newer backend even when this client
  /// does not understand it yet, rather than clearing recurrence on PUT.
  final String? rawFrequency;
  final int interval;
  final List<String> daysOfWeek;
  final int? dayOfMonth;
  final String? annualDate;
  final DateTime? nextDueDate;
  final DateTime? lastCompletedDate;
  final int currentStreak;
  final int longestStreak;

  Map<String, dynamic> toRequestJson() => {
    'frequency': rawFrequency ?? recurrenceFrequencyApiValue(frequency),
    'interval': interval,
    'daysOfWeek': daysOfWeek,
    'dayOfMonth': dayOfMonth,
    'annualDate': annualDate,
  };
}

/// Mirrors Tracker-BE's `TaskResponse` used by both the paginated task list
/// and `GET /api/v1/tasks/{id}`. Unknown enum values degrade safely rather
/// than making an otherwise-valid task unreadable after a backend rollout.
class Task {
  const Task({
    required this.id,
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
    required this.projectId,
    required this.createdDate,
    required this.updatedDate,
    required this.completedDate,
    required this.important,
    required this.status,
    required this.area,
    required this.effort,
    required this.blockedReason,
    required this.waitingOn,
    required this.followUpDate,
    required this.daysLeft,
    required this.overdue,
    required this.urgent,
    required this.priorityScore,
    required this.priorityCategory,
    required this.ageFlag,
    required this.priorityReason,
    required this.boardColumnId,
    required this.position,
    required this.dependencyIds,
    required this.blockingTaskIds,
    required this.subtaskIds,
    required this.subtaskCount,
    required this.completedSubtaskCount,
    required this.subtaskProgressPercent,
    required this.recurrence,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: (json['id'] as num).toInt(),
    title: json['title'] as String,
    description: json['description'] as String?,
    dueDate: _dateFromJson(json['dueDate'] as String?),
    startDate: _dateFromJson(json['startDate'] as String?),
    estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt(),
    actualMinutes: (json['actualMinutes'] as num?)?.toInt(),
    riskLevel: _riskFromJson(json['riskLevel'] as String?),
    riskReason: json['riskReason'] as String?,
    track: json['track'] as String?,
    phase: json['phase'] as String?,
    parentTaskId: (json['parentTaskId'] as num?)?.toInt(),
    projectId: (json['projectId'] as num?)?.toInt(),
    createdDate: DateTime.parse(json['createdDate'] as String),
    updatedDate: DateTime.parse(json['updatedDate'] as String),
    completedDate: _dateTimeFromJson(json['completedDate'] as String?),
    important: json['important'] as bool? ?? false,
    status: _statusFromJson(json['status'] as String?),
    area: _areaFromJson(json['area'] as String?),
    effort: _effortFromJson(json['effort'] as String?),
    blockedReason: json['blockedReason'] as String?,
    waitingOn: json['waitingOn'] as String?,
    followUpDate: _dateFromJson(json['followUpDate'] as String?),
    daysLeft: (json['daysLeft'] as num?)?.toInt(),
    overdue: json['overdue'] as bool? ?? false,
    urgent: json['urgent'] as bool? ?? false,
    priorityScore: (json['priorityScore'] as num?)?.toInt() ?? 0,
    priorityCategory: _priorityCategoryFromJson(
      json['priorityCategory'] as String?,
    ),
    ageFlag: _ageFlagFromJson(json['ageFlag'] as String?),
    priorityReason: json['priorityReason'] as String?,
    boardColumnId: (json['boardColumnId'] as num?)?.toInt(),
    position: (json['position'] as num?)?.toInt() ?? 0,
    dependencyIds: _intList(json['dependencyIds']),
    blockingTaskIds: _intList(json['blockingTaskIds']),
    subtaskIds: _intList(json['subtaskIds']),
    subtaskCount: (json['subtaskCount'] as num?)?.toInt() ?? 0,
    completedSubtaskCount:
        (json['completedSubtaskCount'] as num?)?.toInt() ?? 0,
    subtaskProgressPercent:
        (json['subtaskProgressPercent'] as num?)?.toInt() ?? 0,
    recurrence: json['recurrence'] is Map<String, dynamic>
        ? TaskRecurrence.fromJson(json['recurrence'] as Map<String, dynamic>)
        : null,
  );

  final int id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final DateTime? startDate;
  final int? estimatedMinutes;
  final int? actualMinutes;
  final TaskRiskLevel riskLevel;
  final String? riskReason;
  final String? track;
  final String? phase;
  final int? parentTaskId;
  final int? projectId;
  final DateTime createdDate;
  final DateTime updatedDate;
  final DateTime? completedDate;
  final bool important;
  final TaskStatus status;
  final TaskArea? area;
  final TaskEffort? effort;
  final String? blockedReason;
  final String? waitingOn;
  final DateTime? followUpDate;
  final int? daysLeft;
  final bool overdue;
  final bool urgent;
  final int priorityScore;
  final TaskPriorityCategory priorityCategory;
  final TaskAgeFlag ageFlag;
  final String? priorityReason;
  final int? boardColumnId;
  final int position;
  final List<int> dependencyIds;
  final List<int> blockingTaskIds;
  final List<int> subtaskIds;
  final int subtaskCount;
  final int completedSubtaskCount;
  final int subtaskProgressPercent;
  final TaskRecurrence? recurrence;

  bool get isArchived =>
      status == TaskStatus.done || status == TaskStatus.cancelled;
}

const activeTaskStatuses = <TaskStatus>[
  TaskStatus.backlog,
  TaskStatus.notStarted,
  TaskStatus.inProgress,
  TaskStatus.waiting,
  TaskStatus.blocked,
];

String taskStatusApiValue(TaskStatus status) => switch (status) {
  TaskStatus.backlog => 'BACKLOG',
  TaskStatus.notStarted => 'NOT_STARTED',
  TaskStatus.inProgress => 'IN_PROGRESS',
  TaskStatus.waiting => 'WAITING',
  TaskStatus.blocked => 'BLOCKED',
  TaskStatus.done => 'DONE',
  TaskStatus.cancelled => 'CANCELLED',
  TaskStatus.unknown => 'UNKNOWN',
};

String taskAreaApiValue(TaskArea area) => switch (area) {
  TaskArea.work => 'WORK',
  TaskArea.study => 'STUDY',
  TaskArea.personal => 'PERSONAL',
  TaskArea.health => 'HEALTH',
  TaskArea.family => 'FAMILY',
};

String taskEffortApiValue(TaskEffort effort) => switch (effort) {
  TaskEffort.quick => 'QUICK',
  TaskEffort.medium => 'MEDIUM',
  TaskEffort.deepWork => 'DEEP_WORK',
  TaskEffort.large => 'LARGE',
  TaskEffort.unknown => 'UNKNOWN',
};

String taskRiskLevelApiValue(TaskRiskLevel riskLevel) => switch (riskLevel) {
  TaskRiskLevel.low => 'LOW',
  TaskRiskLevel.medium => 'MEDIUM',
  TaskRiskLevel.high => 'HIGH',
  TaskRiskLevel.critical => 'CRITICAL',
  TaskRiskLevel.unknown => 'UNKNOWN',
};

String recurrenceFrequencyApiValue(RecurrenceFrequency frequency) =>
    switch (frequency) {
      RecurrenceFrequency.daily => 'DAILY',
      RecurrenceFrequency.weekly => 'WEEKLY',
      RecurrenceFrequency.monthly => 'MONTHLY',
      RecurrenceFrequency.annual => 'YEARLY',
      RecurrenceFrequency.unknown => 'UNKNOWN',
    };

TaskStatus _statusFromJson(String? raw) => switch (raw) {
  'BACKLOG' => TaskStatus.backlog,
  'NOT_STARTED' => TaskStatus.notStarted,
  'IN_PROGRESS' => TaskStatus.inProgress,
  'WAITING' => TaskStatus.waiting,
  'BLOCKED' => TaskStatus.blocked,
  'DONE' => TaskStatus.done,
  'CANCELLED' => TaskStatus.cancelled,
  _ => TaskStatus.unknown,
};

TaskArea? _areaFromJson(String? raw) => switch (raw) {
  'WORK' => TaskArea.work,
  'STUDY' => TaskArea.study,
  'PERSONAL' => TaskArea.personal,
  'HEALTH' => TaskArea.health,
  'FAMILY' => TaskArea.family,
  _ => null,
};

TaskEffort _effortFromJson(String? raw) => switch (raw) {
  'QUICK' => TaskEffort.quick,
  'MEDIUM' => TaskEffort.medium,
  'DEEP_WORK' => TaskEffort.deepWork,
  'LARGE' => TaskEffort.large,
  _ => TaskEffort.unknown,
};

TaskRiskLevel _riskFromJson(String? raw) => switch (raw) {
  'LOW' => TaskRiskLevel.low,
  'MEDIUM' => TaskRiskLevel.medium,
  'HIGH' => TaskRiskLevel.high,
  'CRITICAL' => TaskRiskLevel.critical,
  _ => TaskRiskLevel.unknown,
};

TaskPriorityCategory _priorityCategoryFromJson(String? raw) => switch (raw) {
  'DO_NOW' => TaskPriorityCategory.doNow,
  'SCHEDULE' => TaskPriorityCategory.schedule,
  'DELEGATE' => TaskPriorityCategory.delegate,
  'DELETE' => TaskPriorityCategory.delete,
  _ => TaskPriorityCategory.unknown,
};

TaskAgeFlag _ageFlagFromJson(String? raw) => switch (raw) {
  'NEW' => TaskAgeFlag.newTask,
  'AGING' => TaskAgeFlag.aging,
  'STALE' => TaskAgeFlag.stale,
  _ => TaskAgeFlag.unknown,
};

RecurrenceFrequency _recurrenceFrequencyFromJson(String? raw) => switch (raw) {
  'DAILY' => RecurrenceFrequency.daily,
  'WEEKLY' => RecurrenceFrequency.weekly,
  'MONTHLY' => RecurrenceFrequency.monthly,
  'YEARLY' || 'ANNUAL' => RecurrenceFrequency.annual,
  _ => RecurrenceFrequency.unknown,
};

DateTime? _dateFromJson(String? raw) =>
    raw == null ? null : DateTime.parse(raw);
DateTime? _dateTimeFromJson(String? raw) =>
    raw == null ? null : DateTime.parse(raw);

List<int> _intList(dynamic raw) => raw is List
    ? raw.whereType<num>().map((value) => value.toInt()).toList(growable: false)
    : const <int>[];
