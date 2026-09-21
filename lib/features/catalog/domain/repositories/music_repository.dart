import '../entities/track.dart';

/// Accès en lecture au catalogue musical.
///
/// Contrat de domaine : l'implémentation du MVP lit un catalogue embarqué dans
/// les assets. Une implémentation distante (API NestJS/PostgreSQL) pourra la
/// remplacer sans qu'aucun écran n'ait à changer.
abstract interface class MusicRepository {
  /// Renvoie l'intégralité du catalogue, dans l'ordre d'affichage prévu.
  ///
  /// Échoue avec une `CatalogException` si les données sont absentes ou
  /// illisibles. Aucun cache n'est défini par ce contrat : il appartient à
  /// l'implémentation de décider comment et quand éviter les entrées/sorties.
  Future<List<Track>> getTracks();
}
