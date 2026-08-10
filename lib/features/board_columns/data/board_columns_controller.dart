import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/board_column.dart';
import 'board_columns_repository.dart';

/// Loads one authenticated user's global board-column layout and exposes it
/// as an [AsyncValue], so `BoardScreen` renders loading/data/error through
/// the shared `AsyncStateView` like every other feature does.
///
/// [userId] is intentionally part of the provider identity even though the
/// backend derives ownership from the bearer token — this mirrors
/// `ProjectsController`'s pattern (see its doc comment) and, combined with
/// `.autoDispose`, guarantees one account's cached column list can never be
/// reused by another account after logout/account switch on the same
/// device: a new [userId] is a different provider instance entirely, and
/// the old one is disposed once nothing references it anymore.
///
/// A failed load surfaces as an [AsyncError] carrying the original
/// `AppFailure` (thrown, not swallowed) rather than an empty list, so the UI
/// can distinguish "no columns" from "couldn't load columns".
class BoardColumnsController extends AsyncNotifier<List<BoardColumn>> {
  BoardColumnsController(this.userId);

  final int userId;
  int _requestId = 0;

  @override
  Future<List<BoardColumn>> build() => _load();

  Future<List<BoardColumn>> _load() async {
    final repository = ref.watch(boardColumnsRepositoryProvider);
    final result = await repository.fetchColumns();
    return result.when(success: (columns) => columns, failure: (f) => throw f);
  }

  /// Re-fetches. Used by both pull-to-refresh and the error state's retry
  /// action.
  ///
  /// When a previous list is already showing, this deliberately leaves it
  /// on screen while the new request is in flight instead of switching to
  /// [AsyncLoading] — the caller (`RefreshIndicator`, or a retry button)
  /// already renders its own loading affordance.
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

final boardColumnsControllerProvider = AsyncNotifierProvider.family
    .autoDispose<BoardColumnsController, List<BoardColumn>, int>(
      BoardColumnsController.new,
      // BoardColumnsController.build()/refresh() throw AppFailure for
      // ordinary, expected outcomes (offline, 401, 5xx) — not unexpected
      // crashes. Riverpod's default retry policy
      // (ProviderContainer.defaultRetry) treats any thrown non-Error as
      // transient and silently retries up to 10 times over ~40s before an
      // AsyncError ever reaches the UI; that's the wrong behavior for a
      // failure this repository already classified, so retry is disabled
      // here and left to the explicit `refresh()` action instead. (Same
      // reasoning as `projectsControllerProvider`.)
      retry: (retryCount, error) => null,
    );
