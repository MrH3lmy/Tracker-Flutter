import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracker_flutter/core/config/app_config.dart';
import 'package:tracker_flutter/core/config/app_environment.dart';
import 'package:tracker_flutter/core/di/app_providers.dart';
import 'package:tracker_flutter/src/app.dart';

/// End-to-end smoke coverage for the bootstrap epic: the app launches and
/// reaches the home screen inside the adaptive shell. Feature epics extend
/// this file with their own end-to-end flows (e.g. login → select project →
/// browse tasks) rather than replacing it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches to the home screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromEnvironment(AppEnvironment.local),
          ),
        ],
        child: const TrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tracker'), findsWidgets);
  });
}
