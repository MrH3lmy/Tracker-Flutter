import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/network/api_client.dart';
import 'package:tracker_flutter/features/auth/data/auth_api.dart';
import 'package:tracker_flutter/features/auth/data/client_platform.dart';

import '../../../helpers/fake_connectivity_service.dart';
import '../../../helpers/fake_http_client_adapter.dart';

void main() {
  ({DioAuthApi api, FakeHttpClientAdapter adapter}) build(
    ClientPlatform platform,
  ) {
    final adapter = FakeHttpClientAdapter(
      (options, call) => jsonResponseBody({
        'accessToken': 'access-1',
        'refreshToken': 'refresh-1',
        'user': {'id': 1, 'email': 'a@b.com', 'tier': 'FREE', 'role': 'USER'},
      }),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    final apiClient = ApiClient(dio, FakeConnectivityService());
    return (api: DioAuthApi(apiClient, platform), adapter: adapter);
  }

  group('register', () {
    test('posts to the native route with a platform field', () async {
      final built = build(ClientPlatform.android);

      final result = await built.api.register(
        email: 'a@b.com',
        password: 'password123',
        deviceLabel: 'pixel',
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.refreshToken, 'refresh-1');
      final sent = built.adapter.requests.single;
      expect(sent.path, '/api/v1/auth/native/register');
      final body = sent.data as Map<String, dynamic>;
      expect(body['platform'], 'ANDROID');
      expect(body['deviceLabel'], 'pixel');
    });

    test('posts to the web route with no platform field', () async {
      final built = build(ClientPlatform.web);

      await built.api.register(email: 'a@b.com', password: 'password123');

      final sent = built.adapter.requests.single;
      expect(sent.path, '/api/v1/auth/register');
      final body = sent.data as Map<String, dynamic>;
      expect(body.containsKey('platform'), isFalse);
    });
  });

  group('login', () {
    test('posts to the native route with a platform field', () async {
      final built = build(ClientPlatform.ios);

      await built.api.login(email: 'a@b.com', password: 'password123');

      final sent = built.adapter.requests.single;
      expect(sent.path, '/api/v1/auth/native/login');
      expect((sent.data as Map<String, dynamic>)['platform'], 'IOS');
    });

    test('posts to the web route', () async {
      final built = build(ClientPlatform.web);

      await built.api.login(email: 'a@b.com', password: 'password123');

      expect(built.adapter.requests.single.path, '/api/v1/auth/login');
    });
  });

  group('refresh', () {
    test('sends the refresh token in the body on native', () async {
      final built = build(ClientPlatform.windows);

      await built.api.refresh(refreshToken: 'stored-token');

      final sent = built.adapter.requests.single;
      expect(sent.path, '/api/v1/auth/native/refresh');
      expect(
        (sent.data as Map<String, dynamic>)['refreshToken'],
        'stored-token',
      );
    });

    test('sends no body on web (the cookie is the credential)', () async {
      final built = build(ClientPlatform.web);

      await built.api.refresh();

      final sent = built.adapter.requests.single;
      expect(sent.path, '/api/v1/auth/refresh');
      expect(sent.data, isNull);
    });
  });

  group('logout', () {
    test('reports a failure result instead of throwing', () async {
      final adapter = FakeHttpClientAdapter(
        (options, call) => jsonResponseBody({}, statusCode: 500),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter;
      final api = DioAuthApi(
        ApiClient(dio, FakeConnectivityService()),
        ClientPlatform.macos,
      );

      final result = await api.logout(refreshToken: 'x');

      expect(result.isFailure, isTrue);
    });
  });

  group('logoutAll', () {
    test('posts to the native logout-all route', () async {
      final built = build(ClientPlatform.linux);

      await built.api.logoutAll();

      expect(
        built.adapter.requests.single.path,
        '/api/v1/auth/native/logout-all',
      );
    });

    test('posts to the web logout-all route', () async {
      final built = build(ClientPlatform.web);

      await built.api.logoutAll();

      expect(built.adapter.requests.single.path, '/api/v1/auth/logout-all');
    });
  });
}
