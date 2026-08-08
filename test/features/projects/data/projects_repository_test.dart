import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/error/app_failure.dart';
import 'package:tracker_flutter/core/network/api_client.dart';
import 'package:tracker_flutter/features/projects/data/projects_repository.dart';

import '../../../helpers/fake_connectivity_service.dart';
import '../../../helpers/fake_http_client_adapter.dart';

void main() {
  ({ApiProjectsRepository repository, FakeHttpClientAdapter adapter}) build(
    ResponseBody Function(RequestOptions options, int callNumber) handler, {
    bool hasNetwork = true,
  }) {
    final adapter = FakeHttpClientAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    final apiClient = ApiClient(
      dio,
      FakeConnectivityService(hasNetwork: hasNetwork),
    );
    return (repository: ApiProjectsRepository(apiClient), adapter: adapter);
  }

  final sampleProject = {
    'id': 1,
    'name': 'Website relaunch',
    'description': null,
    'status': 'ACTIVE',
    'startDate': null,
    'targetDate': null,
    'area': null,
    'goal': null,
    'ownerUserId': 7,
    'createdDate': '2026-01-01T10:15:30',
  };

  test(
    'successful load requests GET /api/v1/projects and decodes it',
    () async {
      final built = build((options, call) => jsonResponseBody([sampleProject]));

      final result = await built.repository.fetchProjects();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, hasLength(1));
      expect(result.valueOrNull!.single.name, 'Website relaunch');
      expect(built.adapter.requests.single.path, '/api/v1/projects');
      expect(built.adapter.requests.single.method, 'GET');
    },
  );

  test('an empty backend array decodes to an empty list', () async {
    final built = build((options, call) => jsonResponseBody(<dynamic>[]));

    final result = await built.repository.fetchProjects();

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, isEmpty);
  });

  test('a 401 maps to UnauthorizedFailure', () async {
    final built = build(
      (options, call) => jsonResponseBody({
        'timestamp': '2026-01-01T00:00:00Z',
        'status': 401,
        'error': 'Unauthorized',
        'message': 'Authentication is required.',
        'path': '/api/v1/projects',
      }, statusCode: 401),
    );

    final result = await built.repository.fetchProjects();

    expect(result.isFailure, isTrue);
    expect(result.failureOrNull, isA<UnauthorizedFailure>());
  });

  test('a 500 maps to ServerFailure', () async {
    final built = build(
      (options, call) => jsonResponseBody({
        'timestamp': '2026-01-01T00:00:00Z',
        'status': 500,
        'error': 'Internal Server Error',
        'message': 'An unexpected error occurred.',
        'path': '/api/v1/projects',
      }, statusCode: 500),
    );

    final result = await built.repository.fetchProjects();

    expect(result.isFailure, isTrue);
    expect(result.failureOrNull, isA<ServerFailure>());
  });

  test('a connection error with no network reports OfflineFailure', () async {
    final built = build(
      (options, call) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
      hasNetwork: false,
    );

    final result = await built.repository.fetchProjects();

    expect(result.failureOrNull, isA<OfflineFailure>());
  });

  test(
    'a non-array response body maps to UnknownFailure instead of throwing',
    () async {
      final built = build(
        (options, call) => jsonResponseBody({'not': 'a list'}),
      );

      final result = await built.repository.fetchProjects();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<UnknownFailure>());
    },
  );

  test(
    'a malformed item (missing required field) maps to UnknownFailure instead of throwing',
    () async {
      final malformed = {...sampleProject}..remove('name');
      final built = build((options, call) => jsonResponseBody([malformed]));

      final result = await built.repository.fetchProjects();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<UnknownFailure>());
    },
  );
}
