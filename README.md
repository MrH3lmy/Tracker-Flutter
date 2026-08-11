# Tracker-Flutter

Cross-platform Flutter client for [`Tracker-BE`](https://github.com/MrH3lmy/Tracker-BE), the existing Spring Boot API. The React client stays in place; this app is built up feature-by-feature until it reaches parity, starting with an Android internal release.

Targets: Android, iOS, Web, Windows, macOS, Linux.

## Status

This repository currently contains:

- The **bootstrap foundation** ([#1][epic1] — closed): project scaffolding, architecture, DI, routing, theming, environment configuration, and CI.
- The **authenticated API and networking layer** ([#2][epic2] — closed): a `Dio`-based `ApiClient`, single-flight token refresh, retry/backoff, pagination-header parsing, connectivity-aware offline detection, and credential-redacting logging.
- **Real authentication and secure session storage** ([#3][epic3] — closed): login/registration, an explicit session state machine, OS-backed secure refresh-token storage on native platforms, cookie-based sessions on web, startup session restoration, and logout/logout-all. See [Authentication](#authentication) below.
- **The first functional release** ([#4][epic4], in progress — shipped as a sequence of vertical slices, not one PR):
  - Slice 1: the authenticated shell and a Projects list (load, select, refresh, safe selection state). See [Projects](#projects) below.
  - Slice 2: the user's global board-column layout (load, refresh). See [Board columns](#board-columns) below — note this is **not** project-scoped; see that section for why.
  - Slice 3: bounded active-task pagination plus task details, optionally filtered by the selected project. See [Tasks](#tasks) below.
  - Slice 4: task creation and editing with backend-aligned validation, duplicate-submit protection, and safe selected-project assignment. See [Tasks](#tasks) below.

It intentionally does not yet include task lifecycle/archive actions, notes, attachments, or settings — those are later slices of the same epic.

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
    projects/      # project list + selection — see Projects below
    board_columns/ # the user's global Kanban layout — see Board columns below
    tasks/         # bounded task browse/detail/create/edit — see Tasks below
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
- `interceptors/retry_interceptor.dart` retries only timeouts/`5xx`/`429`, and only when a request is idempotent (GET/HEAD by default) or explicitly marked retryable via `RequestPolicy` — a flaky network can't turn one write into two.
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

## Projects

`features/projects/` is epic #4's first vertical slice: an authenticated shell that loads and lets the user select from their projects, against Tracker-BE's `GET /api/v1/projects` (`ProjectController`/`ProjectService`). That endpoint returns a plain JSON array scoped server-side to the authenticated user — no pagination, no ordering guarantee, and archived projects are included — so this slice doesn't invent any of those on the client side either (see `ProjectsRepository`'s doc comment).

- `domain/project.dart` — `Project` mirrors `ProjectResponse` field-for-field. `ProjectStatus`/`ProjectArea` parsing degrades gracefully for a status/area value this build doesn't recognize yet (`ProjectStatus.unknown` / a `null` area) instead of failing the whole list over one forward-compatible field.
- `data/projects_repository.dart` — `ProjectsRepository` wraps `ApiClient`; `fetchProjects()` returns `Result<List<Project>>`.
- `data/projects_controller.dart` — `ProjectsController` (`AsyncNotifier<List<Project>>`) loads the list and exposes `refresh()` for pull-to-refresh/retry, which leaves the previous list on screen while re-fetching rather than flashing back to a loading state. Its provider disables Riverpod's default build-retry (`retry: (retryCount, error) => null`) — an `AppFailure` here is an already-classified, expected outcome (offline, 401, 5xx), not a crash that should be silently retried for up to ~40 seconds before ever reaching the UI.
- `data/project_selection_store.dart` — `ProjectSelectionStore` persists the selected-project id in ordinary (non-encrypted) local preferences via `shared_preferences`, namespaced per user id. This is a UI convenience, never a credential — refresh tokens stay exclusively in `SecureTokenStorage`. Reads never throw, mirroring that type's contract.
- `data/selected_project_controller.dart` — `SelectedProjectController` restores the persisted selection once the signed-in user is known, clears it in memory the instant the user id changes (logout/account switch — never a stale frame of the previous account's selection), and exposes `pruneIfMissing()` so a selection that no longer resolves (deletion, lost access, a stale id from a previous session) is dropped once the live project list is known.
- `presentation/projects_screen.dart` — loading/empty/error/retry via the shared `AsyncStateView`, pull-to-refresh, and project selection with a confirmation snackbar.

`features/shell/presentation/app_shell.dart` hosts the account menu (sign out / sign out everywhere) so it stays available regardless of which destination is active, rather than living on an individual screen.

## Board columns

`features/board_columns/` is epic #4's second vertical slice: the authenticated user's Kanban column layout, against Tracker-BE's `GET /api/v1/board-columns` (`BoardController`).

**This is deliberately not project-scoped**, even though the epic roadmap's original wording talked about "boards for the selected project." Tracker-BE's actual model, verified directly against its source rather than assumed: it provisions exactly **one** board per user at registration (`BoardProvisioningService`), with **no REST resource for the board itself** — no list/get/select-board endpoint exists anywhere. The `Board` entity has no `projectId`; `BoardColumn` rows belong to that single per-user board, also with no project linkage. Tasks (`Task.projectId` and `Task.boardColumnId`) are the only place a project and a column ever meet, and those are two independent foreign keys on the same row — a task can sit in a project *and* in a column, but the column/board itself isn't scoped to any project. It's one flat, cross-project Kanban layout per user. This slice does not invent project-scoped boards, board selection, or a `selectedBoardProvider` to paper over that — see the PR that introduced this section for the full investigation.

The endpoint is not paginated and Tracker-BE already orders the response by `position` ascending (`findAllByUserIdOrderByPositionAsc`).

- `domain/board_column.dart` — `BoardColumn` mirrors `BoardColumnResponse` field-for-field (`id`, `name`, `status`, `position`) — no `boardId`, on purpose. `ColumnStatus` parsing degrades to `ColumnStatus.unknown` for a status value this build doesn't recognize yet, same forward-compatibility approach as `ProjectStatus`.
- `data/board_columns_repository.dart` — `BoardColumnsRepository` wraps `ApiClient`; re-asserts the backend's `position` ordering defensively rather than trusting wire order to survive unchanged, but invents no ordering of its own.
- `data/board_columns_controller.dart` — `BoardColumnsController` (`AsyncNotifier<List<BoardColumn>>.family.autoDispose`, keyed by user id) mirrors `ProjectsController`'s pattern exactly: retry disabled for the same reason, `refresh()` keeps the previous list visible while re-fetching, and guards against an older in-flight `refresh()` clobbering a newer one. `.autoDispose` plus the user-id key means one account's cached column list can never leak to another after logout/account switch — a new user id is a different provider instance, and the old one is disposed once nothing references it.
- `presentation/board_screen.dart` — a horizontally-scrolling Kanban layout (one card per column) inside a pull-to-refresh `RefreshIndicator`, with loading/empty/offline/unauthorized/error/retry via the shared `AsyncStateView`. Task cards are intentionally still a placeholder: composing the independent `board_columns` and `tasks` features should happen through an explicit composition boundary rather than making either feature import the other.

Selecting a different project elsewhere in the app has **no effect** on this screen — `BoardScreen` never reads `selectedProjectControllerProvider` — which is asserted directly in both `board_screen_test.dart` and `test/integration/app_flow_test.dart`.

## Tasks

`features/tasks/` is epic #4's third and fourth vertical slices: bounded active-task browsing and task details, followed by task creation and editing against Tracker-BE's real write contracts.

Tracker-BE returns task pages as a plain JSON array and places page metadata in `X-Total-Count`, `X-Total-Pages`, `X-Page`, `X-Page-Size`, and `X-Has-Next`. The backend caps page size and applies a deterministic `(position, id)` ordering. This client deliberately uses `ApiClient.getPaginated`; there is no task-specific "load everything" compatibility path.

- `domain/task.dart` — `Task` mirrors the backend `TaskResponse` used by both list and detail endpoints, including scheduling, priority, hierarchy, dependency/subtask, and recurrence metadata. Enum parsing degrades to explicit unknown cases where appropriate so one newly introduced backend enum does not make the whole task unreadable. Recurrence preserves the backend's raw frequency value when necessary so a safe edit can round-trip recurrence data it does not otherwise modify.
- `domain/task_write_input.dart` — maps the editable task state onto the backend's full create/update request shape while deliberately preserving fields this first form does not edit, including actual time, parent task, recurrence, board placement when status is unchanged, and existing dependencies.
- `data/tasks_repository.dart` — `TasksRepository` requests one bounded page at a time. The first-release task list sends only active statuses (`BACKLOG`, `NOT_STARTED`, `IN_PROGRESS`, `WAITING`, `BLOCKED`), leaving `DONE`/`CANCELLED` for the later archive/lifecycle slice. When a project is selected, `projectId` is sent to the backend rather than filtering an already-downloaded global list on the device. Writes use `POST /api/v1/tasks` and `PUT /api/v1/tasks/{id}`. Because Tracker-BE's create request has no `projectId`, a successful create is followed by `PATCH /api/v1/tasks/{id}/project` when a project is selected; a failure in that second call is surfaced as a warning without pretending the original POST failed.
- `data/tasks_controller.dart` — `TaskListController` is keyed by `(userId, projectId)`, loads 50 tasks per page, supports pull-to-refresh plus explicit load-more, de-duplicates by task id across page boundaries, and keeps already loaded tasks visible when a later page fails. `TaskDetailController` loads and retries one task by id. Both disable Riverpod's automatic retry because transport failures are already classified and rendered explicitly.
- `data/task_write_controller.dart` — serializes create/update submissions so repeated taps cannot duplicate a write, invalidates the affected all-tasks/project task-list caches after success, updates the active detail state after edits, and keeps project-assignment failure separate from task-creation failure.
- `presentation/tasks_screen.dart` — shows all active tasks when no project is selected, or the selected project's active tasks when there is one. The UI always shows loaded-vs-total counts and an explicit load-more action when `X-Has-Next` is true, and exposes a **New task** action.
- `presentation/task_detail_screen.dart` — renders the task itself and exposes **Edit task** for active tasks without pulling notes, screenshots, or attachments into this slice; those belong to their later feature slices.
- `presentation/task_form_screen.dart` — provides create/edit forms with local validation aligned to Tracker-BE for title length, non-negative estimates, date ordering, elevated-risk reasons, blocked-task reasons, and waiting/follow-up requirements. Recurrence is preserved on edit but intentionally not edited yet.
- `presentation/task_edit_screen.dart` — refuses to silently coerce terminal or unknown-status tasks back into an active status; those edits wait for the lifecycle/archive slice.

The authenticated shell exposes `/tasks`, `/tasks/new`, `/tasks/:id`, and `/tasks/:id/edit`. Project-to-task composition stays in the shell so the `tasks` feature does not import the `projects` feature directly.

## Testing

- `test/core/**` — unit tests for `Result`, `AppConfig`, `AppLogger` redaction, breakpoints, and the full networking layer (mapper, pagination parsing, request policy, connectivity classification, and each interceptor's behavior against a fake `HttpClientAdapter` — including concurrent-401 single-flight refresh and non-idempotent no-auto-retry).
- `test/features/**` — per-feature unit/widget tests following the `data`/`domain`/`presentation` split (auth, projects, board_columns, tasks), including task write payloads, selected-project assignment, duplicate-submit protection, form validation, and create/edit navigation.
- `test/widget/**` — widget tests for `AdaptiveScaffold` and an app-level smoke test (launch → authenticated shell; unknown route → not-found screen).
- `test/integration/app_flow_test.dart` — a widget-test-level run of launch → sign in → authenticated shell → load/select project → open Board/load global columns → open the selected project's bounded Tasks list → open task details → edit the task → return to the list → create a task in the selected project. Every provider and screen is real except the network repositories, which are faked because no live Tracker-BE is reachable from a widget test.
- `integration_test/app_test.dart` — true device/backend end-to-end launch smoke test; feature epics continue extending the widget-level flow while device/backend coverage grows alongside release slices.

## Contributing

1. Branch from `main`.
2. Keep features under `lib/features/<feature>/` with `data/`, `domain/`, `presentation/` subfolders as they grow; only depend on `lib/core`, not on other features.
3. Run `flutter analyze`, `dart format`, and `flutter test` before opening a PR — CI enforces all three plus Android/Web build validation.
4. Never commit secrets or real backend URLs; use `--dart-define` and document new keys in this README.
