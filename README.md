# Tracker-Flutter

Cross-platform Flutter client for [`Tracker-BE`](https://github.com/MrH3lmy/Tracker-BE), the existing Spring Boot API. The React client stays in place; this app is built up feature-by-feature until it reaches parity, starting with an Android internal release.

Targets: Android, iOS, Web, Windows, macOS, Linux.

## Status

This repository currently contains:

- The **bootstrap foundation** ([#1][epic1] — closed): project scaffolding, architecture, DI, routing, theming, environment configuration, and CI.
- The **authenticated API and networking layer** ([#2][epic2] — closed): a `Dio`-based `ApiClient`, single-flight token refresh, retry/backoff, pagination-header parsing, connectivity-aware offline detection, and credential-redacting logging.
- **Real authentication and secure session storage** ([#3][epic3]): login/registration, an explicit session state machine, OS-backed secure refresh-token storage on native platforms, cookie-based sessions on web, startup session restoration, and logout/logout-all. See [Authentication](#authentication) below.

It intentionally does not yet include:

- Business features (projects, boards, tasks, notes, attachments, settings) — [#4][epic4]

Those are tracked as separate epics that build on this foundation.

[epic1]: https://github.com/MrH3lmy/Tracker-Flutter/issues/1
[epic2]: https://github.com/MrH3lmy/Tracker-Flutter/issues/2
[epic3]: https://github.com/MrH3lmy/Tracker-Flutter/issues/3
[epic4]: https://github.com/MrH3lmy/Tracker-Flutter/issues/4

## Setup

Requires Flutter **3.44.8** (stable channel) or newer.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates *.freezed.dart / *.g.dart
```

## Running

There is a `main_*.dart` entry point per environment; each resolves its config from `--dart-define` values only, so no secrets or backend URLs are committed to source control.

```bash
flutter run -t lib/main.dart                      # local (defaults to http://localhost:8080)
flutter run -t lib/main_development.dart --dart-define=API_BASE_URL=https://dev.api.example.com
flutter run -t lib/main_staging.dart --dart-define=API_BASE_URL=https://staging.api.example.com
flutter run -t lib/main_production.dart --dart-define=API_BASE_URL=https://api.example.com
```

## Common commands

```bash
flutter analyze                                     # static analysis
dart format lib test integration_test                # format
flutter test --coverage                              # unit + widget tests
flutter test integration_test                         # integration tests (needs a device/emulator)
dart run build_runner watch --delete-conflicting-outputs  # codegen in watch mode
```

CI (`.github/workflows/ci.yml`) runs format checking, codegen, analysis, tests, and Android/Web build validation on every push and pull request.

## Architecture

Feature-first structure — each feature owns its own data/domain/presentation code and depends only on `lib/core`, never on another feature directly.

```
lib/
  core/            # cross-cutting foundations, shared by every feature
    config/        # AppEnvironment, AppConfig (--dart-define based, no secrets)
    di/            # Riverpod providers wiring config/logging/network into the app
    error/         # AppFailure — the shared failure taxonomy
    result/        # Result<T> — the shared success/failure return type
    logging/       # AppLogger — redacts credentials before anything is logged
    router/        # GoRouter setup, route guard choke point, session status
    theme/         # design tokens + light/dark ThemeData
    utils/         # breakpoints and other small shared helpers
    widgets/       # AdaptiveScaffold, AsyncStateView (loading/empty/error/data)
    network/       # ApiClient, interceptors, pagination, connectivity (see below)
  features/
    auth/          # login/register/session — see Authentication below
    shell/         # authenticated app shell (adaptive navigation chrome)
    home/          # placeholder screen demonstrating the provider -> AsyncStateView pattern
    not_found/     # unknown-route screen
  src/app.dart     # MaterialApp.router wiring theme + router together
  bootstrap.dart   # shared startup: error handling, logging init, ProviderScope
  main*.dart       # one thin entry point per environment
```

**State management & DI**: Riverpod. Providers are colocated with the feature that owns them; cross-cutting providers (config, logging) live in `core/di`.

**Routing**: GoRouter, with a single `redirect` choke point in `core/router/app_router.dart` that every navigation passes through. `core/router/session_status.dart` derives a router-facing `SessionStatus` (`unknown` / `authenticated` / `unauthenticated`) from the real session state in `features/auth`; the redirect holds the app on the splash route while the session is `unknown` (startup restoration in flight), sends unauthenticated users to sign-in, and bounces authenticated users away from sign-in/register. Unmatched routes render `NotFoundScreen` via `errorBuilder`.

**Errors**: data sources return `Result<T>` (`core/result/result.dart`) instead of throwing; failures are one of the `AppFailure` subtypes (`core/error/app_failure.dart`) — network, timeout, offline, unauthorized, validation, conflict, rate-limited, server, cancelled, unknown. `AsyncStateView` (`core/widgets/async_state_view.dart`) renders the loading/empty/error/data states for any `AsyncValue<T>` consistently, including dedicated offline and unauthorized presentations.

**Responsive layout**: `AppBreakpoint` (`core/utils/breakpoints.dart`) classifies available width as compact/medium/expanded; `AdaptiveScaffold` swaps a bottom nav bar for a navigation rail (unlabeled, then extended) accordingly rather than stretching a phone layout to desktop.

**Logging**: `AppLogger` wraps `package:logging` and redacts passwords, tokens, cookies, and authorization headers before anything reaches a sink — verified by `test/core/logging/app_logger_test.dart`.

**Networking** (`core/network/`): feature repositories depend on `ApiClient` (`api_client.dart`), never on `Dio` directly. Every method returns `Result<T>` — nothing throws.

- `interceptors/auth_header_interceptor.dart` injects the bearer token from `AuthSession` unless a request opts out with `RequestPolicy(skipAuth: true)`.
- `interceptors/refresh_interceptor.dart` coalesces concurrent `401`s into one `AuthSession.refreshAccessToken()` call, replays the waiting requests exactly once each, and calls `forceSignOut()` when refresh can't recover the session. See its doc comment for the concurrency/loop-prevention argument.
- `interceptors/retry_interceptor.dart` retries only timeouts/`5xx`/`429`, and only when the request is idempotent (GET/HEAD by default) or explicitly marked `RequestPolicy(retryable: true)` — a flaky network can't turn one write into two.
- `interceptors/redacting_log_interceptor.dart` logs through `AppLogger`; bodies are only logged outside production, and `FormData` is always summarized by field name, never by content.
- `pagination/page_meta.dart` parses Tracker-BE's `X-Total-Count` / `X-Total-Pages` / `X-Page` / `X-Page-Size` / `X-Has-Next` headers into `PageMeta`; `ApiClient.getPaginated` returns a `PaginatedResult<T>` — there is no "load everything" path.
- `connectivity/connectivity_service.dart` reports network *presence*, not reachability; `ApiClient` uses it only to tell `OfflineFailure` (no interface at all) apart from `NetworkFailure` (an interface is up but the server didn't respond).
- `errors/dio_failure_mapper.dart` maps every `DioException` onto `AppFailure` — features never see `DioException`.
- `auth/auth_session.dart` defines the `AuthSession` interface (`accessToken`, `refreshAccessToken()`, `forceSignOut()`) that the interceptors depend on; `features/auth/data/auth_repository.dart`'s `AuthRepository` is the real implementation, bound in `lib/bootstrap.dart`.

## Authentication

`features/auth/` implements Tracker-BE's dual authentication contract (native JSON refresh tokens for Flutter clients, HttpOnly cookies for browsers) against a single `AuthRepository`.

- `domain/session_state.dart` — a sealed `SessionState` models the session as exactly one of `unknown` (startup restoration in flight), `authenticated(user)`, `unauthenticated`, `refreshing(previousUser)`, or `unrecoverable` (secure storage is broken and cannot be trusted). `core/router/session_status.dart` derives the router's 3-state view from this.
- `data/client_platform.dart` — resolves the running `ClientPlatform` (`web`/`android`/`ios`/`windows`/`macos`/`linux`) from `kIsWeb` and `defaultTargetPlatform`. Web always uses the cookie-based contract; every native target uses the token-based one.
- `data/secure_token_storage.dart` — `SecureTokenStorage` is the refresh-token persistence seam. `FlutterSecureTokenStorage` wraps `flutter_secure_storage` (Keychain / Keystore / DPAPI) on native platforms; `NoopTokenStorage` is bound on web, since a refresh token must never be reachable from JavaScript — the browser session lives entirely in the HttpOnly cookie Tracker-BE sets. `readRefreshToken()`/`deleteRefreshToken()` are documented to never throw: a corrupted keystore degrades to "no token found," not a crash.
- `data/auth_api.dart` — talks to Tracker-BE's `/api/v1/auth/**` routes, switching between the native (`/auth/native/*`, JSON refresh token in the body) and web (`/auth/*`, cookie, `withCredentials`) routes based on `ClientPlatform`.
- `data/auth_repository.dart` — `AuthRepository` (a `Notifier<SessionState>`) implements `AuthSession` and is the single source of truth for the session: startup restoration (reads the stored refresh token on native, or attempts a silent cookie-based refresh on web), `login`/`register`, `refreshAccessToken()` (used by `RefreshInterceptor`'s single-flight refresh — on failure it reports `null` and leaves sign-out to the interceptor, avoiding duplicate state transitions), `forceSignOut()`, and `logout`/`logoutAll` (always clear local session state even if the server-side revoke call fails, since a client that can't reach the network must still be able to sign out). The access token lives in memory only and is never persisted.
- `presentation/` — `SplashScreen` (shown during `unknown`), `SignInScreen`, `RegisterScreen`.

Session restoration runs once at startup (`AuthRepository.build()`); routes are held on the splash screen via the router redirect until it resolves, so no protected screen can flash before the session is known.

## Testing

- `test/core/**` — unit tests for `Result`, `AppConfig`, `AppLogger` redaction, breakpoints, and the full networking layer (mapper, pagination parsing, request policy, connectivity classification, and each interceptor's behavior against a fake `HttpClientAdapter` — including concurrent-401 single-flight refresh and non-idempotent no-auto-retry).
- `test/widget/**` — widget tests for `AdaptiveScaffold` and an app-level smoke test (launch → home screen; unknown route → not-found screen).
- `integration_test/app_test.dart` — end-to-end launch smoke test; feature epics add their own flows here (e.g. login → select project → browse tasks) rather than replacing it.

## Contributing

1. Branch from `main`.
2. Keep features under `lib/features/<feature>/` with `data/`, `domain/`, `presentation/` subfolders as they grow; only depend on `lib/core`, not on other features.
3. Run `flutter analyze`, `dart format`, and `flutter test` before opening a PR — CI enforces all three plus Android/Web build validation.
4. Never commit secrets or real backend URLs; use `--dart-define` and document new keys in this README.
