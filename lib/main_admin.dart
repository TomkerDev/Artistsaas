import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin/admin_login_page.dart';
import 'admin/admin_store_page.dart';
import 'firebase_options.dart';
import 'services/supabase_storage_service.dart';

/// Point d'entrée du **panneau d'administration** (déploiement web).
///
/// Séparé de `main.dart` : l'application artiste distribuée n'embarque ni
/// les écrans d'upload ni les services d'administration dans sa racine.
///
/// Ce binaire est celui déployé sur Firebase Hosting :
/// ```sh
/// flutter build web --target lib/main_admin.dart
/// firebase deploy --only hosting
/// ```
///
/// Supabase Storage est initialisé en même temps que Firebase. Les clés sont
/// transmises au build via `--dart-define` :
/// ```sh
/// flutter build web --release \
///   --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ... \
///   --dart-define=FIREBASE_API_KEY=... \
///   ...
/// ```
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase (Auth + Firestore) — échoue silencieusement sans config.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on Object {
    // Configuration absente : l'écran de connexion affichera l'erreur.
  }

  // Supabase Storage (bucket `artist-media`, 5 Go gratuits).
  // Les valeurs proviennent de `--dart-define` ; elles sont `null` lorsque le
  // build a été compilé sans elles, auquel cas on n'initialise rien.
  final String? supabaseUrl = SupabaseStorageService.url;
  final String? supabaseKey = SupabaseStorageService.publishableKey;
  if (supabaseUrl != null && supabaseKey != null) {
    try {
      await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
    } on Object {
      // Supabase non configuré : les uploads afficheront l'erreur au premier
      // appel plutôt qu'au démarrage.
    }
  }

  runApp(const ProviderScope(child: AdminApp()));
}

/// Racine du panneau d'administration : thème sombre et écran de connexion.
class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NOVAA — Administration',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.dark,
      locale: const Locale('fr'),
      supportedLocales: const <Locale>[Locale('fr')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routes: {
        '/admin/login': (context) => const AdminLoginPage(),
        '/admin/upload': (context) => const AdminShell(),
        '/admin/store': (context) => const AdminStorePageOnly(),
      },
      home: const AdminLoginPage(),
    );
  }
}
