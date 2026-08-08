import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/error/app_failure.dart';
import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/auth/data/auth_api.dart';
import 'package:tracker_flutter/features/auth/data/auth_repository.dart';
import 'package:tracker_flutter/features/auth/data/auth_result.dart';
import 'package:tracker_flutter/features/auth/data/client_platform.dart';
import 'package:tracker_flutter/features/auth/data/secure_token_storage.dart';
import 'package:tracker_flutter/features/auth/domain/user.dart';
import 'package:tracker_flutter/features/shell/presentation/app_shell.dart';

import '../../../helpers/fake_auth_api.dart';
import '../../../helpers/fake_secure_token_storage.dart';

const _user = User(
  id: 1,
  email: 'signed-in@example.com',
  displayName: null,
  tier: UserTier.free,
  role: UserRole.user,
);

void main() {
  Future<FakeAuthApi> pumpSignedIn(WidgetTester tester) async {
    final authApi = FakeAuthApi()
      ..refreshResult = const Result.failure(UnauthorizedFailure())
      ..loginResult = Result.success(
        AuthResult(accessToken: 'access', refreshToken: 'refresh', user: _user),
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWithValue(authApi),
          secureTokenStorageProvider.overrideWithValue(
            FakeSecureTokenStorage(),
          ),
          clientPlatformProvider.overrideWithValue(ClientPlatform.android),
        ],
        child: const MaterialApp(home: AppShell(child: SizedBox.shrink())),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
    );
    await container.read(authRepositoryProvider.notifier).startupRestoration;
    await container
        .read(authRepositoryProvider.notifier)
        .login(email: _user.email, password: 'password');
    await tester.pumpAndSettle();
    return authApi;
  }

  testWidgets('shows the Projects destination and the app title', (
    tester,
  ) async {
    await pumpSignedIn(tester);

    expect(find.text('Tracker'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
  });

  testWidgets('the account menu shows the signed-in user\'s email', (
    tester,
  ) async {
    await pumpSignedIn(tester);

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();

    expect(find.text('signed-in@example.com'), findsOneWidget);
  });

  testWidgets('sign out calls AuthRepository.logout', (tester) async {
    final authApi = await pumpSignedIn(tester);
    authApi.logoutResult = const Result.success(null);

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(authApi.logoutCalls, 1);
  });

  testWidgets('sign out everywhere calls AuthRepository.logoutAll', (
    tester,
  ) async {
    final authApi = await pumpSignedIn(tester);
    authApi.logoutAllResult = const Result.success(null);

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out everywhere'));
    await tester.pumpAndSettle();

    expect(authApi.logoutAllCalls, 1);
  });
}
