import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/features/auth/data/client_platform.dart';

void main() {
  group('clientPlatformFrom', () {
    test('is web whenever isWeb is true, regardless of target platform', () {
      expect(
        clientPlatformFrom(isWeb: true, targetPlatform: TargetPlatform.android),
        ClientPlatform.web,
      );
    });

    test('maps each native target platform', () {
      expect(
        clientPlatformFrom(
          isWeb: false,
          targetPlatform: TargetPlatform.android,
        ),
        ClientPlatform.android,
      );
      expect(
        clientPlatformFrom(isWeb: false, targetPlatform: TargetPlatform.iOS),
        ClientPlatform.ios,
      );
      expect(
        clientPlatformFrom(
          isWeb: false,
          targetPlatform: TargetPlatform.windows,
        ),
        ClientPlatform.windows,
      );
      expect(
        clientPlatformFrom(isWeb: false, targetPlatform: TargetPlatform.macOS),
        ClientPlatform.macos,
      );
      expect(
        clientPlatformFrom(isWeb: false, targetPlatform: TargetPlatform.linux),
        ClientPlatform.linux,
      );
    });

    test(
      'falls back to linux for an unsupported target rather than throwing',
      () {
        expect(
          clientPlatformFrom(
            isWeb: false,
            targetPlatform: TargetPlatform.fuchsia,
          ),
          ClientPlatform.linux,
        );
      },
    );
  });
}
