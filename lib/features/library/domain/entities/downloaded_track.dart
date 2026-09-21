import '../../../catalog/domain/entities/track.dart';

/// Piste effectivement disponible hors connexion sur l'appareil.
///
/// Associe l'entité du catalogue aux informations de la copie locale, ce qui
/// permet à l'écran « Ma musique » d'afficher un morceau téléchargé sans
/// dépendre du catalogue complet.
class DownloadedTrack {
  const DownloadedTrack({
    required this.track,
    required this.localPath,
    required this.fileSizeBytes,
    required this.downloadedAt,
  });

  /// Piste d'origine.
  final Track track;

  /// Chemin absolu du fichier local.
  final String localPath;

  /// Taille du fichier sur le disque.
  final int fileSizeBytes;

  /// Date de la matérialisation locale.
  final DateTime downloadedAt;

  /// Identifiant de la piste, raccourci d'accès.
  String get trackId => track.id;

  @override
  bool operator ==(Object other) {
    return other is DownloadedTrack &&
        other.track == track &&
        other.localPath == localPath &&
        other.fileSizeBytes == fileSizeBytes &&
        other.downloadedAt == downloadedAt;
  }

  @override
  int get hashCode =>
      Object.hash(track, localPath, fileSizeBytes, downloadedAt);

  @override
  String toString() =>
      'DownloadedTrack(${track.id}, $localPath, $fileSizeBytes octets)';
}
