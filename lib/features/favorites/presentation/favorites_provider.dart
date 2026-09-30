import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../platform/services/share_service.dart';
import '../../player/domain/entities/playback_media.dart';
import '../domain/entities/favorite.dart';
import '../domain/repositories/favorite_repository.dart';

/// Contrôleur Riverpod des favoris : état observé par l'interface et commandes
/// pour ajouter / retirer un favori.
final AsyncNotifierProvider<FavoritesNotifier, List<Favorite>>
    favoritesNotifierProvider =
    AsyncNotifierProvider<FavoritesNotifier, List<Favorite>>(
        FavoritesNotifier.new);

/// Identifiants des pistes favorisées, dérivés de l'état asynchrone pour un
/// accès synchrone O(1) depuis l'interface (lecteur, catalogue).
final Provider<Set<String>> favoriteIdsProvider = Provider<Set<String>>((
  Ref ref,
) {
  final AsyncValue<List<Favorite>> state = ref.watch(
    favoritesNotifierProvider,
  );
  return state.valueOrNull?.map((Favorite f) => f.trackId).toSet() ??
      const <String>{};
});

class FavoritesNotifier extends AsyncNotifier<List<Favorite>> {
  /// Identifiants des pistes favorisées, par ID de piste pour une recherche
  /// en O(1).
  final Set<String> _favoriteIds = <String>{};

  /// Chargement initial : récupère les favoris du stockage.
  @override
  Future<List<Favorite>> build() async {
    final FavoriteRepository repository = ref.watch(favoriteRepositoryProvider);
    final List<Favorite> favorites = await repository.getFavorites();
    _favoriteIds.clear();
    for (final Favorite favorite in favorites) {
      _favoriteIds.add(favorite.trackId);
    }
    return favorites;
  }

  /// `true` si la piste donnée est actuellement favorie.
  bool isFavorite(String trackId) => _favoriteIds.contains(trackId);

  /// Ajoute ou retire une piste des favoris.
  ///
  /// La bascule est **optimiste** : l'état observé par l'interface (et donc le
  /// cœur du bouton) change à l'instant du tap, avant la persistance. Si le
  /// stockage refuse l'écriture, l'état précédent est restauré puis l'erreur est
  /// relancée — l'appelant (le bouton) l'affiche dans un `SnackBar`.
  Future<void> toggleFavorite(String trackId) async {
    final FavoriteRepository repository = ref.read(favoriteRepositoryProvider);
    final bool wasFavorite = _favoriteIds.contains(trackId);
    final List<Favorite> before = state.valueOrNull ?? const <Favorite>[];

    if (wasFavorite) {
      _favoriteIds.remove(trackId);
      state = AsyncData(
        before.where((Favorite f) => f.trackId != trackId).toList(),
      );
    } else {
      final Favorite newFavorite = Favorite(
        trackId: trackId,
        addedAt: DateTime.now(),
      );
      _favoriteIds.add(trackId);
      state = AsyncData(<Favorite>[...before, newFavorite]);
    }

    try {
      if (wasFavorite) {
        await repository.removeFavorite(trackId);
      } else {
        await repository.addFavorite(trackId);
      }
    } on Object {
      // Persistance refusée : le cœur redevient cohérent avec le stockage.
      if (wasFavorite) {
        _favoriteIds.add(trackId);
      } else {
        _favoriteIds.remove(trackId);
      }
      state = AsyncData(before);
      rethrow;
    }
  }
}

/// Bouton de partage via le service de partage.
class ShareButton extends ConsumerWidget {
  const ShareButton({
    super.key,
    required this.media,
    this.size = 24,
  });

  final PlaybackMedia media;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(
        Icons.share,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: size,
      ),
      tooltip: 'Partager ce morceau',
      onPressed: () {
        final ShareService service = ref.read(shareServiceProvider);
        service.shareTrack(media);
      },
    );
  }
}
