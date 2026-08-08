import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/features/auth/domain/session_state.dart';
import 'package:tracker_flutter/features/auth/domain/user.dart';

void main() {
  const user = User(
    id: 1,
    email: 'a@b.com',
    displayName: null,
    tier: UserTier.free,
    role: UserRole.user,
  );

  group('SessionState.userOrNull', () {
    test('is null for unknown', () {
      expect(const SessionState.unknown().userOrNull, isNull);
    });

    test('is null for unauthenticated', () {
      expect(const SessionState.unauthenticated().userOrNull, isNull);
    });

    test('is the user for authenticated', () {
      expect(const SessionState.authenticated(user).userOrNull, user);
    });

    test('is the previous user for refreshing', () {
      expect(const SessionState.refreshing(user).userOrNull, user);
    });

    test('is null for unrecoverable', () {
      expect(const SessionState.unrecoverable().userOrNull, isNull);
    });
  });

  test('pattern matching distinguishes every variant', () {
    String describe(SessionState state) => switch (state) {
      SessionUnknown() => 'unknown',
      SessionAuthenticated() => 'authenticated',
      SessionUnauthenticated() => 'unauthenticated',
      SessionRefreshing() => 'refreshing',
      SessionUnrecoverable() => 'unrecoverable',
    };

    expect(describe(const SessionState.unknown()), 'unknown');
    expect(describe(const SessionState.authenticated(user)), 'authenticated');
    expect(describe(const SessionState.unauthenticated()), 'unauthenticated');
    expect(describe(const SessionState.refreshing(user)), 'refreshing');
    expect(describe(const SessionState.unrecoverable()), 'unrecoverable');
  });
}
