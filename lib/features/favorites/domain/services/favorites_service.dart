import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/favorite.dart';
import '../../domain/repositories/favorite_repository.dart';

/// Service métier des favoris.
///
/// Une abstraction par-dessus le repository pour ajouter d'éventuelles règles
/// métier (validation, événements, etc.). Pour le MVP, elle délégue directement
/// au repository.
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
