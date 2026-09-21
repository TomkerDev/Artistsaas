import '../../../../core/errors/app_exception.dart';
import '../../domain/datasources/catalog_data_source.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/music_repository.dart';

/// Catalogue lu auprès d'une source brute, puis conservé en mémoire.
///
/// Le contenu embarqué ne change pas pendant l'exécution de l'application : la
/// première lecture est donc mise en cache. La *future* est mémorisée (et non le
/// résultat) afin que deux appels simultanés ne déclenchent qu'une seule lecture.
///
/// Un échec n'est jamais conservé : le bouton « Réessayer » de l'écran d'accueil
/// doit pouvoir relancer une lecture réelle.
class MusicRepositoryImpl implements MusicRepository {
  MusicRepositoryImpl(this._dataSource);

  final CatalogDataSource _dataSource;

  Future<List<Track>>? _cache;

  @override
  Future<List<Track>> getTracks() => _cache ??= _load();

  Future<List<Track>> _load() async {
    try {
      final List<Track> tracks = await _dataSource.fetchTracks();
      return List<Track>.unmodifiable(tracks);
    } on CatalogException {
      _cache = null;
      rethrow;
    }
  }
}
