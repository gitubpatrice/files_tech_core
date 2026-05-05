import 'dart:convert';
import '../utils/format_utils.dart';

/// Métadonnées d'un fichier récemment ouvert dans une app Files Tech.
///
/// Sérialisé dans `SharedPreferences` (clé `recent_files` par défaut).
/// Compatible avec les modèles existants de PDF Tech et Read Files Tech.
class RecentFile {
  final String path;
  final String name;
  final DateTime lastOpened;
  final int sizeBytes;
  final bool isFavorite;

  const RecentFile({
    required this.path,
    required this.name,
    required this.lastOpened,
    required this.sizeBytes,
    this.isFavorite = false,
  });

  RecentFile copyWith({bool? isFavorite}) => RecentFile(
    path: path,
    name: name,
    lastOpened: lastOpened,
    sizeBytes: sizeBytes,
    isFavorite: isFavorite ?? this.isFavorite,
  );

  /// Extension du fichier (sans le point), en minuscules. Vide si pas de point.
  /// Exemple : `RecentFile(name: 'Foo.PDF').extension == 'pdf'`.
  String get extension =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'lastOpened': lastOpened.toIso8601String(),
    'sizeBytes': sizeBytes,
    'isFavorite': isFavorite,
  };

  /// Parse défensif : tout champ manquant ou de mauvais type lève
  /// [FormatException] (au lieu d'un `TypeError` cryptique). Le service
  /// `RecentFilesService.load` attrape l'exception et skip l'entrée
  /// corrompue — pas de crash boot si les prefs ont été trafiquées
  /// (DoS persistant prévenu).
  factory RecentFile.fromJson(Map<String, dynamic> json) {
    final path = json['path'];
    final name = json['name'];
    final iso = json['lastOpened'];
    final size = json['sizeBytes'];
    if (path is! String || path.isEmpty) {
      throw const FormatException('RecentFile JSON invalide : path');
    }
    if (name is! String || name.isEmpty) {
      throw const FormatException('RecentFile JSON invalide : name');
    }
    if (iso is! String) {
      throw const FormatException('RecentFile JSON invalide : lastOpened');
    }
    if (size is! int || size < 0) {
      throw const FormatException('RecentFile JSON invalide : sizeBytes');
    }
    final DateTime lastOpened;
    try {
      lastOpened = DateTime.parse(iso);
    } catch (_) {
      throw const FormatException(
        'RecentFile JSON invalide : lastOpened format',
      );
    }
    return RecentFile(
      path: path,
      name: name,
      lastOpened: lastOpened,
      sizeBytes: size,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  String toJsonString() => jsonEncode(toJson());
  factory RecentFile.fromJsonString(String s) =>
      RecentFile.fromJson(jsonDecode(s) as Map<String, dynamic>);

  /// Format humanisé "1.2 Mo" / "456 Ko" / "789 B" / "2.0 Go".
  /// Délègue à [FormatUtils.bytes] (source unique).
  String get formattedSize => FormatUtils.bytes(sizeBytes);
}
