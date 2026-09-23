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
favoritesNotifierProvider = AsyncNotifierProvider<FavoritesNotifier,
    List<Favorite>>(FavoritesNotifier.new);

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
    final FavoriteRepository repository =
        ref.watch(favoriteRepositoryProvider);
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
  Future<void> toggleFavorite(String trackId) async {
    final FavoriteRepository repository =
        ref.read(favoriteRepositoryProvider);

    if (_favoriteIds.contains(trackId)) {
      await repository.removeFavorite(trackId);
      _favoriteIds.remove(trackId);
      state = state.when(
        data: (List<Favorite> data) {
          final List<Favorite> filtered = data
              .where((Favorite f) => f.trackId != trackId)
              .toList();
          return AsyncData(filtered);
        },
        loading: () => const AsyncData(<Favorite>[]),
        error: (_, _) => const AsyncData(<Favorite>[]),
      );
    } else {
      await repository.addFavorite(trackId);
      _favoriteIds.add(trackId);
      final Favorite newFavorite = Favorite(
        trackId: trackId,
        addedAt: DateTime.now(),
      );
      state = state.when(
        data: (List<Favorite> data) {
          final List<Favorite> updated = List<Favorite>.from(data)
            ..add(newFavorite);
          return AsyncData(updated);
        },
        loading: () => AsyncData(<Favorite>[newFavorite]),
        error: (_, _) => AsyncData(<Favorite>[newFavorite]),
      );
    }
  }
}

/// Bouton de favori : cœur vide ou rempli selon l'état.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.trackId,
    this.size = 32,
    this.onChanged,
  });

  final String trackId;
  final double size;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isFavorite = ref.watch(favoritesNotifierProvider).when(
          data: (List<Favorite> favorites) =>
              favorites.any((Favorite f) => f.trackId == trackId),
          loading: () => false,
          error: (_, _) => false,
        );

    return IconButton(
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: isFavorite
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.onSurfaceVariant,
        size: size,
      ),
      tooltip: isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
      onPressed: () {
        ref.read(favoritesNotifierProvider.notifier).toggleFavorite(trackId);
        onChanged?.call();
      },
    );
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

