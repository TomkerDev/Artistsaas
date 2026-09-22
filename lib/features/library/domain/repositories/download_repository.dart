import '../../../catalog/domain/entities/track.dart';
import '../entities/download_progress.dart';
import '../entities/downloaded_track.dart';

/// Gestion des morceaux disponibles hors connexion.
///
/// Contrat de domaine : l'implémentation du MVP copie les fichiers embarqués
/// dans le stockage privé de l'application et les indexe dans une base locale.
/// Le jour où le catalogue exposera des URLs distantes, seule l'implémentation
/// changera : les contrats, les écrans et le lecteur resteront identiques.
abstract interface class DownloadRepository {
  /// Pistes matérialisées, réémises à chaque ajout ou suppression.
  ///
  /// L'écran « Ma musique » observe ce flux : une matérialisation terminée
  /// apparaît donc sans action manuelle de rafraîchissement.
  Stream<List<DownloadedTrack>> watchDownloadedTracks();

  /// État de matérialisation par identifiant de piste, progression incluse.
  ///
  /// Permet à l'interface d'afficher un indicateur par morceau et de distinguer
  /// « pas téléchargé », « en cours », « disponible » et « échec ».
  Stream<Map<String, DownloadProgress>> watchProgress();

  /// Démarre (ou reprend) la matérialisation locale de [track].
  ///
  /// Échoue avec une `DownloadException` si le fichier ne peut pas être écrit ;
  /// l'échec est également publié dans `watchProgress`.
  Future<void> download(Track track);

  /// Supprime la copie locale et sa trace ; sans effet si la piste est absente.
  Future<void> deleteDownload(String trackId);

  /// Chemin de la copie locale, ou `null` si la piste n'est pas matérialisée.
  ///
  /// Utilisé par la résolution des sources de lecture, qui privilégie le fichier
  /// local avant toute autre source.
  Future<String?> getLocalPath(String trackId);

  /// Identifiants des pistes déjà matérialisées localement.
  ///
  /// Lecture de l'index (SQLite) : permet de marquer `isDownloaded` sur les
  /// pistes du catalogue fusionné sans ouvrir un flux d'écoute.
  Future<Set<String>> getDownloadedTrackIds();
}
