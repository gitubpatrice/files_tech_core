/// Helpers de formatage humanisés pour Files Tech.
class FormatUtils {
  /// Format compact d'une taille en octets : `B / Ko / Mo / Go`.
  /// Toujours 1 décimale au-delà de 1 Ko (sauf B = entier).
  ///
  /// - 500 → "500 B"
  /// - 1500 → "1.5 Ko"
  /// - 1500000 → "1.4 Mo"
  /// - 2147483648 → "2.0 Go"
  static String bytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} Ko';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} Mo';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(1)} Go';
  }
}

/// Helpers de manipulation de chemins / noms de fichiers — sécurité-first.
class PathSafe {
  /// Extrait un basename sûr d'un path source, gère séparateurs Unix et Windows.
  /// Lève [ArgumentError] si le résultat est vide, `.`, `..`, ou contient des
  /// caractères de séparateur internes (anti path-traversal).
  static String basename(String path) {
    final raw = path.split(RegExp(r'[/\\]')).last;
    if (raw.isEmpty || raw == '.' || raw == '..') {
      throw ArgumentError('Nom de fichier invalide');
    }
    if (raw.contains('/') || raw.contains('\\') || raw.contains('\x00')) {
      throw ArgumentError('Nom de fichier invalide');
    }
    return raw;
  }

  /// Sanitise un nom de fichier user-controlled : remplace les caractères
  /// interdits Windows / FAT / contrôle par `_`, supprime les `..`, tronque à
  /// [maxLen] (défaut 60). Garantit un résultat non vide (`'fichier'` si tout
  /// est filtré).
  static String sanitizeFileName(String input, {int maxLen = 60}) {
    var s = input
        .replaceAll(RegExp(r'[\x00-\x1f/\\:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\.\.+'), '_');
    if (s.length > maxLen) s = s.substring(0, maxLen);
    s = s.trim();
    if (s.isEmpty || s == '.' || s == '..') return 'fichier';
    return s;
  }

  /// True si [name] est un nom user-affichable sûr (pas de séparateur, pas de
  /// `..`, pas de NUL, pas vide).
  static bool isValidUserFileName(String name) {
    if (name.isEmpty || name == '.' || name == '..') return false;
    if (name.contains('/') || name.contains('\\') || name.contains('\x00')) {
      return false;
    }
    return true;
  }
}
