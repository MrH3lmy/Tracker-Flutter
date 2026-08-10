import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/features/tasks/domain/task.dart';

void main() {
  Map<String, dynamic> sample({String status = 'IN_PROGRESS'}) => {
    'id': 7,
    'title': 'Ship Flutter task slice',
    'description': 'Wire the paginated list.',
    'dueDate': '2026-08-15',
    'startDate': null,
    'estimatedMinutes': 90,
    'actualMinutes': null,
    'riskLevel': 'MEDIUM',
    'riskReason': null,
    'track': 'Flutter',
    'phase': 'Slice 3',
    'parentTaskId': null,
    'projectId': 12,
    'createdDate': '2026-08-11T01:00:00',
    'updatedDate': '2026-08-11T01:30:00',
    'completedDate': null,
    'important': true,
    'status': status,
    'area': 'WORK',
    'effort': 'DEEP_WORK',
    'blockedReason': null,
    'waitingOn': null,
    'followUpDate': null,
    'daysLeft': 4,
    'overdue': false,
    'urgent': true,
    'priorityScore': 87,
    'priorityCategory': 'DO_NOW',
    'ageFlag': 'NEW',
    'priorityReason': 'Important and near due date',
    'boardColumnId': 3,
    'position': 20,
    'dependencyIds': [1, 2],
    'blockingTaskIds': [9],
    'subtaskIds': [10, 11],
    'subtaskCount': 2,
    'completedSubtaskCount': 1,
    'subtaskProgressPercent': 50,
    'recurrence': null,
  };

  test('decodes the backend TaskResponse fields used by slice 3', () {
    final task = Task.fromJson(sample());

    expect(task.id, 7);
    expect(task.title, 'Ship Flutter task slice');
    expect(task.status, TaskStatus.inProgress);
    expect(task.projectId, 12);
    expect(task.boardColumnId, 3);
    expect(task.effort, TaskEffort.deepWork);
    expect(task.riskLevel, TaskRiskLevel.medium);
    expect(task.dependencyIds, [1, 2]);
    expect(task.subtaskProgressPercent, 50);
  });

  test('unknown enum values degrade safely', () {
    final task = Task.fromJson({
      ...sample(status: 'FUTURE_STATUS'),
      'riskLevel': 'EXTREME',
      'effort': 'MASSIVE',
      'priorityCategory': 'SOMEDAY',
      'ageFlag': 'ANCIENT',
    });

    expect(task.status, TaskStatus.unknown);
    expect(task.riskLevel, TaskRiskLevel.unknown);
    expect(task.effort, TaskEffort.unknown);
    expect(task.priorityCategory, TaskPriorityCategory.unknown);
    expect(task.ageFlag, TaskAgeFlag.unknown);
  });

  test('YEARLY recurrence decodes and round-trips without being cleared', () {
    final task = Task.fromJson({
      ...sample(),
      'recurrence': {
        'frequency': 'YEARLY',
        'interval': 1,
        'daysOfWeek': <String>[],
        'dayOfMonth': null,
        'annualDate': '--12-31',
        'nextDueDate': '2026-12-31',
        'lastCompletedDate': '2025-12-31',
        'currentStreak': 2,
        'longestStreak': 4,
      },
    });

    expect(task.recurrence!.frequency, RecurrenceFrequency.annual);
    expect(task.recurrence!.rawFrequency, 'YEARLY');
    expect(task.recurrence!.toRequestJson()['frequency'], 'YEARLY');
    expect(task.recurrence!.toRequestJson()['annualDate'], '--12-31');
  });

  test('archived is true only for done and cancelled', () {
    expect(Task.fromJson(sample(status: 'DONE')).isArchived, isTrue);
    expect(Task.fromJson(sample(status: 'CANCELLED')).isArchived, isTrue);
    expect(Task.fromJson(sample(status: 'IN_PROGRESS')).isArchived, isFalse);
  });
}
