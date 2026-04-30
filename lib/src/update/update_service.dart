import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Informations sur une mise à jour disponible. Retournée par
/// [UpdateService.checkForUpdate] uniquement quand une nouvelle version
/// est plus récente que la version locale.
class UpdateInfo {
  /// Version de la release GitHub (sans le `v` initial). Ex. `"1.8.0"`.
  final String version;

  /// Corps Markdown de la release (notes de version).
  final String body;

  /// URL de l'APK arm64-v8a si présent dans les assets de la release.
  /// null si aucun asset `.apk` joint.
  final String? apkUrl;

  /// SHA-256 de l'APK arm64-v8a, extrait du body de la release au format
  /// `SHA-256: <hex>` ou `SHA256: <hex>`. null si non publié dans les notes.
  /// Pour vérification manuelle utilisateur (defense in depth — pas
  /// d'auto-download).
  final String? expectedSha256;

  const UpdateInfo({
    required this.version,
    required this.body,
    this.apkUrl,
    this.expectedSha256,
  });
}

/// Service de vérification des mises à jour via GitHub Releases.
///
/// Cache via `SharedPreferences` (clé `update_last_check_ms_<repo>`) — évite
/// de spammer l'API GitHub (limite 60 req/h anonyme). Bypass via `force: true`.
///
/// Usage :
/// ```dart
/// const svc = UpdateService(
///   owner: 'gitubpatrice',
///   repo: 'PDF-TECH',
///   currentVersion: '1.8.0',
/// );
/// final info = await svc.checkForUpdate();
/// if (info != null) showUpdateDialog(info);
/// ```
class UpdateService {
  /// Owner GitHub (ex. `gitubpatrice`).
  final String owner;

  /// Nom du repo (ex. `PDF-TECH`).
  final String repo;

  /// Version locale actuelle (sans `v`). Ex. `"1.8.0"`.
  final String currentVersion;

  /// Durée de validité du cache. Au-delà, un nouveau check sera tenté.
  /// Défaut : 12 h.
  final Duration cacheDuration;

  const UpdateService({
    required this.owner,
    required this.repo,
    required this.currentVersion,
    this.cacheDuration = const Duration(hours: 12),
  });

  String get _cacheKey => 'update_last_check_ms_$repo';

  /// Vérifie si une mise à jour est disponible.
  ///
  /// Retourne `null` si :
  /// - cache encore valide (et `force: false`)
  /// - pas de connexion / erreur réseau
  /// - HTTP non-200
  /// - aucune version plus récente
  ///
  /// Retourne [UpdateInfo] si une mise à jour est disponible.
  Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_cacheKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!force && now - last < cacheDuration.inMilliseconds) return null;

      final uri = Uri.parse(
          'https://api.github.com/repos/$owner/$repo/releases/latest');
      final response = await http
          .get(uri, headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      // Marque le check effectué (évite re-check pendant cacheDuration, même
      // si pas de mise à jour disponible).
      await prefs.setInt(_cacheKey, now);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Validation type-safe : si GitHub renvoie un payload inattendu (ou
      // compte compromis publiant un asset au format custom), on refuse au
      // lieu de crasher.
      final tagRaw = data['tag_name'];
      if (tagRaw is! String) return null;
      final tag = tagRaw.replaceFirst(RegExp(r'^v'), '');
      // Regex semver stricte X.Y.Z (pas de pre-release, cohérent avec le
      // versioning Files Tech).
      if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(tag)) return null;
      if (!_isNewer(tag, currentVersion)) return null;

      // Whitelist hosts GitHub pour l'apkUrl. Empêche un release malicieuse
      // (compte compromis) de pointer vers un APK hébergé hors github.com.
      String? apkUrl;
      final assets = data['assets'];
      if (assets is List) {
        for (final a in assets) {
          if (a is! Map) continue;
          final name = a['name'];
          final url = a['browser_download_url'];
          if (name is! String || url is! String) continue;
          if (!name.toLowerCase().endsWith('.apk')) continue;
          final u = Uri.tryParse(url);
          if (u == null || u.scheme != 'https') continue;
          if (u.host != 'github.com' &&
              u.host != 'objects.githubusercontent.com') {
            continue;
          }
          apkUrl = url;
          break;
        }
      }

      final body = data['body'] is String ? data['body'] as String : '';
      return UpdateInfo(
        version: tag,
        body: body,
        apkUrl: apkUrl,
        expectedSha256: _extractSha256(body),
      );
    } catch (_) {
      return null;
    }
  }

  /// Extrait le SHA-256 hex du body de la release GitHub. Cherche les
  /// patterns `SHA-256: <hex>` ou `SHA256: <hex>` (insensible à la casse).
  static String? _extractSha256(String body) {
    final match = RegExp(
      r'sha-?256\s*[:=]\s*([0-9a-fA-F]{64})',
      caseSensitive: false,
    ).firstMatch(body);
    return match?.group(1)?.toLowerCase();
  }

  /// True si `remote` > `local` en version semver (3 segments majeur.mineur.patch).
  static bool isNewer(String remote, String local) => _isNewer(remote, local);

  static bool _isNewer(String remote, String local) {
    final r = remote.split('.').map(int.tryParse).toList();
    final l = local.split('.').map(int.tryParse).toList();
    for (int i = 0; i < 3; i++) {
      final rv = i < r.length ? (r[i] ?? 0) : 0;
      final lv = i < l.length ? (l[i] ?? 0) : 0;
      if (rv > lv) return true;
      if (rv < lv) return false;
    }
    return false;
  }
}
