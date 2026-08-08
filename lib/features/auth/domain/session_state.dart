import '../../../core/error/app_failure.dart';
import 'user.dart';

/// The explicit authentication/session state machine. Kept separate from
/// [SessionStatus] (`core/router/session_status.dart`), which is a
/// router-facing simplification derived from this: [refreshing] maps to
/// "stay authenticated" (a background token refresh shouldn't bounce the
/// user to a sign-in screen) and [unrecoverable] maps to "unauthenticated"
/// (the session genuinely cannot continue, so the safe action is the same
/// as being signed out).
sealed class SessionState {
  const SessionState();

  const factory SessionState.unknown() = SessionUnknown;
  const factory SessionState.authenticated(User user) = SessionAuthenticated;
  const factory SessionState.unauthenticated() = SessionUnauthenticated;
  const factory SessionState.refreshing(User previousUser) = SessionRefreshing;
  const factory SessionState.unrecoverable({AppFailure? reason}) =
      SessionUnrecoverable;

  /// The signed-in user, if this state has one — [authenticated] and
  /// [refreshing] (which keeps the previous user visible while a background
  /// refresh is in flight) both do.
  User? get userOrNull => switch (this) {
    SessionAuthenticated(:final user) => user,
    SessionRefreshing(:final previousUser) => previousUser,
    SessionUnknown() ||
    SessionUnauthenticated() ||
    SessionUnrecoverable() => null,
  };
}

final class SessionUnknown extends SessionState {
  const SessionUnknown();
}

final class SessionAuthenticated extends SessionState {
  const SessionAuthenticated(this.user);
  final User user;
}

final class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated();
}

/// A refresh is in flight. [previousUser] lets the UI keep showing
/// authenticated content instead of flashing a loading/signed-out state for
/// what is usually a sub-second background request.
final class SessionRefreshing extends SessionState {
  const SessionRefreshing(this.previousUser);
  final User previousUser;
}

/// The session cannot be recovered (e.g. secure storage is corrupted and
/// unreadable). Distinct from [SessionUnauthenticated] so the UI can, if it
/// chooses, explain *why* re-authentication is required instead of showing
/// a plain sign-in screen.
final class SessionUnrecoverable extends SessionState {
  const SessionUnrecoverable({this.reason});
  final AppFailure? reason;
}
