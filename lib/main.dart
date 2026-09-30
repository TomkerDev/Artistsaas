import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app/artist_app.dart';
import 'app/config/app_config.dart';
import 'features/ads/services/ads_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Obligatoire pour `JustAudioBackground.init`, qui doit s'acquitter avant le
  // premier `runApp` : le service natif de lecture en arrière-plan s'annonce au
  // système dès le démarrage.
  WidgetsFlutterBinding.ensureInitialized();

  // Journalisation des erreurs fatales. Sans ces handlers, une exception en
  // release tue le processus sans trace dans `adb logcat` : impossible de
  // comprendre pourquoi « l'application se ferme à l'ouverture ». On redirige
  // tout vers la console, puis on laisse Flutter afficher son écran d'erreur.
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('FlutterError : ${details.exceptionAsString()}');
    FlutterError.presentError(details);
  };
  // Exceptions asynchrones non rattrapées : retourner `true` empêche la
  // termination du processus — l'application reste ouverte et l'erreur est
  // journalisée.
  ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Erreur fatale non rattrapée : $error\n$stack');
    return true;
  };

  // Firebase alimente les nouveautés distantes (Firestore) et le panneau
  // d'administration (Auth + Storage). L'initialisation échoue silencieusement
  // lorsque aucune configuration n'est fournie : l'application continue avec le
  // seul catalogue embarqué, et le panneau admin affiche alors un message clair.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on Object catch (error) {
    // Absence de configuration (`--dart-define=FIREBASE_*`) ou configuration
    // incomplète : le catalogue embarqué reste la base garantie.
    debugPrint('Firebase indisponible au démarrage : $error');
  }

  // Chaque initialisation est isolée : une dépendance native défaillante
  // (plugin audio, AdMob, permissions) ne doit jamais empêcher `runApp` —
  // c'était la cause directe de la fermeture immédiate de l'APK. L'application
  // démarre en mode dégradé et journalise l'erreur.
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.tomker.artistsaas.channel.audio',
      androidNotificationChannelName: 'Lecture musicale Novaa',
      // Le nom de l'artiste vient du registre (`--dart-define=ARTIST_ID=…`) : une
      // chaîne codée en dur afficherait l'artiste d'un autre build dans les
      // réglages de notification Android.
      androidNotificationChannelDescription:
          'Lecture de la musique de ${AppConfig.artist.stageName}',
      // La notification doit rester dismissible : sa suppression appelle le
      // handler audio, qui appelle stop() et libère le lecteur just_audio.
      // Le bouton stop (X) de la notification est fourni automatiquement par
      // `just_audio_background` (MediaControl.stop, visible dans la
      // notification développée) : son action remet le moteur à l'état
      // `idle`, état que `JustAudioPlayerService` traduit en file vidée — le
      // mini-lecteur et l'écran du lecteur se ferment alors comme pour un
      // arrêt local.
      androidNotificationOngoing: false,
      // Un arrêt ou une pause quitte immédiatement le service foreground afin
      // que la notification de l'écran de verrouillage disparaisse sans attendre.
      androidStopForegroundOnPause: true,
    );
  } on Object catch (error) {
    debugPrint('JustAudioBackground indisponible, lecture limitée : $error');
  }

  // Google Mobile Ads. Sans identifiants injectés, l'initialisation est un
  // no-op : un build de développement démarre sans annonce.
  try {
    await AdsService.initialize();
  } on Object catch (error) {
    debugPrint('AdMob indisponible, application sans publicité : $error');
  }

  // `ProviderScope` héberge le conteneur d'injection de dépendances. Les
  // implémentations concrètes (catalogue, moteur audio, téléchargements) y sont
  // déclarées à partir de l'étape 1, dans `lib/app/di/`.
  // Demande les autorisations Android (stockage média + notifications) au lancement.
  if (!kIsWeb) {
    try {
      await _requestPermissions();
    } on Object catch (error) {
      debugPrint('Autorisations Android refusées ou indisponibles : $error');
    }
  }
  runApp(const ProviderScope(child: ArtistApp()));
}

/// Demande les autorisations Android requises au lancement :
/// - [Permission.mediaLibrary] → accès aux fichiers audio
///   (READ_MEDIA_AUDIO sur Android 13+, READ_EXTERNAL_STORAGE sinon)
/// - [Permission.notification] → notifications de lecture en arrière-plan
///   (POST_NOTIFICATIONS sur Android 13+)
Future<void> _requestPermissions() async {
  await [Permission.mediaLibrary, Permission.notification].request();
}
