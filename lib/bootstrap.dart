import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/config/app_environment.dart';
import 'core/di/app_providers.dart';
import 'core/logging/app_logger.dart';
import 'src/app.dart';

/// Shared entry point for every flavor (see `main_*.dart`).
///
/// Centralizing this means each flavor file is only responsible for naming
/// its environment; error handling, logging setup, and provider overrides
/// happen exactly once instead of being copy-pasted per flavor.
Future<void> bootstrap(AppEnvironment environment) async {
  final config = AppConfig.fromEnvironment(environment);
  AppLogger.init(productionMode: config.isProduction);
  final logger = AppLogger('bootstrap');

  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        logger.error(
          'Uncaught Flutter error',
          details.exception,
          details.stack,
        );
      };

      runApp(
        ProviderScope(
          overrides: [appConfigProvider.overrideWithValue(config)],
          child: const TrackerApp(),
        ),
      );
    },
    (error, stackTrace) {
      logger.error('Uncaught zone error', error, stackTrace);
    },
  );
}
