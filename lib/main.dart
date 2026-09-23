import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

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
    androidNotificationOngoing: false,
    androidStopForegroundOnPause: true,
  );
  // `ProviderScope` héberge le conteneur d'injection de dépendances. Les
  // implémentations concrètes (catalogue, moteur audio, téléchargements) y sont
  // déclarées à partir de l'étape 1, dans `lib/app/di/`.
  runApp(const ProviderScope(child: ArtistApp()));
}
