import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_session.dart';
import '../request_policy.dart';

/// Coalesces concurrent authenticated `401` responses into a single refresh
/// attempt and replays only requests whose [RequestPolicy] marks them safe.
///
/// Public requests (`skipAuth`) and the refresh request itself are never
/// intercepted. A retried request is marked in `RequestOptions.extra`, so a
/// second `401` signs the session out instead of entering a refresh loop.
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
    final policy = requestOptions.policy;
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = requestOptions.extra[_retriedKey] == true;

    if (!isUnauthorized || policy.skipAuth || policy.isAuthRefreshRequest) {
      handler.next(err);
      return;
    }

    final session = _ref.read(authSessionProvider);

    if (alreadyRetried) {
      await _safeForceSignOut(session);
      handler.next(err);
      return;
    }

    final newToken = await (_inFlightRefresh ??= _refreshOnce(session));
    if (newToken == null) {
      handler.next(err);
      return;
    }

    // Refreshing an unsafe write is useful for subsequent requests, but the
    // original request must not be replayed automatically because its body or
    // server-side effects may not be safely repeatable.
    if (!requestOptions.isSafeToRetry) {
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
      // The nested fetch re-enters this interceptor. If it is still
      // unauthorized, the `alreadyRetried` path signs out safely.
      handler.next(retryError);
    }
  }

  Future<String?> _refreshOnce(AuthSession session) async {
    try {
      final token = await session.refreshAccessToken();
      if (token == null || token.isEmpty) {
        await _safeForceSignOut(session);
        return null;
      }
      return token;
    } catch (_) {
      await _safeForceSignOut(session);
      return null;
    } finally {
      _inFlightRefresh = null;
    }
  }

  Future<void> _safeForceSignOut(AuthSession session) async {
    try {
      await session.forceSignOut();
    } catch (_) {
      // A broken sign-out implementation must not escape the interceptor and
      // violate ApiClient's Result-returning contract.
    }
  }
}
