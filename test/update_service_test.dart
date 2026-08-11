import 'package:files_tech_core/files_tech_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// `UpdateService` est le **seul code réseau** de plusieurs des neuf
/// applications qui dépendent de ce paquet, dont certaines annoncent
/// publiquement « aucune permission Internet » ou « 100 % local ».
///
/// La comparaison de versions n'avait aucun test alors qu'elle décide ce qu'on
/// propose d'installer à l'utilisateur. La relecture externe du 2026-08-11 y a
/// trouvé un défaut déterministe, reproduit ci-dessous.
void main() {
  group('comparaison de versions', () {
    test('une version distante plus récente est detectee', () {
      expect(UpdateService.isNewer('1.2.4', '1.2.3'), isTrue);
      expect(UpdateService.isNewer('1.3.0', '1.2.9'), isTrue);
      expect(UpdateService.isNewer('2.0.0', '1.99.99'), isTrue);
    });

    test('une version identique ou plus ancienne ne l est pas', () {
      expect(UpdateService.isNewer('1.2.3', '1.2.3'), isFalse);
      expect(UpdateService.isNewer('1.2.2', '1.2.3'), isFalse);
      expect(UpdateService.isNewer('0.9.9', '1.0.0'), isFalse);
    });

    test('une version locale SUFFIXEE ne provoque pas de retrogradation', () {
      // LE test de ce fichier.
      //
      // Chaque composant illisible valait `0` (`int.tryParse(...) ?? 0`). Sur
      // une version locale `1.2.3-beta`, le dernier composant tombait donc a
      // zero, et `1.2.2` passait pour plus recent : l application proposait une
      // RETROGRADATION presentee comme une mise a jour.
      for (final local in <String>[
        '1.2.3-beta',
        '1.2.3+4',
        '1.2.3-rc.1',
        '1.2.3 ',
      ]) {
        expect(
          UpdateService.isNewer('1.2.2', local),
          isFalse,
          reason: 'local « $local » : retrogradation proposee',
        );
      }
    });

    test('une version illisible des deux cotes ne propose rien', () {
      // Repli sur : dans le doute, ne rien proposer. Proposer une mise a jour
      // qu on ne sait pas comparer, c est risquer de proposer une
      // retrogradation.
      for (final paire in <List<String>>[
        ['', '1.2.3'],
        ['1.2.3', ''],
        ['abc', '1.2.3'],
        ['1.2.3', 'abc'],
        ['1.2', '1.2.3'],
        ['1.2.3.4', '1.2.3'],
        ['1..3', '1.2.3'],
      ]) {
        expect(
          UpdateService.isNewer(paire[0], paire[1]),
          isFalse,
          reason: '« ${paire[0]} » contre « ${paire[1]} »',
        );
      }
    });

    test('un composant demesure est refuse, pas converti', () {
      // Un `tag_name` hostile portant des dizaines de milliers de chiffres
      // coute cher a convertir pour un resultat qui n a aucun sens.
      final enorme = '${'9' * 50000}.0.0';
      final chrono = Stopwatch()..start();
      expect(UpdateService.isNewer(enorme, '1.2.3'), isFalse);
      chrono.stop();
      expect(
        chrono.elapsedMilliseconds,
        lessThan(200),
        reason:
            'conversion en ${chrono.elapsedMilliseconds} ms : la borne de '
            'longueur ne s exprime pas',
      );
    });

    test('les zeros en tete restent compris', () {
      // `01` vaut bien 1 : refuser ici casserait des versions legitimes.
      expect(UpdateService.isNewer('1.02.0', '1.1.0'), isTrue);
      expect(UpdateService.isNewer('1.01.0', '1.1.0'), isFalse);
    });
  });

  group('bornes de la requete', () {
    test('le plafond de reponse est fixe et modeste', () {
      // Une release GitHub tient dans quelques kilo-octets. Sans borne,
      // `response.body` lisait TOUT en memoire.
      expect(UpdateService.maxResponseBytes, 512 * 1024);
    });

    test('un seul hote est accepte, y compris apres redirection', () {
      // `http.get` suit les redirections seul et ne revalide ni l hote ni le
      // schema : un `302` vers un autre hote alimentait l application avec un
      // JSON d origine quelconque.
      expect(UpdateService.allowedHosts, {'api.github.com'});
    });
  });
}
