import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/config/app_config.dart';
import 'package:tracker_flutter/core/config/app_environment.dart';

void main() {
  group('AppConfig.fromEnvironment', () {
    test('falls back to a local base URL when none is defined', () {
      final config = AppConfig.fromEnvironment(AppEnvironment.local);
      expect(config.apiBaseUrl, isNotEmpty);
      expect(config.environment, AppEnvironment.local);
    });

    test('enables verbose logging only for local and development', () {
      expect(
        AppConfig.fromEnvironment(AppEnvironment.local).enableVerboseLogging,
        isTrue,
      );
      expect(
        AppConfig.fromEnvironment(
          AppEnvironment.development,
        ).enableVerboseLogging,
        isTrue,
      );
      expect(
        AppConfig.fromEnvironment(AppEnvironment.staging).enableVerboseLogging,
        isFalse,
      );
      expect(
        AppConfig.fromEnvironment(
          AppEnvironment.production,
        ).enableVerboseLogging,
        isFalse,
      );
    });

    test('isProduction is true only for the production environment', () {
      expect(
        AppConfig.fromEnvironment(AppEnvironment.production).isProduction,
        isTrue,
      );
      expect(
        AppConfig.fromEnvironment(AppEnvironment.staging).isProduction,
        isFalse,
      );
    });
  });

  group('AppEnvironment.fromName', () {
    test('parses known names', () {
      expect(AppEnvironment.fromName('production'), AppEnvironment.production);
    });

    test('defaults unknown names to local', () {
      expect(AppEnvironment.fromName('nonsense'), AppEnvironment.local);
    });
  });
}
