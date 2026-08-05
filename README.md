# Tracker-Flutter

Cross-platform Flutter client for [`Tracker-BE`](https://github.com/MrH3lmy/Tracker-BE), the existing Spring Boot API. The React client stays in place; this app is built up feature-by-feature until it reaches parity, starting with an Android internal release.

Targets: Android, iOS, Web, Windows, macOS, Linux.

## Status

This repository currently contains the **bootstrap foundation** ([#1][epic1]): project scaffolding, architecture, DI, routing, theming, environment configuration, and CI. It intentionally does not yet include:

- A real networking layer with auth/refresh/pagination — [#2][epic2]
- Authentication and secure session storage — [#3][epic3]
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
    di/            # Riverpod providers wiring config/logging into the app
    error/         # AppFailure — the shared failure taxonomy
    result/        # Result<T> — the shared success/failure return type
    logging/       # AppLogger — redacts credentials before anything is logged
    router/        # GoRouter setup, route guard choke point, session status
    theme/         # design tokens + light/dark ThemeData
    utils/         # breakpoints and other small shared helpers
    widgets/       # AdaptiveScaffold, AsyncStateView (loading/empty/error/data)
  features/
    shell/         # authenticated app shell (adaptive navigation chrome)
    home/          # placeholder screen demonstrating the provider -> AsyncStateView pattern
    not_found/     # unknown-route screen
  src/app.dart     # MaterialApp.router wiring theme + router together
  bootstrap.dart   # shared startup: error handling, logging init, ProviderScope
  main*.dart       # one thin entry point per environment
```

**State management & DI**: Riverpod. Providers are colocated with the feature that owns them; cross-cutting providers (config, logging) live in `core/di`.

**Routing**: GoRouter, with a single `redirect` choke point in `core/router/app_router.dart` that every navigation passes through. `core/router/session_status.dart` is a placeholder — the [authentication epic][epic3] replaces it with a real session state machine without needing further router changes. Unmatched routes render `NotFoundScreen` via `errorBuilder`.

**Errors**: data sources return `Result<T>` (`core/result/result.dart`) instead of throwing; failures are one of the `AppFailure` subtypes (`core/error/app_failure.dart`) — network, timeout, offline, unauthorized, validation, conflict, rate-limited, server, cancelled, unknown. `AsyncStateView` (`core/widgets/async_state_view.dart`) renders the loading/empty/error/data states for any `AsyncValue<T>` consistently, including dedicated offline and unauthorized presentations.

**Responsive layout**: `AppBreakpoint` (`core/utils/breakpoints.dart`) classifies available width as compact/medium/expanded; `AdaptiveScaffold` swaps a bottom nav bar for a navigation rail (unlabeled, then extended) accordingly rather than stretching a phone layout to desktop.

**Logging**: `AppLogger` wraps `package:logging` and redacts passwords, tokens, cookies, and authorization headers before anything reaches a sink — verified by `test/core/logging/app_logger_test.dart`.

## Testing

- `test/core/**` — unit tests for `Result`, `AppConfig`, `AppLogger` redaction, breakpoints.
- `test/widget/**` — widget tests for `AdaptiveScaffold` and an app-level smoke test (launch → home screen; unknown route → not-found screen).
- `integration_test/app_test.dart` — end-to-end launch smoke test; feature epics add their own flows here (e.g. login → select project → browse tasks) rather than replacing it.

## Contributing

1. Branch from `main`.
2. Keep features under `lib/features/<feature>/` with `data/`, `domain/`, `presentation/` subfolders as they grow; only depend on `lib/core`, not on other features.
3. Run `flutter analyze`, `dart format`, and `flutter test` before opening a PR — CI enforces all three plus Android/Web build validation.
4. Never commit secrets or real backend URLs; use `--dart-define` and document new keys in this README.
