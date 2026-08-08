import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/session_state.dart';

/// Router-facing simplification of [SessionState] (`features/auth`).
/// [SessionState.refreshing] maps to [authenticated] — a background token
/// refresh must not bounce the user to the sign-in screen — and
/// [SessionState.unrecoverable] maps to [unauthenticated], since the
/// correct action (sign in again) is the same either way; the richer state
/// is still available to any screen that wants to explain why.
enum SessionStatus { unknown, authenticated, unauthenticated }

final sessionStatusProvider = Provider<SessionStatus>((ref) {
  final session = ref.watch(authRepositoryProvider);
  return switch (session) {
    SessionUnknown() => SessionStatus.unknown,
    SessionAuthenticated() ||
    SessionRefreshing() => SessionStatus.authenticated,
    SessionUnauthenticated() ||
    SessionUnrecoverable() => SessionStatus.unauthenticated,
  };
});
