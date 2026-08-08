import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/error/app_failure.dart';
import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/auth/data/auth_api.dart';
import 'package:tracker_flutter/features/auth/data/auth_repository.dart';
import 'package:tracker_flutter/features/auth/data/auth_result.dart';
import 'package:tracker_flutter/features/auth/data/client_platform.dart';
import 'package:tracker_flutter/features/auth/data/secure_token_storage.dart';
import 'package:tracker_flutter/features/auth/domain/session_state.dart';
import 'package:tracker_flutter/features/auth/domain/user.dart';

import '../../../helpers/fake_auth_api.dart';
import '../../../helpers/fake_secure_token_storage.dart';

const _user = User(
  id: 1,
  email: 'a@b.com',
  displayName: null,
  tier: UserTier.free,
  role: UserRole.user,
);

void main() {
  ({
    ProviderContainer container,
    FakeAuthApi api,
    FakeSecureTokenStorage storage,
  })
  build({
    ClientPlatform platform = ClientPlatform.android,
    String? initialStoredToken,
    Result<AuthResult>? initialRefreshResult,
  }) {
    final api = FakeAuthApi()
      ..refreshResult =
          initialRefreshResult ?? const Result.failure(UnauthorizedFailure());
    final storage = FakeSecureTokenStorage(initialToken: initialStoredToken);
    final container = ProviderContainer(
      overrides: [
        authApiProvider.overrideWithValue(api),
        secureTokenStorageProvider.overrideWithValue(storage),
        clientPlatformProvider.overrideWithValue(platform),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, api: api, storage: storage);
  }

  group('startup restoration (native)', () {
    test(
      'no stored token -> unauthenticated, without calling the API',
      () async {
        final built = build();
        final notifier = built.container.read(authRepositoryProvider.notifier);

        expect(
          built.container.read(authRepositoryProvider),
          isA<SessionUnknown>(),
        );
        await notifier.startupRestoration;

        expect(
          built.container.read(authRepositoryProvider),
          isA<SessionUnauthenticated>(),
        );
        expect(built.api.refreshCalls, 0);
      },
    );

    test(
      'a stored token that refreshes successfully -> authenticated',
      () async {
        final built = build(
          initialStoredToken: 'stored-refresh-token',
          initialRefreshResult: const Result.success(
            AuthResult(
              accessToken: 'access-1',
              refreshToken: 'rotated-refresh-token',
              user: _user,
            ),
          ),
        );
        final notifier = built.container.read(authRepositoryProvider.notifier);

        await notifier.startupRestoration;

        final state = built.container.read(authRepositoryProvider);
        expect(state, isA<SessionAuthenticated>());
        expect(state.userOrNull, _user);
        expect(notifier.accessToken, 'access-1');
        expect(
          built.api.lastRefreshTokenPassedToRefresh,
          'stored-refresh-token',
        );
        // The rotated token replaces the one that was just consumed.
        expect(built.storage.storedToken, 'rotated-refresh-token');
      },
    );

    test(
      'a stored token that is rejected -> storage cleared, unauthenticated',
      () async {
        final built = build(
          initialStoredToken: 'expired-token',
          initialRefreshResult: const Result.failure(UnauthorizedFailure()),
        );
        final notifier = built.container.read(authRepositoryProvider.notifier);

        await notifier.startupRestoration;

        expect(
          built.container.read(authRepositoryProvider),
          isA<SessionUnauthenticated>(),
        );
        expect(built.storage.storedToken, isNull);
        expect(built.storage.deleteCalls, 1);
      },
    );

    test(
      'a corrupted/unreadable stored token -> unauthenticated, not a crash',
      () async {
        // FlutterSecureTokenStorage.readRefreshToken() never throws by
        // contract (corruption already degrades to null there) — simulated
        // here simply as "nothing readable", which is the exact case that
        // contract exists to guarantee.
        final built = build();
        final notifier = built.container.read(authRepositoryProvider.notifier);

        await notifier.startupRestoration;

        expect(
          built.container.read(authRepositoryProvider),
          isA<SessionUnauthenticated>(),
        );
      },
    );
  });

  group('startup restoration (web)', () {
    test(
      'a successful silent refresh (ambient cookie) -> authenticated',
      () async {
        final built = build(
          platform: ClientPlatform.web,
          initialRefreshResult: const Result.success(
            AuthResult(
              accessToken: 'access-1',
              refreshToken: null,
              user: _user,
            ),
          ),
        );
        final notifier = built.container.read(authRepositoryProvider.notifier);

        await notifier.startupRestoration;

        expect(
          built.container.read(authRepositoryProvider),
          isA<SessionAuthenticated>(),
        );
        expect(built.api.lastRefreshTokenPassedToRefresh, isNull);
        // Nothing is ever persisted on web.
        expect(built.storage.writeCalls, 0);
      },
    );

    test('no cookie / refresh rejected -> unauthenticated', () async {
      final built = build(
        platform: ClientPlatform.web,
        initialRefreshResult: const Result.failure(UnauthorizedFailure()),
      );
      final notifier = built.container.read(authRepositoryProvider.notifier);

      await notifier.startupRestoration;

      expect(
        built.container.read(authRepositoryProvider),
        isA<SessionUnauthenticated>(),
      );
    });
  });

  group('login', () {
    test('success authenticates and returns the user', () async {
      final built = build();
      await built.container
          .read(authRepositoryProvider.notifier)
          .startupRestoration;
      built.api.loginResult = const Result.success(
        AuthResult(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
          user: _user,
        ),
      );

      final result = await built.container
          .read(authRepositoryProvider.notifier)
          .login(email: 'a@b.com', password: 'correct-horse');

      expect(result, isA<Success<User>>());
      expect(
        built.container.read(authRepositoryProvider),
        isA<SessionAuthenticated>(),
      );
      expect(built.storage.storedToken, 'refresh-1');
    });

    test('failure stays unauthenticated and returns the failure', () async {
      final built = build();
      await built.container
          .read(authRepositoryProvider.notifier)
          .startupRestoration;
      built.api.loginResult = const Result.failure(
        ValidationFailure(message: 'Invalid email or password.'),
      );

      final result = await built.container
          .read(authRepositoryProvider.notifier)
          .login(email: 'a@b.com', password: 'wrong');

      expect(result.isFailure, isTrue);
      expect(
        built.container.read(authRepositoryProvider),
        isA<SessionUnauthenticated>(),
      );
    });
  });

  group('register', () {
    test('success authenticates and returns the user', () async {
      final built = build();
      await built.container
          .read(authRepositoryProvider.notifier)
          .startupRestoration;
      built.api.registerResult = const Result.success(
        AuthResult(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
          user: _user,
        ),
      );

      final result = await built.container
          .read(authRepositoryProvider.notifier)
          .register(email: 'a@b.com', password: 'correct-horse-battery');

      expect(result, isA<Success<User>>());
      expect(built.api.registerCalls, 1);
    });
  });

  group('refreshAccessToken (AuthSession contract)', () {
    test(
      'success updates the access token and persists the rotated refresh token',
      () async {
        final built = build(
          initialStoredToken: 'old-token',
          initialRefreshResult: const Result.success(
            AuthResult(
              accessToken: 'first-access',
              refreshToken: 'old-token',
              user: _user,
            ),
          ),
        );
        final notifier = built.container.read(authRepositoryProvider.notifier);
        await notifier.startupRestoration;

        built.api.refreshResult = const Result.success(
          AuthResult(
            accessToken: 'second-access',
            refreshToken: 'new-token',
            user: _user,
          ),
        );
        final newToken = await notifier.refreshAccessToken();

        expect(newToken, 'second-access');
        expect(notifier.accessToken, 'second-access');
        expect(built.storage.storedToken, 'new-token');
      },
    );

    test('failure returns null without itself signing out', () async {
      final built = build(
        initialStoredToken: 'old-token',
        initialRefreshResult: const Result.success(
          AuthResult(
            accessToken: 'first-access',
            refreshToken: 'old-token',
            user: _user,
          ),
        ),
      );
      final notifier = built.container.read(authRepositoryProvider.notifier);
      await notifier.startupRestoration;

      built.api.refreshResult = const Result.failure(UnauthorizedFailure());
      final newToken = await notifier.refreshAccessToken();

      expect(newToken, isNull);
      // Signing out is RefreshInterceptor's job (it calls forceSignOut()
      // itself) — this method only reports failure.
      expect(
        built.container.read(authRepositoryProvider),
        isNot(isA<SessionUnauthenticated>()),
      );
    });

    test('on web, never reads/writes storage', () async {
      final built = build(
        platform: ClientPlatform.web,
        initialRefreshResult: const Result.success(
          AuthResult(
            accessToken: 'first-access',
            refreshToken: null,
            user: _user,
          ),
        ),
      );
      final notifier = built.container.read(authRepositoryProvider.notifier);
      await notifier.startupRestoration;

      await notifier.refreshAccessToken();

      expect(built.storage.writeCalls, 0);
    });
  });

  group('forceSignOut', () {
    test(
      'clears the access token, deletes stored credentials, and signs out',
      () async {
        final built = build(
          initialStoredToken: 'old-token',
          initialRefreshResult: const Result.success(
            AuthResult(
              accessToken: 'access-1',
              refreshToken: 'old-token',
              user: _user,
            ),
          ),
        );
        final notifier = built.container.read(authRepositoryProvider.notifier);
        await notifier.startupRestoration;
        expect(notifier.accessToken, isNotNull);

        await notifier.forceSignOut();

        expect(notifier.accessToken, isNull);
        expect(built.storage.storedToken, isNull);
        expect(
          built.container.read(authRepositoryProvider),
          isA<SessionUnauthenticated>(),
        );
      },
    );
  });

  group('logout / logoutAll', () {
    test('logout signs out locally even when the revoke call fails', () async {
      final built = build(
        initialStoredToken: 'old-token',
        initialRefreshResult: const Result.success(
          AuthResult(
            accessToken: 'access-1',
            refreshToken: 'old-token',
            user: _user,
          ),
        ),
      );
      final notifier = built.container.read(authRepositoryProvider.notifier);
      await notifier.startupRestoration;
      built.api.logoutResult = const Result.failure(OfflineFailure());

      await notifier.logout();

      expect(
        built.container.read(authRepositoryProvider),
        isA<SessionUnauthenticated>(),
      );
      expect(built.api.logoutCalls, 1);
      expect(built.api.lastRefreshTokenPassedToLogout, 'old-token');
    });

    test(
      'logoutAll signs out locally even when the revoke call fails',
      () async {
        final built = build(
          initialStoredToken: 'old-token',
          initialRefreshResult: const Result.success(
            AuthResult(
              accessToken: 'access-1',
              refreshToken: 'old-token',
              user: _user,
            ),
          ),
        );
        final notifier = built.container.read(authRepositoryProvider.notifier);
        await notifier.startupRestoration;
        built.api.logoutAllResult = const Result.failure(OfflineFailure());

        await notifier.logoutAll();

        expect(
          built.container.read(authRepositoryProvider),
          isA<SessionUnauthenticated>(),
        );
        expect(built.api.logoutAllCalls, 1);
      },
    );
  });
}
