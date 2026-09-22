import 'package:flutter/material.dart';

/// Identité visuelle de la marque « NOVAA ».

///
/// Toutes les couleurs de l'interface dérivent de [seed] via
/// `ColorScheme.fromSeed` : modifier [seed] change l'intégralité de la palette
/// (clair et sombre). [accent] et [splashBackground] sont utilisés par
/// l'interface et le splash natif.
abstract final class AppColors {
  /// Couleur de marque : violet néon, graine du `ColorScheme`.
  static const Color seed = Color(0xFF6C3BF4);

  /// Accent d'activité : cyan électrique, réservé à l'état « en cours de
  /// lecture » (equalizer, barre de progression du mini-lecteur). Il distingue
  /// la marque (violet) de l'activité (cyan).
  static const Color accent = Color(0xFF00E5CC);

  /// Fond du splash natif, aligné sur le mode sombre par défaut.
  static const int splashBackground = 0xFF1A1024;
}
