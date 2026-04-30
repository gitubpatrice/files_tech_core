import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'recent_file.dart';

/// Service de gestion des fichiers récemment ouverts. Stocké dans
/// `SharedPreferences` sous une clé configurable (par défaut `recent_files`).
///
/// Les fichiers qui n'existent plus sur le filesystem sont automatiquement
/// filtrés à la lecture — pas de stale entry visible dans l'UI.
class RecentFilesService {
  /// Clé `SharedPreferences` (override possible si plusieurs listes co-existent).
  final String key;

  /// Nombre maximum d'entrées conservées (les plus anciennes sont éjectées).
  final int maxFiles;

  const RecentFilesService({
    this.key = 'recent_files',
    this.maxFiles = 20,
  });

  /// Charge la liste persistée, filtre les fichiers disparus, trie par date
  /// décroissante.
  Future<List<RecentFile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? [];
    return list
        .map((s) => RecentFile.fromJsonString(s))
        .where((f) => File(f.path).existsSync())
        .toList()
      ..sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
  }

  /// Ajoute un fichier (ou met à jour son `lastOpened`). Conserve l'état
  /// `isFavorite` existant.
  Future<List<RecentFile>> addOrUpdate(
      List<RecentFile> current, String path) async {
    final file = File(path);
    if (!file.existsSync()) return current;
    final name = path.split(RegExp(r'[/\\]')).last;
    final size = file.lengthSync();
    final existing = current.firstWhere(
      (f) => f.path == path,
      orElse: () => RecentFile(
          path: path, name: name, lastOpened: DateTime.now(), sizeBytes: size),
    );
    final updated = [
      RecentFile(
        path: path,
        name: name,
        lastOpened: DateTime.now(),
        sizeBytes: size,
        isFavorite: existing.isFavorite,
      ),
      ...current.where((f) => f.path != path),
    ];
    final trimmed = updated.take(maxFiles).toList();
    await _save(trimmed);
    return trimmed;
  }

  Future<List<RecentFile>> remove(
      List<RecentFile> current, String path) async {
    final updated = current.where((f) => f.path != path).toList();
    await _save(updated);
    return updated;
  }

  Future<List<RecentFile>> toggleFavorite(
      List<RecentFile> current, String path) async {
    final updated = current
        .map((f) => f.path == path ? f.copyWith(isFavorite: !f.isFavorite) : f)
        .toList();
    await _save(updated);
    return updated;
  }

  Future<void> _save(List<RecentFile> files) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, files.map((f) => f.toJsonString()).toList());
  }
}
