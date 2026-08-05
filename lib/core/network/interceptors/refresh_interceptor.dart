import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_session.dart';
import '../request_policy.dart';

/// Coalesces concurrent `401` responses into a single refresh attempt and
/// replays the requests that were waiting on it, exactly once each.
///
/// Concurrency: the first `401` starts [AuthSession.refreshAccessToken] and
/// stores the in-flight future; every `401` that arrives while it's
/// outstanding awaits that same future instead of starting its own — Dio
/// invokes `onError` per failing request, so without this, N concurrent
/// `401`s would trigger N refresh calls.
///
/// Loop prevention: a retried request is marked
/// `tracker.refreshRetried = true` in its extras. If that retry itself
/// comes back `401`, this interceptor passes it straight through instead
/// of refreshing again — a request is refreshed-and-replayed at most once.
class RefreshInterceptor extends Interceptor {
  RefreshInterceptor(this._dio, this._ref);

  final Dio _dio;
  final Ref _ref;

  static const _retriedKey = 'tracker.refreshRetried';

  Future<String?>? _inFlightRefresh;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final requestOptions = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = requestOptions.extra[_retriedKey] == true;
    final isRefreshCall = requestOptions.policy.isAuthRefreshRequest;

    if (!isUnauthorized || alreadyRetried || isRefreshCall) {
      handler.next(err);
      return;
    }

    final session = _ref.read(authSessionProvider);
    String? newToken;
    try {
      newToken = await (_inFlightRefresh ??= _refreshOnce(session));
    } catch (_) {
      // AuthSession.refreshAccessToken() is documented not to throw, but a
      // failing implementation shouldn't crash the interceptor chain — an
      // unrecoverable session is exactly what forceSignOut() below is for.
      newToken = null;
    }

    if (newToken == null || newToken.isEmpty) {
      await session.forceSignOut();
      handler.next(err);
      return;
    }

    final retryOptions = requestOptions.copyWith(
      extra: {...requestOptions.extra, _retriedKey: true},
    )..headers['Authorization'] = 'Bearer $newToken';

    try {
      final response = await _dio.fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<String?> _refreshOnce(AuthSession session) async {
    try {
      return await session.refreshAccessToken();
    } finally {
      _inFlightRefresh = null;
    }
  }
}
