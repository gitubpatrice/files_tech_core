import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle, Clipboard, ClipboardData;
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

  /// Labels optionnels — defaults FR pour rétrocompatibilité avec les apps
  /// qui n'ont pas encore branché leur AppLocalizations. Une app i18n FR/EN
  /// peut passer les chaînes localisées depuis son ARB.
  final String? helpSectionTitle;
  final String? legalSectionTitle;
  final String? contactSupportTitle;
  final String? officialWebsiteTitle;
  final String? reportBugTitle;
  final String? reportBugSubtitle;
  final String? bugBodyIntro;
  final String? bugBodyVersionLabel;
  final String? bugBodyDeviceLabel;
  final String? privacyTitle;
  final String? termsTitle;
  final String? licenseTitle;
  final String? linkRefusedMessage;
  final String? cannotOpenMessage;
  final String? noAppMessage;
  final String? assetReadErrorMessage;
  final String? linkBlockedMessage;

  const LegalSupportSections({
    super.key,
    required this.appName,
    required this.version,
    this.contactEmail = 'contact@files-tech.com',
    this.websiteUrl = 'https://files-tech.com',
    this.privacyAsset = 'assets/legal/PRIVACY.fr.md',
    this.termsAsset = 'assets/legal/TERMS.fr.md',
    this.helpSectionTitle,
    this.legalSectionTitle,
    this.contactSupportTitle,
    this.officialWebsiteTitle,
    this.reportBugTitle,
    this.reportBugSubtitle,
    this.bugBodyIntro,
    this.bugBodyVersionLabel,
    this.bugBodyDeviceLabel,
    this.privacyTitle,
    this.termsTitle,
    this.licenseTitle,
    this.linkRefusedMessage,
    this.cannotOpenMessage,
    this.noAppMessage,
    this.assetReadErrorMessage,
    this.linkBlockedMessage,
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
        _section(context, helpSectionTitle ?? 'Aide & support'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.email_outlined, color: cs.primary),
                title: Text(contactSupportTitle ?? 'Contacter le support'),
                subtitle: Text(contactEmail),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () => _openMail(
                  context,
                  contactEmail,
                  '$appName v$version — support',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.public, color: cs.primary),
                title: Text(officialWebsiteTitle ?? 'Site officiel'),
                subtitle: Text(_displayHost(websiteUrl)),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () => _openUrl(context, websiteUrl),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.bug_report_outlined, color: cs.primary),
                title: Text(reportBugTitle ?? 'Signaler un bug'),
                subtitle: Text(
                  reportBugSubtitle ?? 'Email avec version pré-remplie',
                ),
                onTap: () => _openMail(
                  context,
                  contactEmail,
                  '$appName v$version — bug',
                  body:
                      '${bugBodyIntro ?? 'Décrivez le problème rencontré :'}\n\n\n'
                      '— ${bugBodyVersionLabel ?? 'Version'} : $version\n'
                      '— ${bugBodyDeviceLabel ?? 'Appareil'} : ',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        _section(context, legalSectionTitle ?? 'Mentions légales'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.privacy_tip_outlined, color: cs.primary),
                title: Text(privacyTitle ?? 'Politique de confidentialité'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openLegal(
                  context,
                  title: privacyTitle ?? 'Politique de confidentialité',
                  asset: privacyAsset,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.gavel_outlined, color: cs.primary),
                title: Text(termsTitle ?? 'Conditions d\'utilisation'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openLegal(
                  context,
                  title: termsTitle ?? 'Conditions d\'utilisation',
                  asset: termsAsset,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.copyright_outlined, color: cs.primary),
                title: Text(licenseTitle ?? 'Licence'),
                subtitle: const Text('Apache 2.0'),
                onTap: () => _openUrl(
                  context,
                  'https://www.apache.org/licenses/LICENSE-2.0',
                ),
              ),
            ],
          ),
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
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(url);
    if (uri == null || !_isSafeUri(uri)) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            linkRefusedMessage ?? 'Lien refusé pour des raisons de sécurité.',
          ),
        ),
      );
      return;
    }
    // On NE FAIT PLUS de canLaunchUrl() au préalable : ce check est connu
    // pour échouer même quand launchUrl() fonctionne (bug url_launcher
    // Android — voir https://github.com/flutter/flutter/issues/93765).
    // launchUrl jette PlatformException si le scheme n'a aucun handler →
    // on capture proprement et on affiche le bon message.
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              cannotOpenMessage != null
                  ? '$cannotOpenMessage : $url'
                  : 'Impossible d\'ouvrir : $url',
            ),
          ),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(noAppMessage ?? 'Aucune application disponible.'),
        ),
      );
    }
  }

  Future<void> _openMail(
    BuildContext context,
    String to,
    String subject, {
    String? body,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    // Strip CRLF dans les headers (anti mailto header injection).
    final safeSubject = subject.replaceAll(RegExp(r'[\r\n]'), ' ');
    final safeBody = body?.replaceAll(RegExp(r'\r\n?'), '\n');
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      queryParameters: <String, String>{
        'subject': safeSubject,
        'body': ?safeBody,
      },
    );
    // Idem _openUrl : on n'utilise plus canLaunchUrl (faux négatifs).
    // Si launchUrl jette ou retourne false, fallback clipboard.
    try {
      final ok = await launchUrl(uri);
      if (ok) return;
    } catch (_) {
      /* fall through */
    }
    await Clipboard.setData(ClipboardData(text: to));
    messenger.showSnackBar(
      SnackBar(content: Text('Aucune app mail. Adresse copiée : $to')),
    );
  }

  void _openLegal(
    BuildContext context, {
    required String title,
    required String asset,
  }) {
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
              // Idem _openUrl : pas de canLaunchUrl (faux négatifs Android 11+).
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {
                /* silent */
              }
            },
          );
        },
      ),
    );
  }
}
