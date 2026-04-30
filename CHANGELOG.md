# Changelog

## 0.1.0 — 2026-04-30

Initial release. Code factorisé depuis PDF Tech v1.8.0, Read Files Tech
v2.5.6, Pass Tech v1.12.1.

### Ajouts

- `RecentFile` + `RecentFilesService` (parse défensif, auto-purge des
  entrées corrompues, async I/O)
- `UpdateService` + `UpdateInfo` avec cache 12h via SharedPreferences,
  validation regex semver de `tag_name`, whitelist hosts pour `apkUrl`
  (github.com / objects.githubusercontent.com), `force: true` pour bypass
  cache
- `CloudShareRow` widget paramétrable par `channelName`, avec catch
  `MissingPluginException` pour résilience hot-reload
- `CloudTargets` constants : `kDrive`, `googleDrive`, `protonDrive`,
  `pdfTech` (cross-app)
- `LegalSupportSections` widget avec whitelist schemes (https, http,
  mailto), refus `userInfo`, mailto CRLF-strip, assets MD configurables
- `FormatUtils.bytes` (style FR `Mo/Go`) et `FormatUtils.bytesStorage`
  (style EN `MB/GB`), guard valeurs négatives
- `PathSafe.basename`, `sanitizeFileName`, `sanitizeForFs`,
  `isValidUserFileName`

### Tests

14 tests unitaires (FormatUtils, PathSafe, RecentFile JSON round-trip,
formattedSize).
