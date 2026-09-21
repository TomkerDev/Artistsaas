import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/artist_app.dart';

void main() {
  // `ProviderScope` héberge le conteneur d'injection de dépendances. Les
  // implémentations concrètes (catalogue, moteur audio, téléchargements) y sont
  // déclarées à partir de l'étape 1, dans `lib/app/di/`.
  runApp(const ProviderScope(child: ArtistApp()));
}
