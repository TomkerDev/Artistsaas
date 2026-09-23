import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/favorite.dart';
import '../favorites_provider.dart';

/// Bouton de favori : cœur vide ou rempli selon l'état.
///
/// Le widget observe les favoris via Riverpod et déclenche le changement en
/// appuyant sur le bouton.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.trackId,
    this.size = 32,
    this.onChanged,
  });

  /// Identifiant de la piste.
  final String trackId;

  /// Taille de l'icône.
  final double size;

  /// Rappel appelé après le changement d'état (désormais favori ou plus).
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isFavorite = ref.watch(favoritesNotifierProvider).when(
          data: (List<Favorite> favorites) => favorites
              .any((Favorite f) => f.trackId == trackId),
          loading: () => false,
          error: (_, _) => false,
        );

    return IconButton(
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: isFavorite
            ? Theme.of(context).colorScheme.onSurface.withAlpha(255)
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
