import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, Clipboard, ClipboardData;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sections "Aide & support" + "Mentions légales" partagées par toutes les
/// apps Files Tech.
///
/// Sécurité :
/// - Liens limités aux schemes `https`, `http`, `mailto` (anti `intent:`,
///   `javascript:`, `file:` même sur Markdown forgé)
/// - Pas de `userInfo` accepté (anti `https://user:pass@evil.com`)
/// - Subject/body de mail dépouillés de CRLF (anti header injection)
/// - Assets MD configurables (l'app consommatrice doit déclarer
///   `assets/legal/PRIVACY.fr.md` et `TERMS.fr.md` dans son `pubspec.yaml`)
class LegalSupportSections extends StatelessWidget {
  final String appName;
  final String version;
  final String contactEmail;
  final String websiteUrl;
  final String privacyAsset;
  final String termsAsset;

  const LegalSupportSections({
    super.key,
    required this.appName,
    required this.version,
    this.contactEmail = 'contact@files-tech.com',
    this.websiteUrl   = 'https://files-tech.com',
    this.privacyAsset = 'assets/legal/PRIVACY.fr.md',
    this.termsAsset   = 'assets/legal/TERMS.fr.md',
  });

  /// Schemes autorisés pour `_openUrl` et les liens Markdown.
  /// Tout autre scheme (intent, javascript, file, content, app, market…) est
  /// refusé silencieusement.
  static const _allowedSchemes = {'https', 'http', 'mailto'};

  static bool _isSafeUri(Uri u) {
    if (!_allowedSchemes.contains(u.scheme.toLowerCase())) return false;
    if (u.userInfo.isNotEmpty) return false; // anti credential phishing
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(context, 'Aide & support'),
        const SizedBox(height: 8),
        Card(
          child: Column(children: [
            ListTile(
              leading: Icon(Icons.email_outlined, color: cs.primary),
              title: const Text('Contacter le support'),
              subtitle: Text(contactEmail),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () => _openMail(context, contactEmail,
                  '$appName v$version — support'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.public, color: cs.primary),
              title: const Text('Site officiel'),
              subtitle: Text(_displayHost(websiteUrl)),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () => _openUrl(context, websiteUrl),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.bug_report_outlined, color: cs.primary),
              title: const Text('Signaler un bug'),
              subtitle: const Text('Email avec version pré-remplie'),
              onTap: () => _openMail(context, contactEmail,
                  '$appName v$version — bug',
                  body: 'Décrivez le problème rencontré :\n\n\n'
                      '— Version : $version\n— Appareil : '),
            ),
          ]),
        ),

        const SizedBox(height: 24),

        _section(context, 'Mentions légales'),
        const SizedBox(height: 8),
        Card(
          child: Column(children: [
            ListTile(
              leading: Icon(Icons.privacy_tip_outlined, color: cs.primary),
              title: const Text('Politique de confidentialité'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openLegal(context,
                  title: 'Politique de confidentialité',
                  asset: privacyAsset),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.gavel_outlined, color: cs.primary),
              title: const Text('Conditions d\'utilisation'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openLegal(context,
                  title: 'Conditions d\'utilisation',
                  asset: termsAsset),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.copyright_outlined, color: cs.primary),
              title: const Text('Licence'),
              subtitle: const Text('Apache 2.0'),
              onTap: () => _openUrl(context,
                  'https://www.apache.org/licenses/LICENSE-2.0'),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '© ${DateTime.now().year} Files Tech',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
        ),
      ],
    );
  }

  String _displayHost(String url) {
    final u = Uri.tryParse(url);
    return (u != null && u.host.isNotEmpty) ? u.host : url;
  }

  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(url);
    if (uri == null || !_isSafeUri(uri)) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Lien refusé pour des raisons de sécurité.'),
      ));
      return;
    }
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        messenger.showSnackBar(
            SnackBar(content: Text('Impossible d\'ouvrir : $url')));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Erreur d\'ouverture du lien.')));
    }
  }

  Future<void> _openMail(BuildContext context, String to, String subject,
      {String? body}) async {
    final messenger = ScaffoldMessenger.of(context);
    // Strip CRLF dans les headers (anti mailto header injection).
    final safeSubject = subject.replaceAll(RegExp(r'[\r\n]'), ' ');
    final safeBody    = body?.replaceAll(RegExp(r'\r\n?'), '\n');
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      queryParameters: <String, String>{
        'subject': safeSubject,
        'body': ?safeBody,
      },
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    } catch (_) {/* fall through */}
    await Clipboard.setData(ClipboardData(text: to));
    messenger.showSnackBar(SnackBar(
      content: Text('Aucune app mail. Adresse copiée : $to'),
    ));
  }

  void _openLegal(BuildContext context,
      {required String title, required String asset}) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _LegalScreen(title: title, asset: asset),
      ),
    );
  }
}

class _LegalScreen extends StatelessWidget {
  final String title;
  final String asset;
  const _LegalScreen({required this.title, required this.asset});

  // Même whitelist scheme que le parent.
  static const _allowedSchemes = {'https', 'http', 'mailto'};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(asset),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return Center(child: Text('Erreur de chargement : ${snap.error}'));
          }
          return Markdown(
            data: snap.data!,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            selectable: true,
            onTapLink: (text, href, title) async {
              if (href == null) return;
              final uri = Uri.tryParse(href);
              if (uri == null) return;
              if (!_allowedSchemes.contains(uri.scheme.toLowerCase())) return;
              if (uri.userInfo.isNotEmpty) return;
              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              } catch (_) {/* silent */}
            },
          );
        },
      ),
    );
  }
}
