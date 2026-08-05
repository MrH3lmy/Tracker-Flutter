import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/network/auth/auth_session.dart';

void main() {
  group('NullAuthSession', () {
    const session = NullAuthSession();

    test('has no access token', () {
      expect(session.accessToken, isNull);
    });

    test('refresh never recovers a session', () async {
      expect(await session.refreshAccessToken(), isNull);
    });

    test('forceSignOut completes without throwing', () async {
      await expectLater(session.forceSignOut(), completes);
    });
  });
}
