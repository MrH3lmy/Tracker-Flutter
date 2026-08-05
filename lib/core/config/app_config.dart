import 'app_environment.dart';

/// Environment-specific configuration, resolved entirely from
/// `--dart-define` values at build/run time — nothing here is a committed
/// secret, and there is no production default that silently points at a
/// real backend.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.enableVerboseLogging,
  });

  factory AppConfig.fromEnvironment(AppEnvironment environment) {
    // API_BASE_URL must be supplied per environment via --dart-define; it is
    // intentionally left blank rather than defaulted to a guessed backend
    // host. See docs/architecture.md for the flavor entry points that set
    // sane locals for day-to-day development.
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

    return AppConfig(
      environment: environment,
      apiBaseUrl: apiBaseUrl.isEmpty ? _defaultLocalBaseUrl : apiBaseUrl,
      enableVerboseLogging:
          environment == AppEnvironment.local ||
          environment == AppEnvironment.development,
    );
  }

  final AppEnvironment environment;
  final String apiBaseUrl;
  final bool enableVerboseLogging;

  bool get isProduction => environment == AppEnvironment.production;

  // Only used when API_BASE_URL is not supplied, which should only happen
  // for local development against a co-located Tracker-BE instance.
  static const _defaultLocalBaseUrl = 'http://localhost:8080';
}
