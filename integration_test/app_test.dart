import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracker_flutter/core/config/app_config.dart';
import 'package:tracker_flutter/core/config/app_environment.dart';
import 'package:tracker_flutter/core/di/app_providers.dart';
import 'package:tracker_flutter/src/app.dart';

/// End-to-end smoke coverage for the bootstrap epic: the app launches and
/// reaches a stable screen without a live backend. With no stored
/// credential and no Tracker-BE reachable, session restoration correctly
/// settles on the sign-in screen rather than the authenticated shell — see
/// `test/integration/app_flow_test.dart` for the full authenticated
/// launch -> sign in -> load projects -> select project flow, which fakes
/// only the network boundary since a real device/backend pairing isn't
/// available to run against here. Feature epics extend that file with
/// their own flows (e.g. select project -> browse boards) rather than
/// replacing it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches to the sign-in screen', (tester) async {
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

    expect(find.text('Sign in'), findsWidgets);
  });
}
