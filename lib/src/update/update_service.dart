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
        'https://api.github.com/repos/$owner/$repo/releases/latest',
      );
      final response = await _fetch(uri);
      if (response == null) return null;

      final Map<String, dynamic> data;
      try {
        final decoded = jsonDecode(response);
        if (decoded is! Map<String, dynamic>) return null;
        data = decoded;
      } on FormatException {
        // Réponse qui n'est pas du JSON : portail captif, page d'erreur d'un
        // intermédiaire, réponse tronquée. La vérification n'a PAS eu lieu, et
        // le cache ne doit surtout pas être marqué — voir plus bas.
        return null;
      }

      // Le cache n'est marqué qu'ICI, une fois la réponse réellement comprise.
      //
      // Il l'était auparavant juste après le contrôle du code HTTP, donc AVANT
      // `jsonDecode`. Un « 200 » accompagné d'une page HTML — le cas ordinaire
      // d'un portail captif Wi-Fi — marquait donc la vérification comme faite,
      // et plus aucun contrôle n'avait lieu pendant douze heures, même une fois
      // la connexion redevenue normale. L'utilisateur restait sur « pas de mise
      // à jour » alors que rien n'avait été vérifié.
      await prefs.setInt(_cacheKey, now);

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
  /// Plafond de la réponse acceptée, en octets.
  ///
  /// Une release GitHub tient dans quelques kilo-octets. `response.body` lit
  /// TOUT en mémoire sans borne : un intermédiaire — proxy d'entreprise,
  /// autorité installée sur l'appareil, portail captif — pouvait faire avaler
  /// une réponse de plusieurs centaines de mégaoctets et faire tomber
  /// l'application.
  static const int maxResponseBytes = 512 * 1024;

  /// Hôtes acceptés pour la requête, y compris **après redirection**.
  ///
  /// `http.get` suit les redirections tout seul et ne revérifie ni l'hôte ni le
  /// schéma. Un `302` vers un autre hôte — ou vers `http://` en clair —
  /// alimentait donc l'application avec un JSON d'origine quelconque.
  static const Set<String> allowedHosts = {'api.github.com'};

  /// Récupère le corps de la réponse, ou `null` si quoi que ce soit cloche.
  ///
  /// Les redirections sont suivies **à la main**, pour pouvoir revalider l'hôte
  /// et le schéma à chaque saut.
  /// Duree maximale de TOUTE l'operation, redirections et lecture du corps
  /// comprises.
  ///
  /// Le delai ne portait d'abord que sur `client.send`, c'est-a-dire sur
  /// l'obtention des en-tetes. Un serveur repondant « 200 » aussitot puis
  /// n'envoyant plus rien laissait la lecture attendre indefiniment. C'etait
  /// une REGRESSION par rapport a `http.get(...).timeout(...)`, qui englobait
  /// la lecture de `response.body`. Signalee par la relecture GPT du
  /// 2026-08-11.
  static const Duration budgetTotal = Duration(seconds: 20);

  /// Delai maximal entre deux fragments recus.
  static const Duration budgetParFragment = Duration(seconds: 10);

  static Future<String?> _fetch(Uri uri) async {
    final client = http.Client();
    final echeance = DateTime.now().add(budgetTotal);
    Duration reste() {
      final r = echeance.difference(DateTime.now());
      return r.isNegative ? Duration.zero : r;
    }

    try {
      var cible = uri;
      for (var saut = 0; saut < 5; saut++) {
        if (cible.scheme != 'https' || !allowedHosts.contains(cible.host)) {
          return null;
        }
        if (reste() == Duration.zero) return null;
        final requete = http.Request('GET', cible)
          ..followRedirects = false
          ..headers['Accept'] = 'application/vnd.github+json';
        final reponse = await client.send(requete).timeout(reste());

        if (reponse.isRedirect) {
          final vers = reponse.headers['location'];
          // Un `Location` vide se resout sur l'URL courante : sans ce
          // controle, une redirection vide faisait cinq requetes identiques
          // avant d'abandonner.
          if (vers == null || vers.isEmpty) {
            await reponse.stream.drain<void>();
            return null;
          }
          cible = cible.resolve(vers);
          await reponse.stream.drain<void>();
          continue;
        }
        if (reponse.statusCode != 200) {
          await reponse.stream.drain<void>();
          return null;
        }
        // Un `Content-Length` annoncé au-delà du plafond est refusé avant même
        // de lire ; sans en-tête, le comptage ci-dessous prend le relais.
        final annonce = reponse.contentLength;
        if (annonce != null && annonce > maxResponseBytes) {
          await reponse.stream.drain<void>();
          return null;
        }

        final octets = <int>[];
        await for (final tranche in reponse.stream.timeout(budgetParFragment)) {
          if (DateTime.now().isAfter(echeance)) return null;
          // La borne est verifiee AVANT d'ajouter le fragment. Elle l'etait
          // apres : un serveur envoyant un seul fragment de 600 Ko le faisait
          // donc entierement allouer avant d'etre refuse.
          if (octets.length + tranche.length > maxResponseBytes) return null;
          octets.addAll(tranche);
        }
        return utf8.decode(octets, allowMalformed: true);
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static bool isNewer(String remote, String local) => _isNewer(remote, local);

  static bool _isNewer(String remote, String local) {
    final r = _composants(remote);
    final l = _composants(local);
    // Une version illisible d'un côté ou de l'autre ne permet AUCUNE
    // comparaison. Proposer une mise à jour dans le doute, c'est risquer de
    // proposer une rétrogradation ; ne rien proposer est le repli sûr.
    if (r == null || l == null) return false;
    for (var i = 0; i < 3; i++) {
      if (r[i] > l[i]) return true;
      if (r[i] < l[i]) return false;
    }
    return false;
  }

  /// Les trois composants de [version], ou `null` si elle n'est pas un
  /// `X.Y.Z` strict.
  ///
  /// **Pourquoi refuser plutôt que combler.** Chaque composant illisible valait
  /// auparavant `0` (`int.tryParse(...) ?? 0`). Une version locale suffixée —
  /// `1.2.3-beta`, `1.2.3+4`, ce que rend `PackageInfo` sur certaines
  /// configurations — voyait donc son dernier composant ramené à zéro, et
  /// `1.2.2` passait pour plus récent que `1.2.3-beta` : l'application
  /// proposait une **rétrogradation** présentée comme une mise à jour.
  ///
  /// La longueur est bornée : un composant de plusieurs dizaines de milliers de
  /// chiffres, venu d'un `tag_name` hostile, coûte cher à convertir pour rien.
  static List<int>? _composants(String version) {
    final parts = version.split('.');
    if (parts.length != 3) return null;
    final out = <int>[];
    for (final p in parts) {
      if (p.isEmpty || p.length > 9) return null;
      final v = int.tryParse(p);
      if (v == null || v < 0) return null;
      out.add(v);
    }
    return out;
  }
}
