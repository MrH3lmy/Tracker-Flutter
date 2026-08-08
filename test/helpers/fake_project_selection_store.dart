import 'package:tracker_flutter/features/projects/data/project_selection_store.dart';

class FakeProjectSelectionStore implements ProjectSelectionStore {
  final Map<int, int> _byUserId = {};
  int writeCalls = 0;
  int clearCalls = 0;

  /// Set to make [readSelectedProjectId] wait on this future before
  /// resolving — used to deterministically make restoration arrive after
  /// some other async operation (e.g. a project-list fetch) instead of
  /// racing on microtask ordering.
  Future<void>? readDelay;

  void seed(int userId, int projectId) => _byUserId[userId] = projectId;

  @override
  Future<int?> readSelectedProjectId(int userId) async {
    if (readDelay != null) await readDelay;
    return _byUserId[userId];
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
