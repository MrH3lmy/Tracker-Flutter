import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/error/app_failure.dart';
import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/auth/data/auth_api.dart';
import 'package:tracker_flutter/features/auth/data/client_platform.dart';
import 'package:tracker_flutter/features/auth/data/secure_token_storage.dart';
import 'package:tracker_flutter/features/auth/presentation/sign_in_screen.dart';

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
      home: const SignInScreen(),
      routes: {'/register': (context) => const SizedBox()},
    ),
  );

  Finder submitButton() => find.widgetWithText(FilledButton, 'Sign in');

  testWidgets(
    'shows validation errors for empty fields without calling the API',
    (tester) async {
      final api = FakeAuthApi();
      await tester.pumpWidget(host(api));

      await tester.tap(submitButton());
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(api.loginCalls, 0);
    },
  );

  testWidgets('shows the failure message when login fails', (tester) async {
    final api = FakeAuthApi()
      ..loginResult = const Result.failure(
        ValidationFailure(message: 'Invalid email or password.'),
      );
    await tester.pumpWidget(host(api));

    await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
    await tester.enterText(find.byType(TextFormField).last, 'wrong-password');
    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(api.loginCalls, 1);
  });
}
