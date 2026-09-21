import '../../../catalog/domain/entities/track.dart';
import '../entities/playback_media.dart';

/// Traduit une piste du catalogue en élément prêt à être joué.
///
/// C'est ici — et non dans le moteur audio — que vit la règle de priorité des
/// sources, ordre qui rend le téléchargement utile puisqu'il est consulté avant
/// le bundle :
/// 1. la copie locale, si la piste a déjà été matérialisée (écoute hors
///    connexion) ;
/// 2. la source distante, si le catalogue en fournit une ;
/// 3. l'audio embarqué dans le bundle de l'application.
///
/// Le moteur audio reste ainsi totalement ignorant du catalogue et des
/// téléchargements : il ne reçoit qu'une `PlaybackSource`.
abstract interface class PlaybackSourceResolver {
  /// Renvoie l'élément de lecture à utiliser pour [track].
  ///
  /// Échoue avec une `PlaybackException` si aucune des trois sources n'est
  /// exploitable.
  Future<PlaybackMedia> resolve(Track track);
}
