import 'package:dio/dio.dart';
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
    ),
  );

  // Interceptor order matters. Dio runs request-phase interceptors in list
  // order but response/error-phase interceptors in *reverse* list order —
  // adding the logger first means its onResponse/onError runs *last*, after
  // auth/refresh/retry have already resolved or given up, so it always logs
  // the final outcome rather than an intermediate retry attempt.
  dio.interceptors.addAll([
    RedactingLogInterceptor(
      ref.watch(loggerProvider('network')),
      logBodies: config.enableVerboseLogging,
    ),
    AuthHeaderInterceptor(ref),
    RefreshInterceptor(dio, ref),
    RetryInterceptor(dio),
  ]);

  ref.onDispose(dio.close);

  return dio;
});

final apiClientProvider = Provider<ApiClient>(
  (ref) =>
      ApiClient(ref.watch(dioProvider), ref.watch(connectivityServiceProvider)),
);
