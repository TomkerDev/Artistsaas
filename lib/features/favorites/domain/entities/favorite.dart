/// Favori d'une piste.
///
/// Entité de domaine : elle ne connaît ni Flutter, ni SQLite, ni l'interface.
/// La date d'ajout est portée par l'entité car elle fait partie de l'information
/// affichée par l'interface ; elle n'est pas purement technique.
class Favorite {
  const Favorite({
    required this.trackId,
    required this.addedAt,
  });

  /// Identifiant de la piste favorie.
  final String trackId;

  /// Date et heure d'ajout du favori.
  final DateTime addedAt;

  @override
  bool operator ==(Object other) {
    return other is Favorite && other.trackId == trackId;
  }

  @override
  int get hashCode => trackId.hashCode;

  @override
  String toString() => 'Favorite($trackId, ajouté le $addedAt)';
}
