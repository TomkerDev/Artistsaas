/// Étape du cycle de vie d'une matérialisation locale.
enum DownloadState {
  /// Demande enregistrée, en attente de traitement.
  queued,

  /// Copie en cours.
  downloading,

  /// Fichier présent et exploitable hors connexion.
  completed,

  /// Échec : la piste n'est pas disponible localement.
  failed,
}

/// Suivi de la matérialisation locale d'une piste.
class DownloadProgress {
  const DownloadProgress({
    required this.trackId,
    required this.state,
    this.receivedBytes = 0,
    this.totalBytes,
    this.errorMessage,
  });

  /// Piste concernée.
  final String trackId;

  /// Étape courante.
  final DownloadState state;

  /// Octets déjà écrits localement.
  final int receivedBytes;

  /// Taille totale attendue, `null` tant qu'elle n'est pas connue.
  final int? totalBytes;

  /// Message d'erreur lorsque [state] vaut `DownloadState.failed`.
  final String? errorMessage;

  /// `true` si le morceau est disponible localement.
  bool get isCompleted => state == DownloadState.completed;

  /// `true` si la demande est en attente ou en cours.
  bool get isRunning =>
      state == DownloadState.queued || state == DownloadState.downloading;

  /// `true` si la matérialisation a échoué.
  bool get hasFailed => state == DownloadState.failed;

  /// Progression entre 0 et 1, ou `null` si la taille totale est inconnue.
  double? get fraction {
    final int? total = totalBytes;
    if (total == null || total <= 0) {
      return null;
    }
    return (receivedBytes / total).clamp(0, 1);
  }

  @override
  bool operator ==(Object other) {
    return other is DownloadProgress &&
        other.trackId == trackId &&
        other.state == state &&
        other.receivedBytes == receivedBytes &&
        other.totalBytes == totalBytes &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode =>
      Object.hash(trackId, state, receivedBytes, totalBytes, errorMessage);

  @override
  String toString() =>
      'DownloadProgress($trackId, $state, $receivedBytes/$totalBytes)';
}
