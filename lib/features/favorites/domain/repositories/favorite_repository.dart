import '../entities/favorite.dart';

/// Accès à la collection des favoris.
///
/// Contrat de domaine : l'implémentation du MVP persiste les favoris dans
/// une base `sqflite`. Une implémentation distante ou en mémoire pourrait la
/// remplacer sans qu'aucun écran n'ait à changer.
abstract interface class FavoriteRepository {
  /// Renvoie la liste des pistes favorisées, dans l'ordre d'ajout (plus récent
  /// en dernier).
  ///
  /// Échoue avec une `FavoriteException` si le stockage est inaccessible.
  Future<List<Favorite>> getFavorites();

  /// Ajoute une piste aux favoris.
  ///
  /// Si la piste est déjà favorie, l'appel est sans effet (idempotent).
  /// Échoue avec une `FavoriteException` si le stockage est inaccessible.
  Future<void> addFavorite(String trackId);

  /// Retire une piste des favoris.
  ///
  /// Si la piste n'est pas favorie, l'appel est sans effet (idempotent).
  /// Échoue avec une `FavoriteException` si le stockage est inaccessible.
  Future<void> removeFavorite(String trackId);

  /// `true` si la piste est actuellement favorie.
  ///
  /// Échoue avec une `FavoriteException` si le stockage est inaccessible.
  Future<bool> isFavorite(String trackId);
}
