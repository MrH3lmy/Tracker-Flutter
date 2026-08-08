import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/config/app_config.dart';
import 'package:tracker_flutter/core/config/app_environment.dart';
import 'package:tracker_flutter/core/di/app_providers.dart';
import 'package:tracker_flutter/core/router/app_router.dart';
import 'package:tracker_flutter/core/router/session_status.dart';
import 'package:tracker_flutter/src/app.dart';

void main() {
  Widget app({SessionStatus status = SessionStatus.authenticated}) =>
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromEnvironment(AppEnvironment.local),
          ),
          // These smoke tests exercise the shell/home/not-found screens,
          // not the auth flow itself (see features/auth's own tests for
          // that) — fixing the status directly skips needing a full fake
          // auth stack just to reach the authenticated shell.
          sessionStatusProvider.overrideWithValue(status),
        ],
        child: const TrackerApp(),
      );

  testWidgets('launches to the home screen inside the app shell', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle(); // let the splash->home redirect resolve
    expect(find.text('Tracker'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 400)); // greeting future
    expect(
      find.textContaining('Connected to local environment'),
      findsOneWidget,
    );
  });

  testWidgets('unknown routes render the not-found screen', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final router = ProviderScope.containerOf(
      tester.element(find.byType(TrackerApp)),
    ).read(routerProvider);
    router.go('/does-not-exist');
    await tester.pumpAndSettle();

    expect(find.text('Page not found'), findsOneWidget);
  });
}
