import 'package:shared_preferences/shared_preferences.dart';

/// Persists a list of pinned folder paths.
/// Pinned folders appear at the top of the Folders tab.
class PinnedFoldersService {
  PinnedFoldersService._();
  static final PinnedFoldersService instance = PinnedFoldersService._();

  static const _key = 'pinned_folders';

  Future<List<String>> getPinned() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_key) ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<void> pin(String folderPath) async {
    final current = await getPinned();
    if (current.contains(folderPath)) return;
    current.insert(0, folderPath);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, current);
  }

  Future<void> unpin(String folderPath) async {
    final current = await getPinned();
    current.remove(folderPath);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, current);
  }

  Future<bool> isPinned(String folderPath) async {
    final current = await getPinned();
    return current.contains(folderPath);
  }
}
