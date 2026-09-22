import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/datasources/remote_catalog_data_source.dart';
import '../../domain/entities/track.dart';

/// Nouveautés distantes d'un artiste, lues dans la collection Firestore
/// `tracks`.
///
/// Chaque artiste dispose de sa propre collection logique : les documents
/// portent un champ `artistId` et ne sont renvoyés que pour l'identifiant
/// demandé, ce qui évite de télécharger le catalogue des autres artistes.
///
/// L'instance [FirebaseFirestore] est injectable : les tests fournissent un
/// double, et la production utilise [FirebaseFirestore.instance] après
/// l'initialisation de Firebase dans `main()`.
class FirebaseCatalogDataSource implements RemoteCatalogDataSource {
  FirebaseCatalogDataSource({FirebaseFirestore? firestore, this.limit = 15})
    : _firestore = firestore;

  /// Nombre maximal de nouveautés récupérées en une passe.
  final int limit;

  final FirebaseFirestore? _firestore;

  /// Collection Firestore des pistes publiées.
  static const String collection = 'tracks';

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Track>> fetchNewTracks(String artistId) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _db
              .collection(collection)
              .where('artistId', isEqualTo: artistId)
              .limit(limit)
              .get();

      final List<Track> tracks = <Track>[
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs)
          _toTrack(doc),
      ];

      // Les documents Firestore n'imposent pas d'ordre : on trie côté client
      // sur `created_at` lorsqu'il est fourni, les plus récents d'abord.
      tracks.sort(_mostRecentFirst);
      return List<Track>.unmodifiable(tracks);
    } on CatalogException {
      rethrow;
    } on Object catch (error) {
      throw CatalogException(
        'Impossible de récupérer les nouveautés de « $artistId ».',
        cause: error,
      );
    }
  }

  /// Convertit un document Firestore en piste de domaine.
  ///
  /// Le document peut porter un `id` explicite ; à défaut, l'identifiant du
  /// document fait foi. Les nouveautés distantes sont marquées `isNew` par
  /// défaut : c'est leur raison d'être dans ce flux.
  Track _toTrack(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> json = <String, dynamic>{...doc.data()};
    json['id'] = (json['id'] as String?)?.trim().isNotEmpty == true
        ? json['id']
        : doc.id;
    json['is_new'] = json['is_new'] ?? true;
    return Track.fromJson(json);
  }

  static int _mostRecentFirst(Track a, Track b) {
    // Tri stable sur `release_year` faute d'horodatage normalisé dans le
    // domaine ; les pistes sans année passent en fin de liste.
    final int yearA = a.releaseYear ?? 0;
    final int yearB = b.releaseYear ?? 0;
    return yearB.compareTo(yearA);
  }
}