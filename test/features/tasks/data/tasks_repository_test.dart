import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/error/app_failure.dart';
import 'package:tracker_flutter/core/network/api_client.dart';
import 'package:tracker_flutter/features/tasks/data/tasks_repository.dart';

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

  final taskJson = {
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
    'projectId': 9,
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

  test(
    'fetchTasks uses bounded pagination, project filter, and active statuses',
    () async {
      final built = build(
        (options, call) => jsonResponseBody(
          [taskJson],
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
    final built = build((options, call) => jsonResponseBody(taskJson));

    final result = await built.repository.fetchTask(1);

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull!.id, 1);
    expect(built.adapter.requests.single.path, '/api/v1/tasks/1');
  });

  test('malformed paginated body maps to UnknownFailure', () async {
    final built = build((options, call) => jsonResponseBody({'bad': true}));

    final result = await built.repository.fetchTasks(page: 0, size: 50);

    expect(result.failureOrNull, isA<UnknownFailure>());
  });
}
