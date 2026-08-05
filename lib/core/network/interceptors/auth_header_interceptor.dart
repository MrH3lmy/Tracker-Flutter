import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_session.dart';
import '../request_policy.dart';

/// Injects the current bearer token from [AuthSession], unless the request
/// opted out via `RequestPolicy(skipAuth: true)`.
class AuthHeaderInterceptor extends Interceptor {
  AuthHeaderInterceptor(this._ref);

  final Ref _ref;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!options.policy.skipAuth) {
      final token = _ref.read(authSessionProvider).accessToken;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }
}
