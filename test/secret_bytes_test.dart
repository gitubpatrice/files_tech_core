import 'dart:typed_data';

import 'package:files_tech_core/files_tech_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SecretBytes.fromHex — rejet des entrées non hexadécimales', () {
    // Régression : `int.parse(..., radix: 16)` accepte un signe de tête et des
    // espaces. `fromHex('-a')` rendait donc l'octet 246 (troncature deux
    // compléments par Uint8List) au lieu de lever, alors que la doc promet une
    // FormatException. Ces cas verrouillent le contrat.
    for (final bad in const ['+a', '-a', ' a', 'a ', '+0', '-0', 'g0', '0g']) {
      test('rejette "$bad"', () {
        expect(() => SecretBytes.fromHex(bad), throwsFormatException);
      });
    }

    test('rejette une longueur impaire', () {
      expect(() => SecretBytes.fromHex('abc'), throwsFormatException);
    });

    test('accepte le hex valide, casses mélangées', () {
      expect(SecretBytes.fromHex('00ffAb'), [0x00, 0xff, 0xab]);
    });

    test('chaîne vide → buffer vide', () {
      expect(SecretBytes.fromHex(''), isEmpty);
    });

    test('round-trip toHex ∘ fromHex est l\'identité', () {
      final src = Uint8List.fromList([0, 1, 15, 16, 127, 128, 254, 255]);
      expect(SecretBytes.fromHex(SecretBytes.toHex(src)), src);
    });
  });

  group('SecretBytes.wipe — signale l\'échec au lieu de l\'avaler', () {
    test('buffer modifiable : zéroïse et retourne true', () {
      final b = Uint8List.fromList([1, 2, 3, 4]);
      expect(SecretBytes.wipe(b), isTrue);
      expect(b, everyElement(0));
    });

    test('vue non modifiable : retourne false sans lever', () {
      // C'est le cas que certaines impls FFI de `cryptography_flutter`
      // produisent. Avant, l'échec était silencieux : l'appelant croyait le
      // matériel de clé effacé alors qu'il restait intact en RAM.
      final ro = Uint8List.fromList([1, 2, 3, 4]).asUnmodifiableView();
      expect(SecretBytes.wipe(ro), isFalse);
      expect(ro, [1, 2, 3, 4]);
    });

    test('le fil-piege ne LEVE JAMAIS, meme en debug', () {
      // Point critique de conception. `wipe` est tres souvent appelee depuis
      // un `finally` de nettoyage : si le fil-piege levait une AssertionError,
      // elle masquerait l'exception d'origine et transformerait un defaut
      // d'hygiene memoire en plantage — y compris quand l'operation elle-meme
      // avait reussi. Les tests tournent en mode debug, donc ce test
      // exercerait bien un `assert(false, ...)` s'il en restait un.
      final ro = Uint8List.fromList([9, 9, 9]).asUnmodifiableView();
      expect(() => SecretBytes.wipe(ro), returnsNormally);
      expect(SecretBytes.wipe(ro), isFalse);
    });

    test('buffer vide : succès trivial', () {
      expect(SecretBytes.wipe(Uint8List(0)), isTrue);
    });
  });

  group('SecretBytes.constantTimeEq', () {
    test('longueurs différentes → false', () {
      expect(SecretBytes.constantTimeEq([1, 2], [1, 2, 3]), isFalse);
    });

    test('contenu identique → true', () {
      expect(SecretBytes.constantTimeEq([1, 2, 3], [1, 2, 3]), isTrue);
    });

    test('un seul bit différent → false', () {
      expect(SecretBytes.constantTimeEq([1, 2, 3], [1, 2, 2]), isFalse);
    });
  });

  group('SecretBytes.randomBytes', () {
    test('longueur négative → ArgumentError', () {
      expect(() => SecretBytes.randomBytes(-1), throwsArgumentError);
    });

    test('n == 0 → buffer vide', () {
      expect(SecretBytes.randomBytes(0), isEmpty);
    });

    test('deux tirages de 32 octets diffèrent', () {
      expect(SecretBytes.randomBytes(32), isNot(SecretBytes.randomBytes(32)));
    });
  });
}
