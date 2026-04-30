/// Code partagé entre les apps Files Tech (PDF Tech, Read Files Tech, Pass Tech).
///
/// Exports publics. À utiliser via `import 'package:files_tech_core/files_tech_core.dart';`.
library;

// Recents : liste des fichiers récemment ouverts (modèle + service).
export 'src/recents/recent_file.dart';
export 'src/recents/recent_files_service.dart';

// Update : vérification de mises à jour via GitHub Releases.
export 'src/update/update_service.dart';

// Share : rangée de boutons de partage cloud (kDrive / Google Drive / Proton Drive).
export 'src/share/cloud_share_row.dart';

// Legal : sections "Aide & support" + "Mentions légales" partagées.
export 'src/legal/legal_support_sections.dart';

// Utils : formatage humanisé + sécurité chemins.
export 'src/utils/format_utils.dart';
