import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/domain/session_state.dart';
import 'project_selection_store.dart';

/// The selected-project id, safe across restart, logout, and account
/// switch.
///
/// - Restored from [ProjectSelectionStore] once the signed-in user is known
///   (see [restoration], exposed for tests the same way
///   `AuthRepository.startupRestoration` is).
/// - Cleared in memory the instant the signed-in user id changes — a
///   logout or account switch must never leave the previous account's
///   selection visible, even for a frame.
/// - [pruneIfMissing] drops a selection that no longer resolves against the
///   live project list (deletion, lost access, or a stale id restored from
///   a previous session) — callers pass in the ids they actually have
///   access to rather than this class re-fetching anything itself.
class SelectedProjectController extends Notifier<int?> {
  late ProjectSelectionStore _store;
  int? _currentUserId;
  Future<void> _restoration = Future<void>.value();

  @override
  int? build() {
    _store = ref.watch(projectSelectionStoreProvider);
    _currentUserId = ref.read(authRepositoryProvider).userOrNull?.id;

    // ref.listen (not watch) for the account-change signal: a background
    // token refresh flips SessionState between authenticated/refreshing for
    // the *same* user and must not disturb the current selection, so this
    // only reacts when the resolved user id itself actually changes.
    ref.listen<SessionState>(authRepositoryProvider, (previous, next) {
      final newUserId = next.userOrNull?.id;
      if (newUserId == _currentUserId) return;
      _currentUserId = newUserId;
      state = null;
      if (newUserId != null) {
        _restoration = _restoreFor(newUserId);
      }
    });

    final userId = _currentUserId;
    if (userId != null) {
      _restoration = _restoreFor(userId);
    }
    return null;
  }

  Future<void> get restoration => _restoration;

  Future<void> _restoreFor(int userId) async {
    final stored = await _store.readSelectedProjectId(userId);
    // The account may have changed again while this read was in flight;
    // only apply a result that's still relevant.
    if (_currentUserId == userId) {
      state = stored;
    }
  }

  void select(int projectId) {
    state = projectId;
    final userId = _currentUserId;
    if (userId == null) return;
    unawaited(_store.writeSelectedProjectId(userId, projectId));
  }

  void clear() {
    state = null;
    final userId = _currentUserId;
    if (userId == null) return;
    unawaited(_store.clearSelectedProjectId(userId));
  }

  /// Drops the current selection if it isn't in [availableProjectIds] —
  /// call this once the project list has loaded so a deleted/inaccessible/
  /// stale selection never lingers pointed at nothing.
  void pruneIfMissing(Set<int> availableProjectIds) {
    final current = state;
    if (current != null && !availableProjectIds.contains(current)) {
      clear();
    }
  }
}

final selectedProjectControllerProvider =
    NotifierProvider<SelectedProjectController, int?>(
      SelectedProjectController.new,
    );
