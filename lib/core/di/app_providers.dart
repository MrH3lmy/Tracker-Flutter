import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../logging/app_logger.dart';

/// Overridden once in [ProviderScope] at app startup with the resolved
/// [AppConfig] for the running flavor. Left unimplemented so any provider
/// that reads it before bootstrap runs fails loudly instead of silently
/// using the wrong environment.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError(
    'appConfigProvider must be overridden in bootstrap()',
  ),
);

/// Per-feature loggers should depend on this rather than constructing their
/// own `AppLogger`, so log routing stays centralized.
final loggerProvider = Provider.family<AppLogger, String>(
  (ref, name) => AppLogger(name),
);
