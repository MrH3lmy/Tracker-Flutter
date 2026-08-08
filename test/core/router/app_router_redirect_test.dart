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
  Widget app(SessionStatus status) => ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.fromEnvironment(AppEnvironment.local),
      ),
      sessionStatusProvider.overrideWithValue(status),
    ],
    child: const TrackerApp(),
  );

  testWidgets('unknown holds the app on the splash screen', (tester) async {
    await tester.pumpWidget(app(SessionStatus.unknown));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Tracker'), findsNothing);
  });

  testWidgets('unauthenticated redirects to the sign-in screen', (
    tester,
  ) async {
    await tester.pumpWidget(app(SessionStatus.unauthenticated));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets(
    'authenticated users are bounced away from the sign-in route back to home',
    (tester) async {
      await tester.pumpWidget(app(SessionStatus.authenticated));
      await tester.pumpAndSettle();

      final router = ProviderScope.containerOf(
        tester.element(find.byType(TrackerApp)),
      ).read(routerProvider);
      router.go(AppRoutes.signIn);
      await tester.pumpAndSettle();

      expect(find.text('Tracker'), findsWidgets);
      expect(find.text('Sign in'), findsNothing);
    },
  );

  testWidgets('unauthenticated users cannot navigate straight to home', (
    tester,
  ) async {
    await tester.pumpWidget(app(SessionStatus.unauthenticated));
    await tester.pumpAndSettle();

    final router = ProviderScope.containerOf(
      tester.element(find.byType(TrackerApp)),
    ).read(routerProvider);
    router.go(AppRoutes.home);
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
  });
}
