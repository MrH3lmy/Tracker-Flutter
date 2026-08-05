import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/error/app_failure.dart';
import 'package:tracker_flutter/core/network/api_client.dart';
import 'package:tracker_flutter/core/result/result.dart';

import '../../helpers/fake_connectivity_service.dart';
import '../../helpers/fake_http_client_adapter.dart';

void main() {
  ApiClient buildClient(
    FakeHttpClientAdapter adapter, {
    bool hasNetwork = true,
  }) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    return ApiClient(dio, FakeConnectivityService(hasNetwork: hasNetwork));
  }

  test('a successful GET decodes the response body', () async {
    final adapter = FakeHttpClientAdapter(
      (options, call) => jsonResponseBody({'id': '1', 'title': 'Write tests'}),
    );
    final client = buildClient(adapter);

    final result = await client.get<String>(
      '/tasks/1',
      decode: (data) => (data as Map<String, dynamic>)['title'] as String,
    );

    expect(result, isA<Success<String>>());
    expect(result.valueOrNull, 'Write tests');
  });

  test('a validation error maps to a ValidationFailure result', () async {
    final adapter = FakeHttpClientAdapter(
      (options, call) => jsonResponseBody({
        'errors': {'title': 'must not be blank'},
      }, statusCode: 422),
    );
    final client = buildClient(adapter);

    final result = await client.post<dynamic>(
      '/tasks',
      decode: (data) => data,
      data: {'title': ''},
    );

    expect(result.isFailure, isTrue);
    final failure = result.failureOrNull;
    expect(failure, isA<ValidationFailure>());
    expect(
      (failure as ValidationFailure).fieldErrors['title'],
      'must not be blank',
    );
  });

  test('getPaginated parses items and page headers together', () async {
    final adapter = FakeHttpClientAdapter(
      (options, call) => jsonResponseBody(
        [
          {'id': '1'},
          {'id': '2'},
        ],
        headers: {
          'x-total-count': ['2'],
          'x-page': ['0'],
          'x-page-size': ['20'],
          'x-has-next': ['false'],
        },
      ),
    );
    final client = buildClient(adapter);

    final result = await client.getPaginated<String>(
      '/tasks',
      decodeItem: (item) => (item as Map<String, dynamic>)['id'] as String,
    );

    expect(result.isSuccess, isTrue);
    final page = result.valueOrNull!;
    expect(page.items, ['1', '2']);
    expect(page.meta.totalCount, 2);
    expect(page.meta.hasNext, isFalse);
  });

  test('a connection error with no network reports OfflineFailure', () async {
    final adapter = FakeHttpClientAdapter((options, call) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });
    final client = buildClient(adapter, hasNetwork: false);

    final result = await client.get<dynamic>('/tasks', decode: (data) => data);

    expect(result.failureOrNull, isA<OfflineFailure>());
  });

  test(
    'a connection error with network present reports NetworkFailure',
    () async {
      final adapter = FakeHttpClientAdapter((options, call) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });
      final client = buildClient(adapter, hasNetwork: true);

      final result = await client.get<dynamic>(
        '/tasks',
        decode: (data) => data,
      );

      expect(result.failureOrNull, isA<NetworkFailure>());
    },
  );

  test('a cancelled request reports CancelledFailure', () async {
    final adapter = FakeHttpClientAdapter((options, call) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
      );
    });
    final client = buildClient(adapter);

    final result = await client.get<dynamic>('/tasks', decode: (data) => data);

    expect(result.failureOrNull, isA<CancelledFailure>());
  });

  test(
    'an unmapped exception is reported as UnknownFailure, not thrown',
    () async {
      final adapter = FakeHttpClientAdapter((options, call) {
        throw StateError('adapter blew up');
      });
      final client = buildClient(adapter);

      final result = await client.get<dynamic>(
        '/tasks',
        decode: (data) => data,
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<UnknownFailure>());
    },
  );
}
