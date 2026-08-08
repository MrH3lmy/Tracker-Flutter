import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/error/app_failure.dart';
import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/auth/data/auth_api.dart';
import 'package:tracker_flutter/features/auth/data/client_platform.dart';
import 'package:tracker_flutter/features/auth/data/secure_token_storage.dart';
import 'package:tracker_flutter/features/auth/presentation/register_screen.dart';

import '../../../helpers/fake_auth_api.dart';
import '../../../helpers/fake_secure_token_storage.dart';

void main() {
  Widget host(FakeAuthApi api) => ProviderScope(
    overrides: [
      authApiProvider.overrideWithValue(api),
      secureTokenStorageProvider.overrideWithValue(FakeSecureTokenStorage()),
      clientPlatformProvider.overrideWithValue(ClientPlatform.android),
    ],
    child: MaterialApp(
      home: const RegisterScreen(),
      routes: {'/sign-in': (context) => const SizedBox()},
    ),
  );

  Finder submitButton() => find.widgetWithText(FilledButton, 'Create account');

  testWidgets('rejects a password shorter than 8 characters', (tester) async {
    final api = FakeAuthApi();
    await tester.pumpWidget(host(api));

    await tester.enterText(find.byType(TextFormField).at(1), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'short');
    await tester.tap(submitButton());
    await tester.pump();

    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    expect(api.registerCalls, 0);
  });

  testWidgets('shows the failure message when registration fails', (
    tester,
  ) async {
    final api = FakeAuthApi()
      ..registerResult = const Result.failure(
        ValidationFailure(
          message: 'An account with this email already exists.',
        ),
      );
    await tester.pumpWidget(host(api));

    await tester.enterText(find.byType(TextFormField).at(1), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(
      find.text('An account with this email already exists.'),
      findsOneWidget,
    );
    expect(api.registerCalls, 1);
  });
}
