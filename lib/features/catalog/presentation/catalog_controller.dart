import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../domain/entities/track.dart';

/// État du catalogue musical affiché par l'écran d'accueil.
///
/// Le contrôleur ne connaît que l'interface `TrackRepository` (exposé par le
/// provider historique `musicRepositoryProvider`) : il ignore tout de la fusion
/// embarqué + nouveautés distantes + état local, qui appartient à `data/`.
final class CatalogController extends AsyncNotifier<List<Track>> {
  @override
  Future<List<Track>> build() {
    return ref.watch(musicRepositoryProvider).getTracks();
  }

  /// Relance la lecture du catalogue, par exemple depuis le bouton « Réessayer ».
  ///
  /// L'état repasse explicitement par le chargement afin que l'écran affiche de
  /// nouveau son indicateur de progression.
  Future<void> reload() async {
    state = const AsyncValue<List<Track>>.loading();
    state = await AsyncValue.guard(
      () => ref.read(musicRepositoryProvider).getTracks(),
    );
  }
}

/// Catalogue musical, sous forme d'état asynchrone (`loading`/`error`/`data`).
final AsyncNotifierProvider<CatalogController, List<Track>>
catalogControllerProvider =
    AsyncNotifierProvider<CatalogController, List<Track>>(
      CatalogController.new,
    );
