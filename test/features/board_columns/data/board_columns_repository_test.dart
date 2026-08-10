import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/error/app_failure.dart';
import 'package:tracker_flutter/core/network/api_client.dart';
import 'package:tracker_flutter/features/board_columns/data/board_columns_repository.dart';

import '../../../helpers/fake_connectivity_service.dart';
import '../../../helpers/fake_http_client_adapter.dart';

void main() {
  ({ApiBoardColumnsRepository repository, FakeHttpClientAdapter adapter}) build(
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
    return (repository: ApiBoardColumnsRepository(apiClient), adapter: adapter);
  }

  Map<String, dynamic> column(
    int id,
    String name,
    String status,
    int position,
  ) => {'id': id, 'name': name, 'status': status, 'position': position};

  test(
    'successful load requests GET /api/v1/board-columns and decodes it',
    () async {
      final built = build(
        (options, call) =>
            jsonResponseBody([column(1, 'Backlog', 'BACKLOG', 1000)]),
      );

      final result = await built.repository.fetchColumns();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, hasLength(1));
      expect(result.valueOrNull!.single.name, 'Backlog');
      expect(built.adapter.requests.single.path, '/api/v1/board-columns');
      expect(built.adapter.requests.single.method, 'GET');
    },
  );

  test('an empty backend array decodes to an empty list', () async {
    final built = build((options, call) => jsonResponseBody(<dynamic>[]));

    final result = await built.repository.fetchColumns();

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, isEmpty);
  });

  test(
    'columns already ordered by position are returned in that order',
    () async {
      final built = build(
        (options, call) => jsonResponseBody([
          column(1, 'Backlog', 'BACKLOG', 1000),
          column(2, 'In Progress', 'IN_PROGRESS', 3000),
          column(3, 'Done', 'DONE', 6000),
        ]),
      );

      final result = await built.repository.fetchColumns();

      expect(result.valueOrNull!.map((c) => c.name).toList(), [
        'Backlog',
        'In Progress',
        'Done',
      ]);
    },
  );

  test(
    'defensively re-sorts by position even if the wire order is wrong',
    () async {
      final built = build(
        (options, call) => jsonResponseBody([
          column(2, 'In Progress', 'IN_PROGRESS', 3000),
          column(3, 'Done', 'DONE', 6000),
          column(1, 'Backlog', 'BACKLOG', 1000),
        ]),
      );

      final result = await built.repository.fetchColumns();

      expect(result.valueOrNull!.map((c) => c.position).toList(), [
        1000,
        3000,
        6000,
      ]);
    },
  );

  test('a 401 maps to UnauthorizedFailure', () async {
    final built = build(
      (options, call) => jsonResponseBody({
        'timestamp': '2026-01-01T00:00:00Z',
        'status': 401,
        'error': 'Unauthorized',
        'message': 'Authentication is required.',
        'path': '/api/v1/board-columns',
      }, statusCode: 401),
    );

    final result = await built.repository.fetchColumns();

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
        'path': '/api/v1/board-columns',
      }, statusCode: 500),
    );

    final result = await built.repository.fetchColumns();

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

    final result = await built.repository.fetchColumns();

    expect(result.failureOrNull, isA<OfflineFailure>());
  });

  test(
    'a non-array response body maps to UnknownFailure instead of throwing',
    () async {
      final built = build(
        (options, call) => jsonResponseBody({'not': 'a list'}),
      );

      final result = await built.repository.fetchColumns();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<UnknownFailure>());
    },
  );

  test(
    'a malformed item (missing required field) maps to UnknownFailure instead of throwing',
    () async {
      final malformed = {...column(1, 'Backlog', 'BACKLOG', 1000)}
        ..remove('name');
      final built = build((options, call) => jsonResponseBody([malformed]));

      final result = await built.repository.fetchColumns();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<UnknownFailure>());
    },
  );
}
