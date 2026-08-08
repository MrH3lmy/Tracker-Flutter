import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/connectivity/connectivity_service.dart';
import '../network/interceptors/auth_header_interceptor.dart';
import '../network/interceptors/redacting_log_interceptor.dart';
import '../network/interceptors/refresh_interceptor.dart';
import '../network/interceptors/retry_interceptor.dart';
import 'app_providers.dart';

const _apiVersionHeader = 'X-Api-Version';

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {'Accept': 'application/json', _apiVersionHeader: '1'},
      contentType: Headers.jsonContentType,
      // The browser auth contract (core/network/../features/auth) relies on
      // an HttpOnly refresh-token cookie; without this, dio_web_adapter's
      // XHR omits credentials on Flutter Web and the cookie is never sent
      // or accepted, regardless of same-origin/CORS configuration. Ignored
      // entirely by the IO adapter on native platforms — this key only
      // means anything to the web adapter.
      extra: kIsWeb ? const {'withCredentials': true} : const {},
    ),
  );

  // Dio executes interceptors in registration order. Authentication,
  // refresh, and retry must therefore run before the logger so the logger
  // observes the final resolved response/error rather than an intermediate
  // 401 or transient failure.
  dio.interceptors.addAll([
    AuthHeaderInterceptor(ref),
    RefreshInterceptor(dio, ref),
    RetryInterceptor(dio),
    RedactingLogInterceptor(
      ref.watch(loggerProvider('network')),
      logBodies: config.enableVerboseLogging,
    ),
  ]);

  ref.onDispose(dio.close);

  return dio;
});

final apiClientProvider = Provider<ApiClient>(
  (ref) =>
      ApiClient(ref.watch(dioProvider), ref.watch(connectivityServiceProvider)),
);
