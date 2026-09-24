import '../entities/track.dart';

/// Source distante des nouveautés d'un artiste.
///
/// Contrat séparé de [CatalogDataSource] : le catalogue embarqué est la base
/// stable livrée avec l'application, tandis que cette source apporte les titres
/// publiés après la sortie du build (collection Firestore `tracks`).
///
/// L'absence de nouveautés n'est pas une erreur : l'implémentation renvoie une
/// liste vide, et le repository se contente du contenu embarqué.
abstract interface class RemoteCatalogDataSource {
  /// Nouveautés distantes de l'artiste [artistId], les plus récentes d'abord.
  ///
  /// Échoue avec une `CatalogException` si la source est injoignable ou renvoie
  /// des données illisibles. Les implémentations qui préfèrent un repli
  /// silencieux peuvent renvoyer une liste vide à la place.
  Future<List<Track>> fetchNewTracks(String artistId);
}
