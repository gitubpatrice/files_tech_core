import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Identifiants des packages Android pour les destinations cloud
/// supportées par Files Tech.
class CloudTargets {
  static const kDrive = 'com.infomaniak.drive';
  static const googleDrive = 'com.google.android.apps.docs';
  static const protonDrive = 'me.proton.android.drive';

  /// Cible cross-app : ouvre un PDF directement dans PDF Tech depuis RFT.
  /// Utilisé par RFT (file_explorer) — pas de cible inverse pour le moment.
  static const pdfTech = 'com.pdftech.pdf_tech';
}

/// Rangée de boutons d'envoi cloud direct + partage générique.
///
/// Utilise un MethodChannel exposant la méthode `sendToPackage` côté Kotlin
/// (passe par FileProvider + setPackage avec FLAG_GRANT_READ_URI_PERMISSION).
///
/// Sécurité : aucune URI directe — uniquement content:// URIs avec accès
/// limité à l'app cible. Pas d'exfiltration possible vers une app non listée
/// dans le manifest `queries`.
///
/// Usage :
/// ```dart
/// CloudShareRow(
///   path: outputPath,
///   mime: 'application/pdf',
///   channelName: 'com.pdftech.pdf_tech/share',
///   alignment: WrapAlignment.center,
/// )
/// ```
class CloudShareRow extends StatelessWidget {
  /// Chemin absolu du fichier à partager.
  final String path;

  /// Type MIME (`application/pdf`, `image/jpeg`, …).
  final String mime;

  /// Nom du MethodChannel Kotlin qui implémente `sendToPackage`.
  /// Chaque app a son propre channel : `com.pdftech.pdf_tech/share`,
  /// `com.readfilestech/open_file`, etc.
  final String channelName;

  /// Alignement horizontal du Wrap. `start` par défaut (compatible RFT) ;
  /// utiliser `center` côté PDF Tech.
  final WrapAlignment alignment;

  const CloudShareRow({
    super.key,
    required this.path,
    required this.channelName,
    this.mime = 'application/octet-stream',
    this.alignment = WrapAlignment.start,
  });

  Future<void> _send(BuildContext context, String pkg, String label) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await MethodChannel(channelName).invokeMethod('sendToPackage', {
        'path': path,
        'mime': mime,
        'package': pkg,
      });
    } on PlatformException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'NOT_INSTALLED'
                ? '$label n\'est pas installé sur cet appareil.'
                : 'Erreur d\'envoi vers $label.',
          ),
        ),
      );
    } on MissingPluginException {
      // Channel non enregistré côté Kotlin — typiquement en hot-reload sur un
      // build qui ne contient pas encore le handler. Évite le crash.
      messenger.showSnackBar(
        SnackBar(content: Text('Service indisponible pour $label.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erreur d\'envoi vers $label.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: alignment,
      children: [
        OutlinedButton.icon(
          onPressed: () => Share.shareXFiles([XFile(path, mimeType: mime)]),
          icon: const Icon(Icons.share, size: 14),
          label: const Text('Partager', style: TextStyle(fontSize: 12)),
        ),
        OutlinedButton.icon(
          onPressed: () => _send(context, CloudTargets.kDrive, 'kDrive'),
          icon: const Icon(
            Icons.cloud_upload_outlined,
            size: 14,
            color: Color(0xFF0098FF),
          ),
          label: const Text('kDrive', style: TextStyle(fontSize: 12)),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              _send(context, CloudTargets.googleDrive, 'Google Drive'),
          icon: const Icon(
            Icons.cloud_upload_outlined,
            size: 14,
            color: Color(0xFFEA4335),
          ),
          label: const Text('Google Drive', style: TextStyle(fontSize: 12)),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              _send(context, CloudTargets.protonDrive, 'Proton Drive'),
          icon: const Icon(
            Icons.cloud_upload_outlined,
            size: 14,
            color: Color(0xFF6D4AFF),
          ),
          label: const Text('Proton Drive', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
