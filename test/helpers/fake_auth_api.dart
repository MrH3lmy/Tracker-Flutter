import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/auth/data/auth_api.dart';
import 'package:tracker_flutter/features/auth/data/auth_result.dart';

class FakeAuthApi implements AuthApi {
  Result<AuthResult>? registerResult;
  Result<AuthResult>? loginResult;
  Result<AuthResult>? refreshResult;
  Result<void> logoutResult = const Result<void>.success(null);
  Result<void> logoutAllResult = const Result<void>.success(null);

  int registerCalls = 0;
  int loginCalls = 0;
  int refreshCalls = 0;
  int logoutCalls = 0;
  int logoutAllCalls = 0;
  String? lastRefreshTokenPassedToRefresh;
  String? lastRefreshTokenPassedToLogout;

  @override
  Future<Result<AuthResult>> register({
    required String email,
    required String password,
    String? displayName,
    String? deviceLabel,
  }) async {
    registerCalls++;
    return registerResult!;
  }

  @override
  Future<Result<AuthResult>> login({
    required String email,
    required String password,
    String? deviceLabel,
  }) async {
    loginCalls++;
    return loginResult!;
  }

  @override
  Future<Result<AuthResult>> refresh({String? refreshToken}) async {
    refreshCalls++;
    lastRefreshTokenPassedToRefresh = refreshToken;
    return refreshResult!;
  }

  @override
  Future<Result<void>> logout({String? refreshToken}) async {
    logoutCalls++;
    lastRefreshTokenPassedToLogout = refreshToken;
    return logoutResult;
  }

  @override
  Future<Result<void>> logoutAll() async {
    logoutAllCalls++;
    return logoutAllResult;
  }
}
