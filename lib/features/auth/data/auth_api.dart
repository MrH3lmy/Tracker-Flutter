import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/network_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/request_policy.dart';
import '../../../core/result/result.dart';
import 'auth_result.dart';
import 'client_platform.dart';

/// The two auth contracts Tracker-BE exposes, behind one interface so
/// `AuthRepository` never branches on platform itself. On [ClientPlatform.web]
/// every method calls the browser (cookie) routes; everywhere else, the
/// native (JSON-body refresh token) routes.
abstract interface class AuthApi {
  Future<Result<AuthResult>> register({
    required String email,
    required String password,
    String? displayName,
    String? deviceLabel,
  });

  Future<Result<AuthResult>> login({
    required String email,
    required String password,
    String? deviceLabel,
  });

  /// [refreshToken] is required on every platform except web, where the
  /// ambient `HttpOnly` cookie is the only credential — there is nothing
  /// for Dart code to pass.
  Future<Result<AuthResult>> refresh({String? refreshToken});

  Future<Result<void>> logout({String? refreshToken});

  Future<Result<void>> logoutAll();
}

class DioAuthApi implements AuthApi {
  DioAuthApi(this._apiClient, this._platform);

  final ApiClient _apiClient;
  final ClientPlatform _platform;

  bool get _isWeb => _platform == ClientPlatform.web;

  @override
  Future<Result<AuthResult>> register({
    required String email,
    required String password,
    String? displayName,
    String? deviceLabel,
  }) {
    return _apiClient.post<AuthResult>(
      _isWeb ? '/api/v1/auth/register' : '/api/v1/auth/native/register',
      decode: (data) => AuthResult.fromJson(data as Map<String, dynamic>),
      data: {
        'email': email,
        'password': password,
        'displayName': ?displayName,
        'deviceLabel': ?deviceLabel,
        if (!_isWeb) 'platform': _platformName,
      },
      policy: const RequestPolicy(skipAuth: true),
    );
  }

  @override
  Future<Result<AuthResult>> login({
    required String email,
    required String password,
    String? deviceLabel,
  }) {
    return _apiClient.post<AuthResult>(
      _isWeb ? '/api/v1/auth/login' : '/api/v1/auth/native/login',
      decode: (data) => AuthResult.fromJson(data as Map<String, dynamic>),
      data: {
        'email': email,
        'password': password,
        'deviceLabel': ?deviceLabel,
        if (!_isWeb) 'platform': _platformName,
      },
      policy: const RequestPolicy(skipAuth: true),
    );
  }

  @override
  Future<Result<AuthResult>> refresh({String? refreshToken}) {
    return _apiClient.post<AuthResult>(
      _isWeb ? '/api/v1/auth/refresh' : '/api/v1/auth/native/refresh',
      decode: (data) => AuthResult.fromJson(data as Map<String, dynamic>),
      data: _isWeb ? null : {'refreshToken': refreshToken},
      policy: const RequestPolicy(skipAuth: true, isAuthRefreshRequest: true),
    );
  }

  @override
  Future<Result<void>> logout({String? refreshToken}) {
    return _apiClient.post<void>(
      _isWeb ? '/api/v1/auth/logout' : '/api/v1/auth/native/logout',
      decode: (_) {},
      data: _isWeb ? null : {'refreshToken': refreshToken},
      policy: const RequestPolicy(skipAuth: true),
    );
  }

  @override
  Future<Result<void>> logoutAll() {
    return _apiClient.post<void>(
      _isWeb ? '/api/v1/auth/logout-all' : '/api/v1/auth/native/logout-all',
      decode: (_) {},
      // Idempotent in effect (revokes every session either way) and needs
      // the current access token, which may itself be near-expired — mark
      // retryable so a 401 here is transparently replayed after refresh
      // instead of surfacing to the caller.
      policy: const RequestPolicy(retryable: true),
    );
  }

  String get _platformName => switch (_platform) {
    ClientPlatform.web => 'WEB',
    ClientPlatform.android => 'ANDROID',
    ClientPlatform.ios => 'IOS',
    ClientPlatform.windows => 'WINDOWS',
    ClientPlatform.macos => 'MACOS',
    ClientPlatform.linux => 'LINUX',
  };
}

final authApiProvider = Provider<AuthApi>(
  (ref) => DioAuthApi(
    ref.watch(apiClientProvider),
    ref.watch(clientPlatformProvider),
  ),
);
