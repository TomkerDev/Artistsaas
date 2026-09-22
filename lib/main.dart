import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app/artist_app.dart';

Future<void> main() async {
  // Obligatoire pour `JustAudioBackground.init`, qui doit s'acquitter avant le
  // premier `runApp` : le service natif de lecture en arrière-plan s'annonce au
  // système dès le démarrage.
  WidgetsFlutterBinding.ensureInitialized();
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
