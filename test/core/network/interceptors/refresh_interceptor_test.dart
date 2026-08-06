import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/network/auth/auth_session.dart';
import 'package:tracker_flutter/core/network/interceptors/refresh_interceptor.dart';
import 'package:tracker_flutter/core/network/request_policy.dart';

import '../../../helpers/fake_auth_session.dart';
import '../../../helpers/fake_http_client_adapter.dart';

ResponseBody _unauthorized() =>
    jsonResponseBody({'message': 'Unauthorized'}, statusCode: 401);

void main() {
  Dio buildDio(FakeAuthSession session, FakeHttpClientAdapter adapter) {
    late Dio dio;
    final container = ProviderContainer(
      overrides: [authSessionProvider.overrideWithValue(session)],
    );
    addTearDown(container.dispose);
    final interceptorProvider = Provider<RefreshInterceptor>(
      (ref) => RefreshInterceptor(dio, ref),
    );
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(container.read(interceptorProvider));
    return dio;
  }

  test('retries once after a successful refresh', () async {
    final session = FakeAuthSession(refreshResult: 'new-token');
    final adapter = FakeHttpClientAdapter((options, call) {
      if (options.headers['Authorization'] == 'Bearer new-token') {
        return jsonResponseBody({'ok': true});
      }
      return _unauthorized();
    });
    final dio = buildDio(session, adapter);

    final response = await dio.get<dynamic>('/secure');

    expect(response.data, {'ok': true});
    expect(session.refreshCalls, 1);
    expect(adapter.callCount, 2);
  });

  test('coalesces concurrent 401s into a single refresh call', () async {
    final session = FakeAuthSession(
      refreshResult: 'new-token',
      refreshDelay: const Duration(milliseconds: 20),
    );
    final adapter = FakeHttpClientAdapter((options, call) {
      if (options.headers['Authorization'] == 'Bearer new-token') {
        return jsonResponseBody({'ok': true});
      }
      return _unauthorized();
    });
    final dio = buildDio(session, adapter);

    final responses = await Future.wait([
      dio.get<dynamic>('/secure/a'),
      dio.get<dynamic>('/secure/b'),
      dio.get<dynamic>('/secure/c'),
    ]);

    expect(responses.every((response) => response.data['ok'] == true), isTrue);
    expect(session.refreshCalls, 1);
    expect(adapter.callCount, 6);
  });

  test('forces sign-out when refresh cannot recover the session', () async {
    final session = FakeAuthSession(refreshResult: null);
    final adapter = FakeHttpClientAdapter((options, call) => _unauthorized());
    final dio = buildDio(session, adapter);

    await expectLater(
      () => dio.get<dynamic>('/secure'),
      throwsA(
        isA<DioException>().having(
          (exception) => exception.response?.statusCode,
          'statusCode',
          401,
        ),
      ),
    );

    expect(session.refreshCalls, 1);
    expect(session.signOutCalls, 1);
    expect(adapter.callCount, 1);
  });

  test('does not intercept public request 401 responses', () async {
    final session = FakeAuthSession(refreshResult: 'new-token');
    final adapter = FakeHttpClientAdapter((options, call) => _unauthorized());
    final dio = buildDio(session, adapter);

    await expectLater(
      () => dio.post<dynamic>(
        '/login',
        options: const RequestPolicy(skipAuth: true).toOptions(),
      ),
      throwsA(isA<DioException>()),
    );

    expect(session.refreshCalls, 0);
    expect(session.signOutCalls, 0);
    expect(adapter.callCount, 1);
  });

  test('refreshes but does not replay an unsafe write', () async {
    final session = FakeAuthSession(refreshResult: 'new-token');
    final adapter = FakeHttpClientAdapter((options, call) {
      if (call > 1) return jsonResponseBody({'created': true});
      return _unauthorized();
    });
    final dio = buildDio(session, adapter);

    await expectLater(
      () => dio.post<dynamic>('/tasks', data: {'title': 'Write tests'}),
      throwsA(isA<DioException>()),
    );

    expect(session.refreshCalls, 1);
    expect(session.accessToken, 'new-token');
    expect(adapter.callCount, 1);
  });

  test('signs out when the retried request is still unauthorized', () async {
    final session = FakeAuthSession(refreshResult: 'new-token');
    final adapter = FakeHttpClientAdapter((options, call) => _unauthorized());
    final dio = buildDio(session, adapter);

    await expectLater(
      () => dio.get<dynamic>('/secure'),
      throwsA(isA<DioException>()),
    );

    expect(session.refreshCalls, 1);
    expect(session.signOutCalls, 1);
    expect(adapter.callCount, 2);
  });
}
