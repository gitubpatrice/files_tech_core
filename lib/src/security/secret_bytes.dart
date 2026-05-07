import 'dart:math';
import 'dart:typed_data';

/// Helpers pour manipuler des octets sensibles (clés, IV, salt, MAC).
///
/// Usage strict : pour de la donnée crypto (matériel de clé, comparaisons
/// HMAC, IV/nonce, salt KDF). Pour les buffers normaux, utiliser les
/// opérations standard `Uint8List`.
///
/// Conçu pour être un drop-in remplacement des helpers locaux qui pullulaient
/// dans `pass_tech`, `notes_tech`, `read_files_tech` (`_zero`, `_zeroize`,
/// `_wipe`, `_randomBytes`, `_constEq`, `_constantTimeEq`).
abstract final class SecretBytes {
  SecretBytes._();

  /// CSPRNG via `Random.secure()`.
  ///
  /// Lance [StateError] si la plateforme n'expose pas de CSPRNG (Dart le
  /// signale par une [UnsupportedError] interne — propagée ici en
  /// [StateError] pour homogénéiser).
  ///
  /// [n] doit être >= 0. `n == 0` retourne un buffer vide.
  static Uint8List randomBytes(int n) {
    if (n < 0) {
      throw ArgumentError.value(n, 'n', 'doit être >= 0');
    }
    final Random rng;
    try {
      rng = Random.secure();
    } on UnsupportedError catch (e) {
      throw StateError('CSPRNG indisponible : ${e.message}');
    }
    final out = Uint8List(n);
    for (var i = 0; i < n; i++) {
      out[i] = rng.nextInt(256);
    }
    return out;
  }

  /// Écrit 0 sur tout le buffer. Best-effort : Dart GC peut copier la mémoire
  /// avant l'écriture (immutable strings, sublist…). À utiliser AVANT la sortie
  /// de portée d'une clé pour limiter la fenêtre où elle est en clair en RAM.
  ///
  /// Sémantique identique à un `bytes.fillRange(0, bytes.length, 0)`.
  static void wipe(Uint8List bytes) {
    bytes.fillRange(0, bytes.length, 0);
  }

  /// Comparaison en temps constant — accumule l'OR des XOR sur toute la
  /// longueur, sans early return sur les éléments. Sémantique alignée sur
  /// `_constEq` / `_constantTimeEq` historiques.
  ///
  /// Note : retourne `false` si les tailles diffèrent (early return). C'est
  /// inoffensif quand on compare des HMAC ou tags AEAD de taille fixe (tous
  /// les callsites historiques). NE PAS l'utiliser pour comparer des secrets
  /// de longueur variable — un attaquant pourrait observer un timing distinct
  /// selon la longueur.
  static bool constantTimeEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Encode des bytes en hex lowercase. Ex: `[0xAB, 0xCD]` → `"abcd"`.
  ///
  /// Conçu pour les hash de fichier (SHA-256 stocké en base, fingerprints
  /// de modèle ML, IDs dérivés). Ne PAS utiliser pour stocker une clé brute
  /// (pas de wipe possible sur les String — Dart les met en pool).
  static String toHex(Uint8List bytes) {
    final buf = StringBuffer();
    for (final b in bytes) {
      buf.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buf.toString();
  }

  /// Décode une hex string en bytes. Lance [FormatException] si invalide.
  /// Tolère uppercase et lowercase. Refuse une longueur impaire.
  ///
  /// Réciproque de [toHex] : `fromHex(toHex(b))` == `b` pour tout `b`.
  static Uint8List fromHex(String hex) {
    if (hex.length.isOdd) {
      throw const FormatException('hex string with odd length');
    }
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      final byte = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      out[i] = byte;
    }
    return out;
  }

  /// Comparaison en temps constant de deux strings hex (sortie SHA-256, etc.).
  /// Lance [ArgumentError] si tailles différentes — contrairement à
  /// [constantTimeEq] sur bytes (qui retourne `false`), ici on sait que les
  /// hashs comparés ont une taille fixe connue (64 hex chars pour SHA-256) et
  /// une asymétrie indique un bug appelant qu'on veut signaler.
  ///
  /// Fonctionne directement sur la string sans la passer par [fromHex] : évite
  /// l'allocation de buffers intermédiaires sur le hot path (vérif intégrité
  /// répétée d'un fichier découpé en chunks).
  static bool constantTimeEqHex(String a, String b) {
    if (a.length != b.length) {
      throw ArgumentError('hex strings must have same length');
    }
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
