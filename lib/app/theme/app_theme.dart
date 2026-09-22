import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Thème Material 3 de l'application.
///
/// Le thème clair et le thème sombre sont tous deux définis ; le mode par défaut
/// est choisi dans `ArtistApp`.
abstract final class AppTheme {
  /// Thème sombre : mode d'affichage par défaut de l'application.
  static ThemeData get dark => _build(Brightness.dark);

  /// Thème clair.
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );

    final TextTheme textTheme = _textTheme(colorScheme);

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
            progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
    );
  }

  /// Hiérarchie typographique de la marque : titres affirmés, espacement
  /// régulier des majuscules, corps de texte inchangé.
  ///
  /// La famille de polices reste celle de la plateforme (Roboto sur Android) :
  /// aucune ressource typographique sous licence n'est embarquée.
  static TextTheme _textTheme(ColorScheme colorScheme) {
    final Color titleColor = colorScheme.onSurface;
    return TextTheme(
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: titleColor,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: colorScheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: colorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: colorScheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: colorScheme.onSurfaceVariant,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        letterSpacing: 0.4,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
