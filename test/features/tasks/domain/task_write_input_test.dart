import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/features/tasks/domain/task.dart';
import 'package:tracker_flutter/features/tasks/domain/task_write_input.dart';

void main() {
  test('create defaults mirror Tracker-BE task defaults', () {
    final input = TaskWriteInput.defaults();

    expect(input.status, TaskStatus.backlog);
    expect(input.area, TaskArea.personal);
    expect(input.effort, TaskEffort.medium);
    expect(input.riskLevel, TaskRiskLevel.low);
    expect(input.important, isFalse);
  });

  test('request JSON trims strings and serializes date-only values', () {
    final input = TaskWriteInput(
      title: '  Write Flutter form  ',
      description: '  body  ',
      dueDate: DateTime(2026, 8, 20, 15, 30),
      startDate: DateTime(2026, 8, 11, 9),
      estimatedMinutes: 45,
      actualMinutes: null,
      riskLevel: TaskRiskLevel.high,
      riskReason: '  risky  ',
      track: '  Flutter  ',
      phase: '  Slice 4  ',
      parentTaskId: null,
      important: true,
      status: TaskStatus.inProgress,
      area: TaskArea.work,
      effort: TaskEffort.deepWork,
      blockedReason: null,
      waitingOn: null,
      followUpDate: DateTime(2026, 8, 21),
      recurrence: null,
    );

    final json = input.toRequestJson();
    expect(json['title'], 'Write Flutter form');
    expect(json['description'], 'body');
    expect(json['dueDate'], '2026-08-20');
    expect(json['startDate'], '2026-08-11');
    expect(json['followUpDate'], '2026-08-21');
    expect(json['riskLevel'], 'HIGH');
    expect(json['status'], 'IN_PROGRESS');
    expect(json['area'], 'WORK');
    expect(json['effort'], 'DEEP_WORK');
    expect(json['dependencyIds'], isNull);
  });

  test('editing preserves hidden full-PUT fields and recurrence', () {
    final task = Task.fromJson({
      'id': 9,
      'title': 'Recurring task',
      'description': null,
      'estimatedMinutes': 30,
      'actualMinutes': 25,
      'riskLevel': 'LOW',
      'parentTaskId': 3,
      'projectId': 7,
      'createdDate': '2026-01-01T00:00:00',
      'updatedDate': '2026-08-11T00:00:00',
      'important': false,
      'status': 'NOT_STARTED',
      'area': 'PERSONAL',
      'effort': 'MEDIUM',
      'overdue': false,
      'urgent': false,
      'priorityScore': 0,
      'boardColumnId': 2,
      'position': 1000,
      'dependencyIds': [4, 5],
      'recurrence': {
        'frequency': 'YEARLY',
        'interval': 2,
        'daysOfWeek': <String>[],
        'dayOfMonth': null,
        'annualDate': '--06-15',
        'nextDueDate': '2028-06-15',
        'lastCompletedDate': '2026-06-15',
        'currentStreak': 3,
        'longestStreak': 5,
      },
    });

    final json = TaskWriteInput.fromTask(task).toRequestJson();
    expect(json['actualMinutes'], 25);
    expect(json['parentTaskId'], 3);
    expect(json['boardColumnId'], 2);
    expect(json['dependencyIds'], isNull);
    expect(json['recurrence'], {
      'frequency': 'YEARLY',
      'interval': 2,
      'daysOfWeek': <String>[],
      'dayOfMonth': null,
      'annualDate': '--06-15',
    });
  });
}
