import 'app_environment.dart';

/// Environment-specific configuration, resolved entirely from
/// `--dart-define` values at build/run time. No secret or production backend
/// URL is committed to source control.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.enableVerboseLogging,
  });

  factory AppConfig.fromEnvironment(
    AppEnvironment environment, {
    String? apiBaseUrl,
  }) {
    const definedApiBaseUrl = String.fromEnvironment('API_BASE_URL');
    final configuredApiBaseUrl = (apiBaseUrl ?? definedApiBaseUrl).trim();
    final resolvedApiBaseUrl = configuredApiBaseUrl.isEmpty
        ? _defaultBaseUrlFor(environment)
        : configuredApiBaseUrl;

    _validateApiBaseUrl(environment, resolvedApiBaseUrl);

    return AppConfig(
      environment: environment,
      apiBaseUrl: resolvedApiBaseUrl,
      enableVerboseLogging:
          environment == AppEnvironment.local ||
          environment == AppEnvironment.development,
    );
  }

  final AppEnvironment environment;
  final String apiBaseUrl;
  final bool enableVerboseLogging;

  bool get isProduction => environment == AppEnvironment.production;

  static String _defaultBaseUrlFor(AppEnvironment environment) {
    if (environment == AppEnvironment.local) {
      return _defaultLocalBaseUrl;
    }

    throw StateError(
      'API_BASE_URL is required for the ${environment.name} environment.',
    );
  }

  static void _validateApiBaseUrl(
    AppEnvironment environment,
    String apiBaseUrl,
  ) {
    final uri = Uri.tryParse(apiBaseUrl);
    final supportedScheme =
        uri?.scheme == 'http' || uri?.scheme == 'https';

    if (uri == null || !uri.hasScheme || !uri.hasAuthority || !supportedScheme) {
      throw FormatException(
        'API_BASE_URL must be an absolute HTTP(S) URL.',
        apiBaseUrl,
      );
    }

    if (environment == AppEnvironment.production && uri.scheme != 'https') {
      throw StateError('Production API_BASE_URL must use HTTPS.');
    }
  }

  static const _defaultLocalBaseUrl = 'http://localhost:8080';
}
