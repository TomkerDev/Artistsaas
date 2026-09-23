import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/admin/presentation/admin_login_page.dart';
import 'firebase_options.dart';

/// Point d'entrée du **panneau d'administration** (déploiement web).
///
/// Séparé de `main.dart` : l'application artiste distribuée n'embarque ni
/// les écrans d'upload ni les services d'administration dans sa racine. Ce
/// binaire est celui déployé sur Firebase Hosting :
///
/// ```sh
/// flutter build web --target lib/main_admin.dart
/// firebase deploy --only hosting
/// ```
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on Object {
    // Configuration absente (`--dart-define=FIREBASE_*`) : l'écran de connexion
    // affiche l'erreur plutôt qu'un écran figé.
  }
  runApp(const ProviderScope(child: AdminApp()));
}
