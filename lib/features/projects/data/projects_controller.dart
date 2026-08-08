import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/project.dart';
import 'projects_repository.dart';

/// Loads one authenticated user's projects and exposes them as an
/// [AsyncValue], so `ProjectsScreen` renders loading/data/error through the
/// shared `AsyncStateView` like every other feature will.
///
/// [userId] is intentionally part of the provider identity even though the
/// backend derives ownership from the bearer token. This prevents one
/// account's cached project list from ever being reused by another account
/// after logout/account switch on the same device.
///
/// A failed load surfaces as an [AsyncError] carrying the original
/// `AppFailure` (thrown, not swallowed) rather than an empty list, so the UI
/// can distinguish "no projects" from "couldn't load projects".
class ProjectsController extends AsyncNotifier<List<Project>> {
  ProjectsController(this.userId);

  final int userId;
  int _requestId = 0;

  @override
  Future<List<Project>> build() => _load();

  Future<List<Project>> _load() async {
    final repository = ref.watch(projectsRepositoryProvider);
    final result = await repository.fetchProjects();
    return result.when(
      success: (projects) => projects,
      failure: (f) => throw f,
    );
  }

  /// Re-fetches. Used by both pull-to-refresh and the error state's retry
  /// action.
  ///
  /// When a previous list is already showing, this deliberately leaves it
  /// on screen while the new request is in flight instead of switching to
  /// [AsyncLoading] — the caller (`RefreshIndicator`, or a retry button)
  /// already renders its own loading affordance, and swapping the whole
  /// list out from under it would just flash content away and back.
  ///
  /// Guarded against out-of-order responses: if two calls overlap (e.g. a
  /// quick double-tap on retry), only the most recently issued call is
  /// allowed to write [state] — an earlier, slower response arriving last
  /// must not silently overwrite a newer one.
  Future<void> refresh() async {
    final requestId = ++_requestId;
    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }
    final result = await AsyncValue.guard(_load);
    if (requestId == _requestId) {
      state = result;
    }
  }
}

final projectsControllerProvider =
    AsyncNotifierProvider.family.autoDispose<
      ProjectsController,
      List<Project>,
      int
    >(
      ProjectsController.new,
      // ProjectsController.build()/refresh() throw AppFailure for
      // ordinary, expected outcomes (offline, 401, 5xx) — not unexpected
      // crashes. Riverpod's default retry policy
      // (ProviderContainer.defaultRetry) treats any thrown non-Error as
      // transient and silently retries up to 10 times over ~40s before an
      // AsyncError ever reaches the UI; that's the wrong behavior for a
      // failure this repository already classified, so retry is disabled
      // here and left to the explicit `refresh()` action instead.
      retry: (retryCount, error) => null,
    );
