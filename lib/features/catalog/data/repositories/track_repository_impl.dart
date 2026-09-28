import '../../../../app/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../library/domain/repositories/download_repository.dart';
import '../../domain/datasources/catalog_data_source.dart';
import '../../domain/datasources/remote_catalog_data_source.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/track_repository.dart';

/// Fusion du catalogue embarqué, des nouveautés distantes et de l'état local.
///
/// Déroulé d'une lecture :
/// 1. les **morceaux embarqués** (`catalog.json`) sont chargés ; ils constituent
///    la base stable livrée avec l'application ;
/// 2. les **nouveautés distantes** (Firestore) sont récupérées pour l'artiste
///    courant ; leur indisponibilité n'interrompt jamais la lecture ;
/// 3. l'**état local** (SQLite) est interrogé une fois pour marquer les pistes
///    déjà téléchargées (`isDownloaded`).
///
/// Les doublons éventuels (une nouveauté déjà embarquée lors d'une mise à jour)
/// sont écartés au profit de la version embarquée, et les nouveautés sont
/// placées en tête de liste pour être visibles immédiatement.
///
/// La *future* est mémorisée (et non le résultat) afin que deux appels
/// simultanés ne déclenchent qu'une seule lecture ; un échec du catalogue
/// embarqué n'est jamais conservé, pour que « Réessayer » relance une lecture
/// réelle.
class TrackRepositoryImpl implements TrackRepository {
  TrackRepositoryImpl({
    required CatalogDataSource local,
    required RemoteCatalogDataSource remote,
    required DownloadRepository downloads,
    required String artistId,
    bool? streamOnly,
  })  : _local = local,
        _remote = remote,
        _downloads = downloads,
        _artistId = artistId,
        _streamOnly = streamOnly ?? AppConfig.streamOnly;

  final CatalogDataSource _local;
  final RemoteCatalogDataSource _remote;
  final DownloadRepository _downloads;
  final String _artistId;

  /// Application « 100 % audio » : Firestore est la source unique.
  ///
  /// Injectable pour les tests — la valeur de production vient du build
  /// (`--dart-define=STREAM_ONLY=true`, voir `AppConfig.streamOnly`).
  final bool _streamOnly;

  Future<List<Track>>? _cache;

  @override
  Future<List<Track>> getTracks() => _cache ??= _load();

  Future<List<Track>> _load() async {
    try {
      final List<Track> embedded =
          _streamOnly ? const <Track>[] : await _local.fetchTracks();
      final Set<String> downloaded = await _downloads.getDownloadedTrackIds();
      final List<Track> newTracks = await _fetchNewTracks();

      final Set<String> embeddedIds = <String>{
        for (final Track track in embedded) track.id,
      };

      final List<Track> merged = <Track>[
        // Les nouveautés distantes passent en tête de liste.
        for (final Track track in newTracks)
          if (!embeddedIds.contains(track.id)) track,
        ...embedded,
      ];

      // L'état local est appliqué en dernier : il prime sur tout marqueur
      // provenant du catalogue (JSON embarqué ou Firestore).
      return List<Track>.unmodifiable(<Track>[
        for (final Track track in merged)
          track.copyWith(isDownloaded: downloaded.contains(track.id)),
      ]);
    } on CatalogException {
      _cache = null;
      rethrow;
    }
  }

  /// Récupère les morceaux distants, en absorbant les erreurs réseau.
  ///
  /// Deux régimes :
  /// - **catalogue embarqué actif** (application classique) : la source
  ///   distante est un complément ; son indisponibilité ne doit pas priver
  ///   l'utilisateur de l'œuvre livrée dans l'APK, l'erreur est donc absorbée ;
  /// - **100 % audio** (`_streamOnly`) : Firestore est la *seule*
  ///   source. Absorber l'erreur afficherait un catalogue vide sans explication,
  ///   donc l'erreur remonte à l'écran, qui propose « Réessayer ».
  Future<List<Track>> _fetchNewTracks() async {
    try {
      return await _remote.fetchNewTracks(_artistId);
    } on Object {
      if (_streamOnly) {
        rethrow;
      }
      return const <Track>[];
    }
  }
}
