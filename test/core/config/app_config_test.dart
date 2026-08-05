import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/config/app_config.dart';
import 'package:tracker_flutter/core/config/app_environment.dart';

void main() {
  group('AppConfig.fromEnvironment', () {
    test('falls back to localhost only for the local environment', () {
      final config = AppConfig.fromEnvironment(
        AppEnvironment.local,
        apiBaseUrl: '',
      );

      expect(config.apiBaseUrl, 'http://localhost:8080');
      expect(config.environment, AppEnvironment.local);
    });

    test('requires an explicit base URL outside the local environment', () {
      for (final environment in [
        AppEnvironment.development,
        AppEnvironment.staging,
        AppEnvironment.production,
      ]) {
        expect(
          () => AppConfig.fromEnvironment(environment, apiBaseUrl: ''),
          throwsStateError,
          reason: '${environment.name} must not silently use localhost',
        );
      }
    });

    test('rejects an insecure production base URL', () {
      expect(
        () => AppConfig.fromEnvironment(
          AppEnvironment.production,
          apiBaseUrl: 'http://api.example.com',
        ),
        throwsStateError,
      );
    });

    test('rejects malformed and unsupported base URLs', () {
      expect(
        () => AppConfig.fromEnvironment(
          AppEnvironment.staging,
          apiBaseUrl: 'api.example.com',
        ),
        throwsFormatException,
      );
      expect(
        () => AppConfig.fromEnvironment(
          AppEnvironment.staging,
          apiBaseUrl: 'ftp://api.example.com',
        ),
        throwsFormatException,
      );
    });

    test('accepts a secure production base URL', () {
      final config = AppConfig.fromEnvironment(
        AppEnvironment.production,
        apiBaseUrl: 'https://api.example.com',
      );

      expect(config.apiBaseUrl, 'https://api.example.com');
      expect(config.isProduction, isTrue);
    });

    test('enables verbose logging only for local and development', () {
      expect(_config(AppEnvironment.local).enableVerboseLogging, isTrue);
      expect(_config(AppEnvironment.development).enableVerboseLogging, isTrue);
      expect(_config(AppEnvironment.staging).enableVerboseLogging, isFalse);
      expect(_config(AppEnvironment.production).enableVerboseLogging, isFalse);
    });

    test('isProduction is true only for the production environment', () {
      expect(_config(AppEnvironment.production).isProduction, isTrue);
      expect(_config(AppEnvironment.staging).isProduction, isFalse);
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

AppConfig _config(AppEnvironment environment) {
  return AppConfig.fromEnvironment(
    environment,
    apiBaseUrl: environment == AppEnvironment.local
        ? 'http://localhost:8080'
        : 'https://api.example.com',
  );
}
