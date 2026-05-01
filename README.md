# files_tech_core

[![CI](https://github.com/gitubpatrice/files_tech_core/actions/workflows/ci.yml/badge.svg)](https://github.com/gitubpatrice/files_tech_core/actions/workflows/ci.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter)](https://flutter.dev)

Code partagé entre les apps Files Tech (PDF Tech, Read Files Tech, Pass Tech).
Package local Flutter (path-dependency) — **non publié sur pub.dev**.

## Contenu

| Module | Rôle |
|---|---|
| `RecentFile` + `RecentFilesService` | Liste des fichiers récents persistée dans `SharedPreferences`, robuste aux entrées corrompues |
| `UpdateService` + `UpdateInfo` | Vérification de mises à jour via GitHub Releases, cache 12h, validation semver + host whitelist |
| `CloudShareRow` + `CloudTargets` | Boutons de partage cloud (kDrive, Google Drive, Proton Drive) via MethodChannel |
| `LegalSupportSections` | Sections "Aide & support" + "Mentions légales" avec whitelist de schemes (anti `intent:`/`javascript:`) |
| `FormatUtils` | Formatage humanisé d'octets (`bytes` style FR, `bytesStorage` style EN) |
| `PathSafe` | Validation et sanitisation de noms de fichiers (anti path-traversal) |

## Usage

Ajouter dans le `pubspec.yaml` de l'app consommatrice :

```yaml
dependencies:
  files_tech_core:
    path: ../files_tech_core
```

### RecentFiles

```dart
import 'package:files_tech_core/files_tech_core.dart';

final svc = RecentFilesService();
List<RecentFile> recents = await svc.load();
recents = await svc.addOrUpdate(recents, '/storage/emulated/0/Download/foo.pdf');
```

### UpdateService

Configurer un singleton par app :

```dart
// app/lib/services/app_update.dart
const appUpdateService = UpdateService(
  owner: 'gitubpatrice',
  repo: 'PDF-TECH',
  currentVersion: '1.8.0',
);

// Usage
final info = await appUpdateService.checkForUpdate();
final manualCheck = await appUpdateService.checkForUpdate(force: true);
```

### CloudShareRow

Wrapper per-app pour injecter le nom de channel :

```dart
// app/lib/widgets/cloud_share_row.dart
import 'package:files_tech_core/files_tech_core.dart' as core;

class CloudShareRow extends StatelessWidget {
  final String path;
  const CloudShareRow({super.key, required this.path});
  @override
  Widget build(BuildContext context) => core.CloudShareRow(
    path: path,
    channelName: 'com.pdftech.pdf_tech/share',
    alignment: WrapAlignment.center,
  );
}
```

Côté Kotlin, le channel doit exposer `sendToPackage` qui prend `path`, `mime`, `package`.

### LegalSupportSections

```dart
const LegalSupportSections(
  appName: 'PDF Tech',
  version: '1.8.0',
)
```

L'app consommatrice doit déclarer dans son `pubspec.yaml` :

```yaml
flutter:
  assets:
    - assets/legal/PRIVACY.fr.md
    - assets/legal/TERMS.fr.md
```

Override possible des chemins via `privacyAsset` / `termsAsset`, et de
`contactEmail` / `websiteUrl` si nécessaire.

### FormatUtils

```dart
FormatUtils.bytes(1500);        // → "1.5 Ko"  (FR)
FormatUtils.bytesStorage(1500); // → "1.5 KB"  (EN, MB sans décimale)
```

### PathSafe

```dart
PathSafe.basename('/foo/bar.pdf');         // → "bar.pdf"
PathSafe.basename('..');                   // → throws ArgumentError
PathSafe.sanitizeFileName('my:file*.txt'); // → "my_file_.txt"
PathSafe.sanitizeForFs('hello world');     // → "hello_world" (variante FS-safe)
PathSafe.isValidUserFileName('foo.pdf');   // → true
```

## Sécurité

- Pas de secret hardcodé
- HTTPS uniquement (`api.github.com`)
- Schemes autorisés dans les liens : `https`, `http`, `mailto` (refus de `intent:`, `javascript:`, `file:`, etc.)
- Refus des URIs avec `userInfo` (anti credential phishing)
- `LaunchMode.externalApplication` (pas de browser-in-app)
- `RecentFilesService.load` filtre silencieusement les entrées corrompues (anti DoS)
- `UpdateService` valide `tag_name` en regex semver et whitelist le host de l'APK (`github.com` / `objects.githubusercontent.com`)
- `mailto` strip CRLF (anti header injection)

## Tests

```bash
flutter test
```

## Conventions

- Versions des apps doivent rester synchronisées entre `pubspec.yaml`,
  `AboutScreen._version` et `app_update.dart` `currentVersion`.
- Les channels Kotlin sont par-app (`com.pdftech.pdf_tech/share`,
  `com.readfilestech/open_file`, etc.) — déclarés dans le wrapper local.
