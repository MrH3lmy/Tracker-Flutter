import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/network/interceptors/retry_interceptor.dart';
import 'package:tracker_flutter/core/network/request_policy.dart';

import '../../../helpers/fake_http_client_adapter.dart';

void main() {
  test('retries an idempotent GET once on a transient 503', () async {
    final delays = <Duration>[];
    final adapter = FakeHttpClientAdapter((options, call) {
      if (call == 1) {
        return jsonResponseBody({'message': 'unavailable'}, statusCode: 503);
      }
      return jsonResponseBody({'ok': true});
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      RetryInterceptor(dio, delay: (d) async => delays.add(d)),
    );

    final response = await dio.get<dynamic>('/tasks');

    expect(response.data, {'ok': true});
    expect(adapter.callCount, 2);
    expect(delays.length, 1);
  });

  test('does not retry a non-idempotent POST on a 503', () async {
    final adapter = FakeHttpClientAdapter(
      (options, call) =>
          jsonResponseBody({'message': 'unavailable'}, statusCode: 503),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(RetryInterceptor(dio, delay: (_) async {}));

    await expectLater(
      () => dio.post<dynamic>('/tasks', data: {'title': 'x'}),
      throwsA(isA<DioException>()),
    );

    expect(
      adapter.callCount,
      1,
      reason: 'a non-idempotent request must not auto-retry',
    );
  });

  test(
    'a request explicitly marked retryable is retried even if not idempotent',
    () async {
      final adapter = FakeHttpClientAdapter((options, call) {
        if (call == 1) return jsonResponseBody({}, statusCode: 503);
        return jsonResponseBody({'ok': true});
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter;
      dio.interceptors.add(RetryInterceptor(dio, delay: (_) async {}));

      final response = await dio.post<dynamic>(
        '/tasks',
        data: {'title': 'x'},
        options: const RequestPolicy(retryable: true).toOptions(),
      );

      expect(response.data, {'ok': true});
      expect(adapter.callCount, 2);
    },
  );

  test('respects Retry-After on a 429', () async {
    final delays = <Duration>[];
    final adapter = FakeHttpClientAdapter((options, call) {
      if (call == 1) {
        return jsonResponseBody(
          {},
          statusCode: 429,
          headers: {
            'retry-after': ['2'],
          },
        );
      }
      return jsonResponseBody({'ok': true});
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      RetryInterceptor(dio, delay: (d) async => delays.add(d)),
    );

    final response = await dio.get<dynamic>('/tasks');

    expect(response.data, {'ok': true});
    expect(delays.single, const Duration(seconds: 2));
  });

  test('gives up after maxAttempts transient failures', () async {
    final adapter = FakeHttpClientAdapter(
      (options, call) => jsonResponseBody({}, statusCode: 503),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      RetryInterceptor(dio, maxAttempts: 2, delay: (_) async {}),
    );

    await expectLater(
      () => dio.get<dynamic>('/tasks'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.callCount, 3); // initial attempt + 2 retries
  });

  test('does not retry a non-retryable client error like 404', () async {
    final adapter = FakeHttpClientAdapter(
      (options, call) => jsonResponseBody({}, statusCode: 404),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(RetryInterceptor(dio, delay: (_) async {}));

    await expectLater(
      () => dio.get<dynamic>('/tasks/1'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.callCount, 1);
  });
}
