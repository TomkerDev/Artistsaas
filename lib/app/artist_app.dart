import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/constants/app_strings.dart';
import 'shell/home_shell.dart';
import 'theme/app_theme.dart';

/// Racine de l'application : thème, langue et écran d'entrée.
class ArtistApp extends StatelessWidget {
  const ArtistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Univers musical : affichage sombre par défaut, thème clair disponible.
      themeMode: ThemeMode.dark,
      locale: const Locale('fr'),
      supportedLocales: const <Locale>[Locale('fr')],
      // Fournit les libellés Material/Cupertino en français (accessibilité,
      // menus système, sélecteurs de date, etc.).
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeShell(),
    );
  }
}
