/// Helpers de path safe/sains. Cohérents avec [PathSafe] (anti-traversal)
/// mais pour des usages d'affichage / extraction extension / nom court.
///
/// Conçu pour dédupliquer les ~24 callsites identifiés dans `pdf_tech` et
/// `read_files_tech` qui re-implémentent localement `lastIndexOf('/')` +
/// `lastIndexOf('.')` à la main, parfois sans gérer le séparateur Windows.
///
/// Contrairement à [PathSafe], aucune validation anti-`..` n'est faite ici :
/// ce sont juste des helpers de découpage. Pour valider un nom utilisateur
/// avant écriture sur disque, passer par [PathSafe.sanitizeFileName] ou
/// [PathSafe.sanitizeForFs].
abstract final class PathUtils {
  PathUtils._();

  /// Nom du fichier à partir d'un path full. Ex: `"/a/b/c.pdf"` → `"c.pdf"`.
  /// Gère séparateurs Windows (`\`) + Unix (`/`).
  ///
  /// Si le path est vide, retourne la chaîne vide. Si pas de séparateur,
  /// retourne le path tel quel.
  static String fileName(String path) {
    if (path.isEmpty) return path;
    final i = path.lastIndexOf(RegExp(r'[/\\]'));
    return i < 0 ? path : path.substring(i + 1);
  }

  /// Extension lowercase sans le point. Ex: `"doc.PDF"` → `"pdf"`.
  /// Retourne `''` si pas d'extension, ou si le point est en première
  /// position (fichier caché Unix `.bashrc`), ou s'il termine le nom
  /// (`"foo."`).
  ///
  /// Pour un double-extension `"archive.tar.gz"`, ne retourne que la
  /// dernière partie (`"gz"`) — comportement cohérent avec `path.extension`.
  static String fileExt(String path) {
    final name = fileName(path);
    final i = name.lastIndexOf('.');
    if (i <= 0 || i == name.length - 1) return '';
    return name.substring(i + 1).toLowerCase();
  }

  /// Nom sans extension. Ex: `"/a/b/c.pdf"` → `"c"`.
  /// Pour un fichier caché Unix `".bashrc"`, retourne `".bashrc"` (pas
  /// d'extension à retirer).
  static String fileBaseName(String path) {
    final name = fileName(path);
    final i = name.lastIndexOf('.');
    return i <= 0 ? name : name.substring(0, i);
  }
}
