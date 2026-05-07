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
}
