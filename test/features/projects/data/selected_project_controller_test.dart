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
import 'package:tracker_flutter/features/projects/data/project_selection_store.dart';
import 'package:tracker_flutter/features/projects/data/selected_project_controller.dart';

import '../../../helpers/fake_auth_api.dart';
import '../../../helpers/fake_project_selection_store.dart';
import '../../../helpers/fake_secure_token_storage.dart';

const _userA = User(
  id: 1,
  email: 'a@b.com',
  displayName: null,
  tier: UserTier.free,
  role: UserRole.user,
);
const _userB = User(
  id: 2,
  email: 'b@c.com',
  displayName: null,
  tier: UserTier.free,
  role: UserRole.user,
);

void main() {
  ({
    ProviderContainer container,
    FakeAuthApi authApi,
    FakeProjectSelectionStore store,
  })
  build() {
    final authApi = FakeAuthApi()
      ..refreshResult = const Result.failure(UnauthorizedFailure());
    final store = FakeProjectSelectionStore();
    final container = ProviderContainer(
      overrides: [
        authApiProvider.overrideWithValue(authApi),
        secureTokenStorageProvider.overrideWithValue(FakeSecureTokenStorage()),
        clientPlatformProvider.overrideWithValue(ClientPlatform.android),
        projectSelectionStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, authApi: authApi, store: store);
  }

  /// Signs in, then reads `selectedProjectControllerProvider` for the first
  /// time (initializing it while already authenticated, mirroring how the
  /// real widget tree only starts watching it once the shell renders) and
  /// awaits its restoration — so every test interacts with a settled
  /// controller instead of racing the background store read `select()`/
  /// `pruneIfMissing()` would otherwise run concurrently with.
  Future<void> signInAndSettle(
    ProviderContainer container,
    FakeAuthApi authApi,
    User user,
  ) async {
    authApi.loginResult = Result.success(
      AuthResult(accessToken: 'access', refreshToken: 'refresh', user: user),
    );
    await container
        .read(authRepositoryProvider.notifier)
        .login(email: user.email, password: 'password');
    await container
        .read(selectedProjectControllerProvider.notifier)
        .restoration;
  }

  test('starts at null with nobody signed in', () async {
    final built = build();
    await built.container
        .read(authRepositoryProvider.notifier)
        .startupRestoration;

    expect(built.container.read(selectedProjectControllerProvider), isNull);
  });

  test('restores a previously persisted selection once signed in', () async {
    final built = build();
    built.store.seed(_userA.id, 42);
    await built.container
        .read(authRepositoryProvider.notifier)
        .startupRestoration;

    await signInAndSettle(built.container, built.authApi, _userA);

    expect(built.container.read(selectedProjectControllerProvider), 42);
  });

  test(
    'select() updates state and persists it for the signed-in user',
    () async {
      final built = build();
      await built.container
          .read(authRepositoryProvider.notifier)
          .startupRestoration;
      await signInAndSettle(built.container, built.authApi, _userA);

      built.container
          .read(selectedProjectControllerProvider.notifier)
          .select(7);

      expect(built.container.read(selectedProjectControllerProvider), 7);
      expect(await built.store.readSelectedProjectId(_userA.id), 7);
    },
  );

  test(
    'pruneIfMissing clears a selection that is no longer available',
    () async {
      final built = build();
      await built.container
          .read(authRepositoryProvider.notifier)
          .startupRestoration;
      await signInAndSettle(built.container, built.authApi, _userA);
      built.container
          .read(selectedProjectControllerProvider.notifier)
          .select(7);

      built.container
          .read(selectedProjectControllerProvider.notifier)
          .pruneIfMissing({1, 2, 3});

      expect(built.container.read(selectedProjectControllerProvider), isNull);
      expect(await built.store.readSelectedProjectId(_userA.id), isNull);
    },
  );

  test('pruneIfMissing keeps a selection that is still available', () async {
    final built = build();
    await built.container
        .read(authRepositoryProvider.notifier)
        .startupRestoration;
    await signInAndSettle(built.container, built.authApi, _userA);
    built.container.read(selectedProjectControllerProvider.notifier).select(7);

    built.container
        .read(selectedProjectControllerProvider.notifier)
        .pruneIfMissing({7, 8});

    expect(built.container.read(selectedProjectControllerProvider), 7);
  });

  test(
    'logging out clears the selection in memory without touching storage',
    () async {
      final built = build();
      await built.container
          .read(authRepositoryProvider.notifier)
          .startupRestoration;
      await signInAndSettle(built.container, built.authApi, _userA);
      built.container
          .read(selectedProjectControllerProvider.notifier)
          .select(7);

      built.authApi.logoutResult = const Result.success(null);
      await built.container.read(authRepositoryProvider.notifier).logout();

      expect(built.container.read(selectedProjectControllerProvider), isNull);
      // The persisted value survives a mere sign-out (not a clear()) so the
      // same account sees its selection again next time it signs in.
      expect(await built.store.readSelectedProjectId(_userA.id), 7);
    },
  );

  test(
    "switching accounts never shows the previous account's selection",
    () async {
      final built = build();
      built.store.seed(_userB.id, 99);
      await built.container
          .read(authRepositoryProvider.notifier)
          .startupRestoration;
      await signInAndSettle(built.container, built.authApi, _userA);
      built.container
          .read(selectedProjectControllerProvider.notifier)
          .select(7);
      expect(built.container.read(selectedProjectControllerProvider), 7);

      built.authApi.logoutResult = const Result.success(null);
      await built.container.read(authRepositoryProvider.notifier).logout();
      // The switch happens on an already-initialized controller this time
      // (unlike signInAndSettle's first-touch case), exercising the
      // ref.listen account-change path instead of build()'s initial read.
      expect(built.container.read(selectedProjectControllerProvider), isNull);

      built.authApi.loginResult = Result.success(
        AuthResult(
          accessToken: 'access',
          refreshToken: 'refresh',
          user: _userB,
        ),
      );
      await built.container
          .read(authRepositoryProvider.notifier)
          .login(email: _userB.email, password: 'password');
      await built.container
          .read(selectedProjectControllerProvider.notifier)
          .restoration;

      expect(built.container.read(selectedProjectControllerProvider), 99);
    },
  );
}
