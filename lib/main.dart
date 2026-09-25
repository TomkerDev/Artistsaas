import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app/artist_app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Obligatoire pour `JustAudioBackground.init`, qui doit s'acquitter avant le
  // premier `runApp` : le service natif de lecture en arrière-plan s'annonce au
  // système dès le démarrage.
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase alimente les nouveautés distantes (Firestore) et le panneau
  // d'administration (Auth + Storage). L'initialisation échoue silencieusement
  // lorsque aucune configuration n'est fournie : l'application continue avec le
  // seul catalogue embarqué, et le panneau admin affiche alors un message clair.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on Object {
    // Absence de configuration (`--dart-define=FIREBASE_*`) ou configuration
    // incomplète : le catalogue embarqué reste la base garantie.
  }
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.tomker.artistsaas.channel.audio',
    androidNotificationChannelName: 'Lecture musicale Novaa',
    androidNotificationChannelDescription:
        'Lecture de la musique de Dilson Le Mustang',
    // La notification doit rester dismissible : sa suppression appelle le
    // handler audio, qui appelle stop() et libère le lecteur just_audio.
    androidNotificationOngoing: false,
    // Un arrêt ou une pause quitte immédiatement le service foreground afin
    // que la notification de l'écran de verrouillage disparaisse sans attendre.
    androidStopForegroundOnPause: true,
  );
  // `ProviderScope` héberge le conteneur d'injection de dépendances. Les
  // implémentations concrètes (catalogue, moteur audio, téléchargements) y sont
  // déclarées à partir de l'étape 1, dans `lib/app/di/`.
  // Demande les autorisations Android (stockage média + notifications) au lancement.
  if (!kIsWeb) {
    await _requestPermissions();
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
