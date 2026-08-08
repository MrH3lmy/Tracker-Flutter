import 'package:tracker_flutter/features/projects/data/project_selection_store.dart';

class FakeProjectSelectionStore implements ProjectSelectionStore {
  final Map<int, int> _byUserId = {};
  int writeCalls = 0;
  int clearCalls = 0;

  /// Set to make [readSelectedProjectId] wait on this future before
  /// resolving — used to deterministically make restoration arrive after
  /// some other async operation (e.g. a project-list fetch or an explicit
  /// selection) instead of racing on microtask ordering.
  Future<void>? readDelay;

  void seed(int userId, int projectId) => _byUserId[userId] = projectId;

  @override
  Future<int?> readSelectedProjectId(int userId) async {
    // Snapshot the value before the artificial delay. This models an
    // already-started persistence read whose stale result is delivered
    // later, which is the race the production controller must guard.
    final value = _byUserId[userId];
    if (readDelay != null) await readDelay;
    return value;
  }

  @override
  Future<void> writeSelectedProjectId(int userId, int projectId) async {
    writeCalls++;
    _byUserId[userId] = projectId;
  }

  @override
  Future<void> clearSelectedProjectId(int userId) async {
    clearCalls++;
    _byUserId.remove(userId);
  }
}
