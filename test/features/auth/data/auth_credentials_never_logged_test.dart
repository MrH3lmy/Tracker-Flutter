import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart' as pkg;
import 'package:tracker_flutter/core/logging/app_logger.dart';
import 'package:tracker_flutter/core/network/api_client.dart';
import 'package:tracker_flutter/core/network/interceptors/redacting_log_interceptor.dart';
import 'package:tracker_flutter/features/auth/data/auth_api.dart';
import 'package:tracker_flutter/features/auth/data/client_platform.dart';

import '../../../helpers/fake_connectivity_service.dart';
import '../../../helpers/fake_http_client_adapter.dart';

/// Explicit end-to-end coverage (epic #3) that a password or refresh token
/// passed through the real request/response logging pipeline never appears
/// in a log line — not just that `AuthApi` happens not to call a logger
/// itself.
void main() {
  test('login/register/refresh bodies are never logged in the clear', () async {
    final records = <pkg.LogRecord>[];
    final subscription = pkg.Logger.root.onRecord.listen(records.add);
    addTearDown(subscription.cancel);
    pkg.Logger.root.level = pkg.Level.ALL;

    final adapter = FakeHttpClientAdapter(
      (options, call) => jsonResponseBody({
        'accessToken': 'super-secret-access-token',
        'refreshToken': 'super-secret-refresh-token',
        'user': {'id': 1, 'email': 'a@b.com', 'tier': 'FREE', 'role': 'USER'},
      }),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        RedactingLogInterceptor(AppLogger('test-auth'), logBodies: true),
      );
    final api = DioAuthApi(
      ApiClient(dio, FakeConnectivityService()),
      ClientPlatform.android,
    );

    await api.register(
      email: 'a@b.com',
      password: 'super-secret-password',
      deviceLabel: 'test-device',
    );
    await api.login(email: 'a@b.com', password: 'super-secret-password');
    await api.refresh(refreshToken: 'super-secret-refresh-token');

    final logged = records.map((r) => r.message).join('\n');
    expect(logged, isNot(contains('super-secret-password')));
    expect(logged, isNot(contains('super-secret-refresh-token')));
    expect(logged, isNot(contains('super-secret-access-token')));
  });
}
