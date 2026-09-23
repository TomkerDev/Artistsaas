import '../entities/favorite.dart';
import '../repositories/favorite_repository.dart';

/// Service métier des favoris.
///
/// Une abstraction par-dessus le repository pour ajouter d'éventuelles règles
/// métier (validation, événements, etc.). Pour le MVP, elle délègue directement
/// au repository.
abstract interface class FavoritesService {
  /// Renvoie la liste des favoris, dans l'ordre d'ajout.
  Future<List<Favorite>> getFavorites();

  /// Ajoute une piste aux favoris.
  Future<void> addFavorite(String trackId);

  /// Retire une piste des favoris.
  Future<void> removeFavorite(String trackId);

  /// `true` si la piste est actuellement favorie.
  Future<bool> isFavorite(String trackId);
}

/// Implémentation concrète déléguant au repository `sqflite`.
class LocalFavoritesService implements FavoritesService {
  const LocalFavoritesService(this._repository);

  final FavoriteRepository _repository;

  @override
  Future<List<Favorite>> getFavorites() => _repository.getFavorites();

  @override
  Future<void> addFavorite(String trackId) => _repository.addFavorite(trackId);

  @override
  Future<void> removeFavorite(String trackId) =>
      _repository.removeFavorite(trackId);

  @override
  Future<bool> isFavorite(String trackId) => _repository.isFavorite(trackId);
}
