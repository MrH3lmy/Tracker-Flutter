import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/config/app_environment.dart';
import 'core/di/app_providers.dart';
import 'core/logging/app_logger.dart';
import 'core/network/auth/auth_session.dart';
import 'features/auth/data/auth_repository.dart';
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
          overrides: [
            appConfigProvider.overrideWithValue(config),
            // The authentication epic's real session controller — see
            // AuthRepository's doc comment for why this is the one place
            // that wires it in.
            authSessionProvider.overrideWith(
              (ref) => ref.watch(authRepositoryProvider.notifier),
            ),
          ],
          child: const TrackerApp(),
        ),
      );
    },
    (error, stackTrace) {
      logger.error('Uncaught zone error', error, stackTrace);
    },
  );
}
