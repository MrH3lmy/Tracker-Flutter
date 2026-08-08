import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/features/auth/data/secure_token_storage.dart';

void main() {
  group('NoopTokenStorage', () {
    const storage = NoopTokenStorage();

    test('never returns a stored token', () async {
      expect(await storage.readRefreshToken(), isNull);
    });

    test('write and delete are no-ops that never throw', () async {
      await storage.writeRefreshToken('some-token');
      await storage.deleteRefreshToken();
    });
  });

  group('FlutterSecureTokenStorage', () {
    // No platform channel handler is registered in the plain unit-test
    // environment, so the underlying plugin calls throw
    // MissingPluginException — this doubles as coverage for "the platform
    // channel/keystore is broken", which is exactly the corruption case
    // readRefreshToken/deleteRefreshToken must degrade safely from.
    final storage = FlutterSecureTokenStorage();

    test(
      'readRefreshToken returns null instead of throwing when storage is unavailable',
      () async {
        expect(await storage.readRefreshToken(), isNull);
      },
    );

    test(
      'deleteRefreshToken completes instead of throwing when storage is unavailable',
      () async {
        await expectLater(storage.deleteRefreshToken(), completes);
      },
    );
  });
}
