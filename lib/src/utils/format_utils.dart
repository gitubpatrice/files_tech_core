/// Helpers de formatage humanisés pour Files Tech.
class FormatUtils {
  /// Format compact d'une taille en octets — style FR : `B / Ko / Mo / Go`.
  /// 1 décimale au-delà de 1 Ko (sauf B = entier). Garde les négatifs à 0.
  ///
  /// - 500 → "500 B"
  /// - 1500 → "1.5 Ko"
  /// - 1500000 → "1.4 Mo"
  /// - 2147483648 → "2.0 Go"
  static String bytes(int b) {
    if (b < 0) return '0 B';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} Ko';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} Mo';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(1)} Go';
  }

  /// Variante "stockage" — style EN : `B / KB / MB / GB`.
  /// MB sans décimale (cohérent avec l'affichage barre de stockage Android).
  /// Garde les négatifs à 0.
  static String bytesStorage(int b) {
    if (b <= 0) return '0 B';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
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

  /// Sanitise un nom de fichier user-controlled.
  ///
  /// Étapes :
  /// 1. Remplace caractères interdits Windows / FAT / contrôle par `_`
  /// 2. Remplace les séquences `..` par `_` (anti path-traversal)
  /// 3. Si [collapseWhitespace] : remplace les whitespaces multiples par un espace
  /// 4. Si [collapseUnderscores] : remplace les `_` multiples par un seul
  /// 5. Si [stripLeadingDots] : retire les `.` et `_` en début
  /// 6. Tronque à [maxLen]
  /// 7. Trim, fallback `'fichier'` si vide
  static String sanitizeFileName(
    String input, {
    int maxLen = 60,
    bool collapseWhitespace = false,
    bool collapseUnderscores = false,
    bool stripLeadingDots = false,
  }) {
    var s = input
        .replaceAll(RegExp(r'[\x00-\x1f/\\:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\.\.+'), '_');
    if (collapseWhitespace) {
      s = s.replaceAll(RegExp(r'\s+'), ' ');
    }
    if (collapseUnderscores) {
      s = s.replaceAll(RegExp(r'_+'), '_');
    }
    if (stripLeadingDots) {
      s = s.replaceFirst(RegExp(r'^[._]+'), '');
    }
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

  /// Sanitisation FS-safe pour générer un nom de fichier de sortie depuis
  /// du contenu user (ex. nom d'export). Variante plus agressive que
  /// [sanitizeFileName] :
  /// - whitespace remplacés par `_` (pas espace)
  /// - underscores consécutifs collapsés
  /// - leading ET trailing `._` retirés
  /// - tronqué à 60 chars
  /// - fallback `'fichier'`
  ///
  /// Convient pour les noms persistés dans `/Files Tech/<Catégorie>/...`.
  static String sanitizeForFs(String name) {
    var s = name.replaceAll(RegExp(r'[\x00-\x1f]'), '_');
    s = s.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    s = s.replaceAll(RegExp(r'\s+'), '_');
    s = s.replaceAll(RegExp(r'_+'), '_');
    s = s.replaceAll(RegExp(r'^[._]+|[._]+$'), '');
    if (s.isEmpty) s = 'fichier';
    if (s.length > 60) s = s.substring(0, 60);
    return s;
  }
}
