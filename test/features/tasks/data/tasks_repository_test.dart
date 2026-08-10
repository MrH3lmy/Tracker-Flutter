import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/error/app_failure.dart';
import 'package:tracker_flutter/core/network/api_client.dart';
import 'package:tracker_flutter/features/tasks/data/tasks_repository.dart';
import 'package:tracker_flutter/features/tasks/domain/task.dart';
import 'package:tracker_flutter/features/tasks/domain/task_write_input.dart';

import '../../../helpers/fake_connectivity_service.dart';
import '../../../helpers/fake_http_client_adapter.dart';

void main() {
  ({ApiTasksRepository repository, FakeHttpClientAdapter adapter}) build(
    ResponseBody Function(RequestOptions options, int callNumber) handler,
  ) {
    final adapter = FakeHttpClientAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    final client = ApiClient(dio, FakeConnectivityService(hasNetwork: true));
    return (repository: ApiTasksRepository(client), adapter: adapter);
  }

  Map<String, dynamic> taskJson({int? projectId = 9}) => {
    'id': 1,
    'title': 'First task',
    'description': null,
    'dueDate': null,
    'startDate': null,
    'estimatedMinutes': null,
    'actualMinutes': null,
    'riskLevel': 'LOW',
    'riskReason': null,
    'track': null,
    'phase': null,
    'parentTaskId': null,
    'projectId': projectId,
    'createdDate': '2026-08-11T01:00:00',
    'updatedDate': '2026-08-11T01:00:00',
    'completedDate': null,
    'important': false,
    'status': 'NOT_STARTED',
    'area': 'WORK',
    'effort': 'QUICK',
    'blockedReason': null,
    'waitingOn': null,
    'followUpDate': null,
    'daysLeft': null,
    'overdue': false,
    'urgent': false,
    'priorityScore': 10,
    'priorityCategory': 'SCHEDULE',
    'ageFlag': 'NEW',
    'priorityReason': null,
    'boardColumnId': 2,
    'position': 100,
    'dependencyIds': <int>[],
    'blockingTaskIds': <int>[],
    'subtaskIds': <int>[],
    'subtaskCount': 0,
    'completedSubtaskCount': 0,
    'subtaskProgressPercent': 0,
    'recurrence': null,
  };

  TaskWriteInput writeInput() => const TaskWriteInput(
    title: 'First task',
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
    status: TaskStatus.notStarted,
    area: TaskArea.work,
    effort: TaskEffort.quick,
    blockedReason: null,
    waitingOn: null,
    followUpDate: null,
    recurrence: null,
  );

  test(
    'fetchTasks uses bounded pagination, project filter, and active statuses',
    () async {
      final built = build(
        (options, call) => jsonResponseBody(
          [taskJson()],
          headers: {
            'x-total-count': ['51'],
            'x-total-pages': ['2'],
            'x-page': ['0'],
            'x-page-size': ['50'],
            'x-has-next': ['true'],
          },
        ),
      );

      final result = await built.repository.fetchTasks(
        page: 0,
        size: 50,
        projectId: 9,
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.items.single.title, 'First task');
      expect(result.valueOrNull!.meta.totalCount, 51);
      expect(result.valueOrNull!.meta.hasNext, isTrue);

      final request = built.adapter.requests.single;
      expect(request.path, '/api/v1/tasks');
      expect(request.queryParameters['page'], 0);
      expect(request.queryParameters['size'], 50);
      expect(request.queryParameters['projectId'], 9);
      expect(request.queryParameters['status'], contains('IN_PROGRESS'));
      expect(request.queryParameters['status'], isNot(contains('DONE')));
    },
  );

  test('fetchTask loads a single task by id', () async {
    final built = build((options, call) => jsonResponseBody(taskJson()));

    final result = await built.repository.fetchTask(1);

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull!.id, 1);
    expect(built.adapter.requests.single.path, '/api/v1/tasks/1');
  });

  test('create assigns selected project only after POST succeeds', () async {
    final built = build((options, call) {
      if (call == 1) {
        return jsonResponseBody(taskJson(projectId: null), statusCode: 201);
      }
      return jsonResponseBody(taskJson(projectId: 9));
    });

    final result = await built.repository.createTask(writeInput(), projectId: 9);

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull!.task.projectId, 9);
    expect(result.valueOrNull!.projectAssignmentFailure, isNull);
    expect(built.adapter.requests, hasLength(2));
    expect(built.adapter.requests[0].method, 'POST');
    expect(built.adapter.requests[0].path, '/api/v1/tasks');
    expect(built.adapter.requests[1].method, 'PATCH');
    expect(built.adapter.requests[1].path, '/api/v1/tasks/1/project');
    expect(built.adapter.requests[1].data, {'projectId': 9});
  });

  test('project assignment failure does not turn a created task into failure', () async {
    final built = build((options, call) {
      if (call == 1) {
        return jsonResponseBody(taskJson(projectId: null), statusCode: 201);
      }
      return jsonResponseBody(
        {'message': 'project unavailable'},
        statusCode: 500,
      );
    });

    final result = await built.repository.createTask(writeInput(), projectId: 9);

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull!.task.id, 1);
    expect(result.valueOrNull!.task.projectId, isNull);
    expect(result.valueOrNull!.projectAssignmentFailure, isA<ServerFailure>());
    expect(built.adapter.callCount, 2);
  });

  test('update sends one full PUT payload', () async {
    final built = build((options, call) => jsonResponseBody(taskJson()));

    final result = await built.repository.updateTask(1, writeInput());

    expect(result.isSuccess, isTrue);
    final request = built.adapter.requests.single;
    expect(request.method, 'PUT');
    expect(request.path, '/api/v1/tasks/1');
    expect((request.data as Map)['title'], 'First task');
    expect((request.data as Map)['dependencyIds'], isNull);
  });

  test('malformed paginated body maps to UnknownFailure', () async {
    final built = build((options, call) => jsonResponseBody({'bad': true}));

    final result = await built.repository.fetchTasks(page: 0, size: 50);

    expect(result.failureOrNull, isA<UnknownFailure>());
  });
}
