import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The networking layer's view of authentication — deliberately narrow so
/// the authentication epic (#3) can supply a real implementation without
/// this layer changing.
abstract interface class AuthSession {
  /// The current in-memory access token, or `null` when signed out.
  /// Never persisted by this layer — see the authentication epic for
  /// secure-storage handling of refresh credentials.
  String? get accessToken;

  /// Attempts to refresh the session, returning the new access token on
  /// success or `null` if the session cannot be recovered. Concurrent
  /// callers are coalesced by [RefreshInterceptor], so implementations do
  /// not need their own single-flight guard.
  Future<String?> refreshAccessToken();

  /// Called when refresh cannot recover the session, so the app can enter
  /// a safe signed-out state. Must not throw.
  Future<void> forceSignOut();
}

/// Default binding until the authentication epic overrides
/// [authSessionProvider] with a real session controller: no token, refresh
/// never succeeds, and sign-out is a no-op since there's nothing to clear.
class NullAuthSession implements AuthSession {
  const NullAuthSession();

  @override
  String? get accessToken => null;

  @override
  Future<String?> refreshAccessToken() async => null;

  @override
  Future<void> forceSignOut() async {}
}

final authSessionProvider = Provider<AuthSession>(
  (ref) => const NullAuthSession(),
);
