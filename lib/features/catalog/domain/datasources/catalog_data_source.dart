import '../entities/track.dart';

/// Source brute du catalogue musical.
///
/// Contrat volontairement minimal : une implémentation lit le catalogue embarqué
/// dans les assets (MVP), une autre interrogera l'API distante. Ni la mise en
/// cache ni la stratégie de repli ne sont définies ici, elles appartiennent au
/// repository.
abstract interface class CatalogDataSource {
  /// Renvoie les pistes telles que les fournit la source, dans l'ordre reçu.
  ///
  /// Échoue avec une `CatalogException` si les données sont absentes, illisibles
  /// ou ne respectent pas le format attendu.
  Future<List<Track>> fetchTracks();
}
