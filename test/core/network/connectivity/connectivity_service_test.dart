import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/network/connectivity/connectivity_service.dart';

void main() {
  group('hasNetworkPresenceFrom', () {
    test('is false when every result is none', () {
      expect(hasNetworkPresenceFrom([ConnectivityResult.none]), isFalse);
    });

    test('is true when any interface is up', () {
      expect(
        hasNetworkPresenceFrom([
          ConnectivityResult.none,
          ConnectivityResult.wifi,
        ]),
        isTrue,
      );
    });

    test('is false for an empty result list', () {
      expect(hasNetworkPresenceFrom(const []), isFalse);
    });
  });
}
