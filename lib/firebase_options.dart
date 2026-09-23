import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Options d'initialisation de Firebase, résolues par plateforme.
///
/// En production, ce fichier est régénéré par la CLI officielle :
///
/// ```sh
/// dart pub global activate flutterfire_cli
/// flutterfire configure
/// ```
///
/// La commande remplace ce fichier par la configuration réelle du projet Firebase
/// (API keys, project id, app id par plateforme…). En attendant, une variante
/// pilotée par `--dart-define` est fournie pour éviter de committer des clés :
///
/// ```sh
/// flutter run --dart-define=FIREBASE_PROJECT_ID=mon-projet \
///   --dart-define=FIREBASE_API_KEY=AIza… \
///   --dart-define=FIREBASE_APP_ID=1:123:web:abc \
///   --dart-define=FIREBASE_MESSAGING_SENDER_ID=123 \
///   --dart-define=FIREBASE_STORAGE_BUCKET=mon-projet.appspot.com
/// ```
///
/// Sans configuration complète, [DefaultFirebaseOptions.currentPlatform] lève
/// une exception : `main()` l'absorbe et l'application démarre avec le seul
/// catalogue embarqué (les écrans admin affichent alors un message explicite).
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      TargetPlatform.macOS => macos,
      _ => throw UnsupportedError(
        'Plateforme Firebase non configurée : '
        'utilisez `flutterfire configure` pour la régénérer.',
      ),
    };
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_IOS_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_MACOS_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    iosBundleId: String.fromEnvironment('FIREBASE_MACOS_BUNDLE_ID'),
  );
}
