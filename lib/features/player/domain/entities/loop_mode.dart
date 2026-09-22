/// Modes de lecture en boucle, indépendants de la bibliothèque audio.
///
/// Ce type appartient au domaine : l'interface et le service concret traduisent
/// ces valeurs dans l'API de `just_audio` (`LoopMode.off / .all / .one`).
enum LoopMode {
  /// Lecture normale, sans répétition.
  off,
  /// Répéter l'intégralité de la file.
  all,
  /// Répéter la piste en cours.
  one,
}
