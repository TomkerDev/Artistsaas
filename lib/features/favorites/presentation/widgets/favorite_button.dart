import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/favorite.dart';
import '../favorites_provider.dart';

/// Bouton de favori : cœur vide ou rempli selon l'état.
///
/// Le widget observe les favoris via Riverpod et déclenche le changement en
/// appuyant sur le bouton. La bascule de l'icône est immédiate (état
/// optimiste géré par `FavoritesNotifier`) et un `SnackBar` confirme
/// l'ajout / le retrait ; si la persistance locale échoue, l'état est
/// restauré et l'erreur affichée.
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
          data: (List<Favorite> favorites) =>
              favorites.any((Favorite f) => f.trackId == trackId),
          loading: () => false,
          error: (_, __) => false,
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
      onPressed: () async {
        try {
          await ref
              .read(favoritesNotifierProvider.notifier)
              .toggleFavorite(trackId);
        } on Object catch (error) {
          if (!context.mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error is AppException
                    ? error.message
                    : "Le favori n'a pas pu être enregistré.",
              ),
            ),
          );
          return;
        }
        onChanged?.call();
        if (!context.mounted) {
          return;
        }
        // `isFavorite` reflète l'état d'avant le tap : s'il était favori, la
        // bascule vient donc de le retirer.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFavorite ? 'Retiré des favoris' : 'Ajouté aux favoris',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      },
    );
  }
}
