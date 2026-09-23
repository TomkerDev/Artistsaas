import 'dart:typed_data';

/// Publication d'une nouveauté multi-artistes (audio + pochette + Firestore).
///
/// Contrat de domaine : l'écran d'upload ne connaît ni Firebase Storage ni
/// Firestore. [TrackUploadRequest] porte les méta-données et les octets à
/// téléverser ; l'implémentation choisit l'emplacement de stockage, le nom du
/// document et l'horodatage.
abstract interface class TrackPublisher {
  /// Téléverse la piste décrite par [request] et crée le document Firestore
  /// correspondant dans la collection `tracks`.
  ///
  /// Le flux produit de 0 à 100 : progression du seul téléversement du MP3
  /// (la création du document est quasi instantanée).
  ///
  /// Lève une `AdminException` si le téléversement ou l'écriture échoue ; dans
  /// ce cas le document Firestore n'est jamais créé (l'audio seul peut avoir
  /// été partiellement téléversé et sera remplacé à la prochaine tentative).
  Stream<int> publish(TrackUploadRequest request);
}

/// Demande de publication d'une nouveauté.
final class TrackUploadRequest {
  const TrackUploadRequest({
    required this.artistId,
    required this.artistName,
    required this.trackId,
    required this.title,
    required this.audioFileName,
    required this.audioBytes,
    this.album,
    this.trackNumber,
    this.releaseYear,
    this.coverFileName,
    this.coverBytes,
  });

  /// Identifiant de l'artiste ciblé (`artist_1`, `artist_2`, …).
  final String artistId;

  /// Nom de scène de l'artiste, tel qu'affiché dans l'application.
  final String artistName;

  /// Identifiant stable de la piste (base du nom de fichier et du document).
  final String trackId;

  /// Titre du morceau.
  final String title;

  /// Nom du fichier MP3 sélectionné (ex. `single-summer.mp3`).
  final String audioFileName;

  /// Contenu du MP3 compressé à téléverser.
  final Uint8List audioBytes;

  /// Album de rattachement, facultatif.
  final String? album;

  /// Position du morceau dans son album, facultative.
  final int? trackNumber;

  /// Année de publication, facultative.
  final int? releaseYear;

  /// Nom du fichier de pochette sélectionné, s'il y en a une.
  final String? coverFileName;

  /// Contenu de la pochette, s'il y en a une.
  final Uint8List? coverBytes;
}
