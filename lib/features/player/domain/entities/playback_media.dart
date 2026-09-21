import 'playback_source.dart';

/// Élément de la file de lecture : une source audio et ses métadonnées.
///
/// Volontairement indépendant de l'entité `Track` : le moteur audio n'a besoin
/// que de la source et de quoi alimenter l'interface (titre, artiste, pochette),
/// ce qui permet notamment d'afficher une piste sans charger tout le catalogue.
class PlaybackMedia {
  const PlaybackMedia({
    required this.trackId,
    required this.title,
    required this.artist,
    required this.source,
    this.artAsset,
  });

  /// Identifiant de la piste d'origine.
  final String trackId;

  /// Titre affiché par le lecteur.
  final String title;

  /// Artiste affiché par le lecteur.
  final String artist;

  /// Source effectivement lue.
  final PlaybackSource source;

  /// Pochette embarquée, ou `null` si la piste n'en fournit pas.
  final String? artAsset;

  @override
  bool operator ==(Object other) {
    return other is PlaybackMedia &&
        other.trackId == trackId &&
        other.title == title &&
        other.artist == artist &&
        other.source == source &&
        other.artAsset == artAsset;
  }

  @override
  int get hashCode => Object.hash(trackId, title, artist, source, artAsset);

  @override
  String toString() => 'PlaybackMedia($trackId, « $title »)';
}
