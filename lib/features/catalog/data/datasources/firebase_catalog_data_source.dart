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
  FirebaseCatalogDataSource({FirebaseFirestore? firestore, this.limit = 500})
      : _firestore = firestore;

  /// Nombre maximal de morceaux récupérés en une passe.
  ///
  /// Pour une application « 100 % audio », Firestore est la source *unique* :
  /// la limite doit donc couvrir l'intégralité du catalogue, et pas seulement
  /// les dernières nouveautés. 500 couvre largement un catalogue tout en
  /// restant raisonnable ; la requête s'appuie sur l'index composite
  /// `artistId ASC / createdAt DESC` (voir `firestore.indexes.json`).
  final int limit;

  final FirebaseFirestore? _firestore;

  /// Collection Firestore des pistes publiées.
  static const String collection = 'tracks';

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Track>> fetchNewTracks(String artistId) async {
    try {
      // Le tri est délégué à Firestore (`orderBy('createdAt')`) afin que les
      // nouveautés fraîchement publiées par le panneau Web remontent en tête
      // de liste. L'index composite `artistId ASC / createdAt DESC` déclaré
      // dans `firestore.indexes.json` rend cette requête serveur possible ;
      // sans `orderBy`, Firestore renvoyait les documents dans un ordre
      // arbitraire et le nouveau morceau « Test » se retrouvait noyé en fin
      // de liste. Le filtre `artistId` est conservé : l'application est
      // cloisonnée par artiste (une build par artiste), et l'`artistId`
      // enregistré par l'admin doit correspondre au `--dart-define=ARTIST_ID`
      // du build mobile.
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _db
          .collection(collection)
          .where('artistId', isEqualTo: artistId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final List<Track> tracks = <Track>[
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs)
          _toTrack(doc),
      ];

      // Filet de sécurité côté client : Firestore ordonne déjà par `createdAt`
      // décroissant, mais on conserve un tri local stable au cas où certains
      // documents seraient dépourvus d'horodatage (ils passent alors en fin de
      // liste, comme avant).
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
  ///
  /// Le `Timestamp` Firestore (`created_at` / `createdAt`) est normalisé en
  /// millisecondes depuis l'epoch avant d'alimenter [Track.fromJson], afin que
  /// l'entité de domaine dépende d'un type Dart standard et non de
  /// `cloud_firestore`.
  Track _toTrack(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> json = <String, dynamic>{...doc.data()};
    json['id'] = (json['id'] as String?)?.trim().isNotEmpty == true
        ? json['id']
        : doc.id;
    json['is_new'] = json['is_new'] ?? true;
    json['created_at'] =
        _normalizeTimestamp(json['created_at'] ?? json['createdAt']);
    return Track.fromJson(json);
  }

  /// Convertit une valeur d'horodatage Firestore en millisecondes epoch.
  ///
  /// Accepte un `Timestamp` Firestore (champ `created_at` / `createdAt` écrit
  /// côté serveur) ou un nombre déjà exprimé en millisecondes. Renvoie `null`
  /// si la valeur est absente ou d'un type inattendu : le tri se contentera
  /// alors de replacer la piste en fin de liste.
  static int? _normalizeTimestamp(Object? value) {
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  static int _mostRecentFirst(Track a, Track b) {
    // Tri par date de création décroissante ; les pistes sans horodatage
    // (catalogue embarqué) conservent un repli stable sur `release_year`,
    // puis passent en fin de liste.
    final DateTime? dateA = a.createdAt;
    final DateTime? dateB = b.createdAt;
    if (dateA != null && dateB != null) {
      final int byDate = dateB.compareTo(dateA);
      if (byDate != 0) {
        return byDate;
      }
    } else if (dateA != null) {
      return -1;
    } else if (dateB != null) {
      return 1;
    }
    final int yearA = a.releaseYear ?? 0;
    final int yearB = b.releaseYear ?? 0;
    return yearB.compareTo(yearA);
  }
}
