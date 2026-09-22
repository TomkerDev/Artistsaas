import '../entities/track.dart';

/// Accès en lecture au catalogue consolidé de l'artiste.
///
/// Le catalogue affiché est le fruit de trois sources :
/// 1. les morceaux **embarqués** dans l'application (`catalog.json`) ;
/// 2. les **nouveautés distantes** publiées après la sortie du build ;
/// 3. l'**état local** (SQLite) qui indique quels morceaux sont déjà
///    disponibles hors connexion.
///
/// La fusion est la responsabilité de ce contrat : les écrans reçoivent une
/// liste unique, prête à l'affichage, où chaque piste porte déjà ses marqueurs
/// `isNew` et `isDownloaded`.
abstract interface class TrackRepository {
  /// Renvoie le catalogue consolidé, dans l'ordre d'affichage prévu.
  ///
  /// Échoue avec une `CatalogException` si le catalogue embarqué est absent ou
  /// illisible. L'indisponibilité de la source distante n'est pas fatale : le
  /// catalogue embarqué est alors renvoyé seul.
  Future<List<Track>> getTracks();
}