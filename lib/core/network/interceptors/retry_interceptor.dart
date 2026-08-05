import 'package:dio/dio.dart';

import '../errors/dio_failure_mapper.dart';
import '../request_policy.dart';

/// Retries transient failures (timeouts, `5xx`, `429`) — never anything
/// else, and never a request that isn't idempotent or explicitly marked
/// `retryable` via [RequestPolicy], so a flaky network can't turn one
/// "create task" tap into two tasks.
///
/// [delay] is injectable so tests don't have to wait out real backoff
/// timers.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._dio, {
    this.maxAttempts = 2,
    this.baseDelay = const Duration(milliseconds: 300),
    Future<void> Function(Duration duration)? delay,
  }) : _delay = delay ?? Future<void>.delayed;

  final Dio _dio;
  final int maxAttempts;
  final Duration baseDelay;
  final Future<void> Function(Duration duration) _delay;

  static const _attemptKey = 'tracker.retryAttempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;

    if (!_isRetryableFailure(err) ||
        !options.isSafeToRetry ||
        attempt >= maxAttempts) {
      handler.next(err);
      return;
    }

    await _delay(_delayFor(err, attempt));

    final retryOptions = options.copyWith(
      extra: {...options.extra, _attemptKey: attempt + 1},
    );

    try {
      final response = await _dio.fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _isRetryableFailure(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return true;
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode;
        return status != null && (status == 429 || status >= 500);
      default:
        return false;
    }
  }

  Duration _delayFor(DioException err, int attempt) {
    final retryAfter = extractRetryAfter(err.response);
    if (retryAfter != null) return retryAfter;
    return baseDelay * (attempt + 1);
  }
}
