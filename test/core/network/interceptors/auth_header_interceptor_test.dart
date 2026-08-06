import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:tracker_flutter/core/network/auth/auth_session.dart';
import 'package:tracker_flutter/core/network/interceptors/auth_header_interceptor.dart';
import 'package:tracker_flutter/core/network/request_policy.dart';

import '../../../helpers/fake_auth_session.dart';
import '../../../helpers/fake_http_client_adapter.dart';

final _interceptorProvider = Provider<AuthHeaderInterceptor>(
  (ref) => AuthHeaderInterceptor(ref),
);

void main() {
  late ProviderContainer container;
  late FakeHttpClientAdapter adapter;

  Dio buildDio({
    required List<Override> overrides,
    required ResponseBody Function(RequestOptions options, int call) respond,
  }) {
    container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    adapter = FakeHttpClientAdapter(respond);
    return Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(container.read(_interceptorProvider));
  }

  test('injects the bearer token from AuthSession', () async {
    final dio = buildDio(
      overrides: [
        authSessionProvider.overrideWithValue(FakeAuthSession(token: 'abc123')),
      ],
      respond: (options, _) {
        expect(options.headers['Authorization'], 'Bearer abc123');
        return jsonResponseBody({'ok': true});
      },
    );

    await dio.get<dynamic>('/ping');
    expect(adapter.callCount, 1);
  });

  test('omits the header when there is no token', () async {
    final dio = buildDio(
      overrides: [authSessionProvider.overrideWithValue(FakeAuthSession())],
      respond: (options, _) {
        expect(options.headers.containsKey('Authorization'), isFalse);
        return jsonResponseBody({'ok': true});
      },
    );

    await dio.get<dynamic>('/ping');
  });

  test(
    'omits the header when skipAuth is set, even with a token present',
    () async {
      final dio = buildDio(
        overrides: [
          authSessionProvider.overrideWithValue(
            FakeAuthSession(token: 'abc123'),
          ),
        ],
        respond: (options, _) {
          expect(options.headers.containsKey('Authorization'), isFalse);
          return jsonResponseBody({'ok': true});
        },
      );

      await dio.get<dynamic>(
        '/ping',
        options: const RequestPolicy(skipAuth: true).toOptions(),
      );
    },
  );
}
