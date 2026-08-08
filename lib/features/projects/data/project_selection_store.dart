import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the selected-project id — a UI convenience, never a credential
/// — using ordinary (non-encrypted) local preferences. Refresh tokens stay
/// exclusively in `SecureTokenStorage`; nothing account-sensitive belongs
/// here.
///
/// Every key is namespaced by user id so a selection never leaks across an
/// account switch on a shared device, and [clearSelectedProjectId] lets
/// callers drop it explicitly on logout.
///
/// Mirrors `SecureTokenStorage`'s contract: reads never throw. A corrupted
/// or unavailable preferences store degrades to "nothing selected" rather
/// than crashing the app over a UI convenience.
abstract interface class ProjectSelectionStore {
  Future<int?> readSelectedProjectId(int userId);
  Future<void> writeSelectedProjectId(int userId, int projectId);
  Future<void> clearSelectedProjectId(int userId);
}

class SharedPreferencesProjectSelectionStore implements ProjectSelectionStore {
  const SharedPreferencesProjectSelectionStore();

  @override
  Future<int?> readSelectedProjectId(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_key(userId));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeSelectedProjectId(int userId, int projectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key(userId), projectId);
    } catch (_) {
      // Best-effort: the in-memory selection for this app session still
      // works, only persistence for the next launch is lost.
    }
  }

  @override
  Future<void> clearSelectedProjectId(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
    } catch (_) {
      // Nothing further to do — see writeSelectedProjectId.
    }
  }

  String _key(int userId) => 'projects.selectedProjectId.$userId';
}

final projectSelectionStoreProvider = Provider<ProjectSelectionStore>(
  (ref) => const SharedPreferencesProjectSelectionStore(),
);
