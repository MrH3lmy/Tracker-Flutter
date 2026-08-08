import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/router/session_status.dart';
import 'package:tracker_flutter/features/auth/data/auth_repository.dart';
import 'package:tracker_flutter/features/auth/domain/session_state.dart';
import 'package:tracker_flutter/features/auth/domain/user.dart';

const _user = User(
  id: 1,
  email: 'a@b.com',
  displayName: null,
  tier: UserTier.free,
  role: UserRole.user,
);

/// A Notifier that skips AuthRepository's real build() (and therefore its
/// dependency chain) entirely, just to prove sessionStatusProvider's
/// SessionState -> SessionStatus mapping in isolation.
class _FixedSessionRepository extends AuthRepository {
  _FixedSessionRepository(this._fixedState);
  final SessionState _fixedState;

  @override
  SessionState build() => _fixedState;
}

void main() {
  SessionStatus statusFor(SessionState state) {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith(
          () => _FixedSessionRepository(state),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container.read(sessionStatusProvider);
  }

  test('unknown maps to unknown', () {
    expect(statusFor(const SessionState.unknown()), SessionStatus.unknown);
  });

  test('authenticated maps to authenticated', () {
    expect(
      statusFor(const SessionState.authenticated(_user)),
      SessionStatus.authenticated,
    );
  });

  test(
    'refreshing maps to authenticated so a background refresh does not bounce navigation',
    () {
      expect(
        statusFor(const SessionState.refreshing(_user)),
        SessionStatus.authenticated,
      );
    },
  );

  test('unauthenticated maps to unauthenticated', () {
    expect(
      statusFor(const SessionState.unauthenticated()),
      SessionStatus.unauthenticated,
    );
  });

  test('unrecoverable maps to unauthenticated', () {
    expect(
      statusFor(const SessionState.unrecoverable()),
      SessionStatus.unauthenticated,
    );
  });
}
