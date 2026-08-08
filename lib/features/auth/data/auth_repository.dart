import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/auth/auth_session.dart';
import '../../../core/result/result.dart';
import '../domain/session_state.dart';
import '../domain/user.dart';
import 'auth_api.dart';
import 'auth_result.dart';
import 'client_platform.dart';
import 'secure_token_storage.dart';

/// The real [AuthSession] implementation and the single source of truth for
/// [SessionState]. Bound to the networking layer's `authSessionProvider`
/// and the router's `sessionStatusProvider` via overrides in
/// `bootstrap.dart` / `core/router/session_status.dart` — this class itself
/// has no idea either of those exist.
///
/// The access token lives only in [_accessToken] (a plain field, never
/// written to storage or logged). On native platforms the refresh token is
/// mirrored to [SecureTokenStorage]; on web, [_refreshToken] and storage are
/// both unused — the browser's `HttpOnly` cookie is the only credential and
/// Dart code never sees its value.
class AuthRepository extends Notifier<SessionState> implements AuthSession {
  late AuthApi _api;
  late SecureTokenStorage _storage;
  late bool _isWeb;
  late Future<void> _startupRestoration;

  String? _accessToken;
  String? _refreshToken;

  @override
  SessionState build() {
    _api = ref.watch(authApiProvider);
    _storage = ref.watch(secureTokenStorageProvider);
    _isWeb = ref.watch(clientPlatformProvider) == ClientPlatform.web;
    // Fire-and-forget in production (the splash route holds the UI on
    // SessionState.unknown until this resolves) — exposed as
    // [startupRestoration] so callers that do need to know when it settles
    // (namely tests) can await the exact call build() triggered instead of
    // guessing with an arbitrary delay or racing a second call against it.
    _startupRestoration = restoreSession();
    return const SessionState.unknown();
  }

  Future<void> get startupRestoration => _startupRestoration;

  @override
  String? get accessToken => _accessToken;

  /// Runs once at startup (see [build]) so the router can hold protected
  /// routes behind [SessionState.unknown] until this resolves. Web attempts
  /// a silent refresh against the ambient cookie; native reads the stored
  /// refresh token (if any) and exchanges it. Every failure path —
  /// no stored credential, an expired/revoked/replayed one, or storage
  /// itself being unreadable — converges on the same
  /// [SessionState.unauthenticated]: there is no safe way to tell those
  /// apart from here, and the correct action (sign in again) is identical.
  Future<void> restoreSession() async {
    if (_isWeb) {
      final result = await _api.refresh();
      await result.when(
        success: _applyAuthenticated,
        failure: (_) async => _applyUnauthenticated(),
      );
      return;
    }

    // SecureTokenStorage.readRefreshToken() never throws — a corrupted or
    // unreadable entry surfaces as null, the same as "never signed in",
    // which is exactly the right outcome here.
    final storedToken = await _storage.readRefreshToken();
    if (storedToken == null) {
      _applyUnauthenticated();
      return;
    }

    final result = await _api.refresh(refreshToken: storedToken);
    await result.when(
      success: _applyAuthenticated,
      failure: (_) async {
        await _clearStoredToken();
        _applyUnauthenticated();
      },
    );
  }

  Future<Result<User>> login({
    required String email,
    required String password,
    String? deviceLabel,
  }) async {
    final result = await _api.login(
      email: email,
      password: password,
      deviceLabel: deviceLabel,
    );
    return _applyAuthResult(result);
  }

  Future<Result<User>> register({
    required String email,
    required String password,
    String? displayName,
    String? deviceLabel,
  }) async {
    final result = await _api.register(
      email: email,
      password: password,
      displayName: displayName,
      deviceLabel: deviceLabel,
    );
    return _applyAuthResult(result);
  }

  Future<Result<User>> _applyAuthResult(Result<AuthResult> result) async {
    return result.when(
      success: (auth) async {
        await _applyAuthenticated(auth);
        return Result.success(auth.user);
      },
      failure: (failure) async {
        state = const SessionState.unauthenticated();
        return Result.failure(failure);
      },
    );
  }

  Future<void> _applyAuthenticated(AuthResult auth) async {
    _accessToken = auth.accessToken;
    if (!_isWeb && auth.refreshToken != null) {
      _refreshToken = auth.refreshToken;
      try {
        await _storage.writeRefreshToken(auth.refreshToken!);
      } catch (_) {
        // The access token above is still good for the rest of this app
        // session; only persistence for the *next* launch is lost.
      }
    }
    state = SessionState.authenticated(auth.user);
  }

  void _applyUnauthenticated() {
    _accessToken = null;
    _refreshToken = null;
    state = const SessionState.unauthenticated();
  }

  /// Called by `RefreshInterceptor` on a `401`. Concurrent callers are
  /// already coalesced by that interceptor, so no single-flight guard is
  /// needed here.
  @override
  Future<String?> refreshAccessToken() async {
    final previousUser = state.userOrNull;
    if (previousUser != null) {
      state = SessionState.refreshing(previousUser);
    }

    if (!_isWeb && _refreshToken == null) {
      return null;
    }

    final result = await _api.refresh(
      refreshToken: _isWeb ? null : _refreshToken,
    );
    return result.when(
      success: (auth) {
        _accessToken = auth.accessToken;
        if (!_isWeb && auth.refreshToken != null) {
          _refreshToken = auth.refreshToken;
          unawaited(
            _storage.writeRefreshToken(auth.refreshToken!).catchError((_) {}),
          );
        }
        state = SessionState.authenticated(auth.user);
        return auth.accessToken;
      },
      // Returning null (not signing out here) is deliberate: the caller
      // (RefreshInterceptor) calls forceSignOut() itself when this returns
      // null, so the transition only happens in one place.
      failure: (_) => null,
    );
  }

  /// Called by `RefreshInterceptor` when [refreshAccessToken] cannot
  /// recover the session. Must not throw — it never does, since both steps
  /// here are already failure-tolerant.
  @override
  Future<void> forceSignOut() async {
    await _clearStoredToken();
    _applyUnauthenticated();
  }

  /// Best-effort: the user's intent (stop being signed in on this device)
  /// is honored locally even if the revoke call itself fails — e.g. while
  /// offline — since they shouldn't be trapped in a signed-in UI because of
  /// a network error the backend session will also expire on its own.
  Future<void> logout() async {
    await _api.logout(refreshToken: _refreshToken);
    await forceSignOut();
  }

  Future<void> logoutAll() async {
    await _api.logoutAll();
    await forceSignOut();
  }

  Future<void> _clearStoredToken() async {
    _refreshToken = null;
    if (_isWeb) return;
    await _storage.deleteRefreshToken();
  }
}

final authRepositoryProvider = NotifierProvider<AuthRepository, SessionState>(
  AuthRepository.new,
);
