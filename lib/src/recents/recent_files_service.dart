import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/format_utils.dart';
import 'recent_file.dart';

/// Service de gestion des fichiers récemment ouverts. Stocké dans
/// `SharedPreferences` sous une clé configurable (par défaut `recent_files`).
///
/// **Robustesse** : la lecture (`load`) ignore silencieusement les entrées
/// JSON corrompues plutôt que de crasher l'app au boot. Si la liste persistée
/// contient des entrées invalides, elle est ré-écrite filtrée — auto-purge.
///
/// Les fichiers qui n'existent plus sur le filesystem sont aussi filtrés.
class RecentFilesService {
  /// Clé `SharedPreferences` (override possible si plusieurs listes co-existent).
  final String key;

  /// Nombre maximum d'entrées conservées (les plus anciennes sont éjectées).
  final int maxFiles;

  const RecentFilesService({
    this.key = 'recent_files',
    this.maxFiles = 20,
  });

  /// Charge la liste persistée, filtre les fichiers disparus + entrées
  /// corrompues, trie par date décroissante.
  Future<List<RecentFile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(key) ?? [];
    final out = <RecentFile>[];
    for (final s in raw) {
      try {
        final f = RecentFile.fromJsonString(s);
        // Vérification d'existence en async pour ne pas bloquer le main isolate
        // (jusqu'à 20 stat syscalls — sur SD lente ça peut piquer).
        if (await File(f.path).exists()) out.add(f);
      } catch (_) {
        // Entrée corrompue → on l'ignore. La liste sera ré-écrite plus bas.
      }
    }
    out.sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
    // Auto-purge : si on a filtré quoi que ce soit, on ré-écrit la liste
    // assainie (évite que la corruption persiste au prochain démarrage).
    if (out.length != raw.length) await _save(out);
    return out;
  }

  /// Ajoute un fichier (ou met à jour son `lastOpened`). Conserve l'état
  /// `isFavorite` existant. Refuse silencieusement les paths invalides
  /// (basename `..`, séparateur, NUL).
  Future<List<RecentFile>> addOrUpdate(
      List<RecentFile> current, String path) async {
    final file = File(path);
    if (!await file.exists()) return current;
    final String name;
    try {
      name = PathSafe.basename(path);
    } on ArgumentError {
      return current;
    }
    final size = await file.length();
    final existing = current.where((f) => f.path == path).cast<RecentFile?>()
        .firstWhere((_) => true, orElse: () => null);
    final isFav = existing?.isFavorite ?? false;
    final updated = [
      RecentFile(
        path: path,
        name: name,
        lastOpened: DateTime.now(),
        sizeBytes: size,
        isFavorite: isFav,
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
