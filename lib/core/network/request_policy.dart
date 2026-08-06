import 'package:dio/dio.dart';

/// Per-request safety flags the interceptor chain reads instead of
/// guessing from the HTTP method alone.
///
/// [idempotent] and [retryable] both gate automatic retry (transient-error
/// retry and, indirectly, whether a request is safe to replay after a
/// token refresh): GET/HEAD are idempotent by default, everything else
/// needs an explicit opt-in because retrying a POST/PATCH blindly can
/// duplicate side effects.
class RequestPolicy {
  const RequestPolicy({
    this.idempotent = false,
    this.retryable = false,
    this.skipAuth = false,
    this.isAuthRefreshRequest = false,
  });

  final bool idempotent;
  final bool retryable;
  final bool skipAuth;

  /// Set by the concrete `AuthSession` implementation on the request it
  /// issues to refresh a session, so [RefreshInterceptor] never tries to
  /// refresh-and-retry the refresh call itself.
  final bool isAuthRefreshRequest;

  static const _extraKey = 'tracker.requestPolicy';

  Options toOptions({Options? base}) {
    final options = base ?? Options();
    final extra = {...?options.extra, _extraKey: this};
    return options.copyWith(extra: extra);
  }
}

extension RequestOptionsPolicy on RequestOptions {
  RequestPolicy get policy =>
      (extra[RequestPolicy._extraKey] as RequestPolicy?) ??
      (method == 'GET' || method == 'HEAD'
          ? const RequestPolicy(idempotent: true)
          : const RequestPolicy());

  /// Whether an automatic retry (transient-error or post-refresh replay) is
  /// safe to perform for this specific request.
  bool get isSafeToRetry => policy.idempotent || policy.retryable;
}
