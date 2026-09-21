import 'package:flutter/material.dart';

/// Thème Material 3 de l'application.
///
/// Le thème clair et le thème sombre sont tous deux définis ; le mode par défaut
/// est choisi dans `ArtistApp`.
abstract final class AppTheme {
  /// Couleur de marque provisoire, utilisée comme graine du `ColorScheme`.
  ///
  /// À remplacer par la couleur officielle de l'artiste dès que l'identité
  /// visuelle est disponible : c'est le seul point à modifier pour changer
  /// l'intégralité de la palette (clair et sombre).
  static const Color seedColor = Color(0xFF6C3BF4);

  /// Thème sombre : mode d'affichage par défaut de l'application.
  static ThemeData get dark => _build(Brightness.dark);

  /// Thème clair.
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
