/// Seuils performance partagés entre apps Files Tech.
///
/// Centralisés ici pour homogénéiser les décisions UX sur les low-end
/// (Redmi 9C 3GB, POCO C75 4GB) sans avoir à refaire des micro-benchmarks
/// dans chaque app.
abstract final class PerfThresholds {
  PerfThresholds._();

  /// Seuil au-delà duquel un parsing CPU-bound doit basculer en isolate.
  ///
  /// 1 Mo = bon compromis : en dessous c'est ~ms direct sur main thread,
  /// au-dessus le coût de setup d'un isolate (~80ms cold start) devient
  /// amorti par le gain de fluidité UI (60fps préservés pendant le parse).
  ///
  /// Callsites typiques : décodage CSV/JSON, parsing PDF métadonnées,
  /// conversion images → PDF, parsing markdown long.
  static const int isolateThreshold = 1 << 20; // 1 MiB

  /// Cap maximal pour les viewers texte (csv, json, md, html, xml, log).
  ///
  /// Au-delà : refus avec message d'erreur explicite ("fichier trop
  /// volumineux pour la prévisualisation"). Évite les OOM sur low-end où
  /// charger un .json de 200 Mo en string Dart explose le heap.
  ///
  /// Pour les viewers binaires (PDF, images), des caps spécifiques sont
  /// définis dans chaque app — la limite ici ne s'applique qu'au texte.
  static const int viewerMaxBytes = 50 << 20; // 50 MiB
}
