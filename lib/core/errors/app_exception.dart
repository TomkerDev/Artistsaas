/// Exception applicative de base.
///
/// Elle est `sealed` : toute erreur métier doit appartenir à l'une des
/// sous-classes déclarées ci-dessous, ce qui garantit qu'un `catch` sur
/// [AppException] couvre l'intégralité des erreurs connues de l'application.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  /// Message destiné aux logs et, si nécessaire, à l'utilisateur.
  final String message;

  /// Erreur d'origine (inattendue, non traduite) à des fins de diagnostic.
  final Object? cause;

  @override
  String toString() {
    final String suffix = cause == null ? '' : ' (cause : $cause)';
    return '$runtimeType : $message$suffix';
  }
}

/// Le catalogue musical est illisible, vide ou contient une entrée invalide.
final class CatalogException extends AppException {
  const CatalogException(super.message, {super.cause});
}

/// Une opération de téléchargement ou de stockage local a échoué.
final class DownloadException extends AppException {
  const DownloadException(super.message, {super.cause});
}

/// La lecture audio n'a pas pu démarrer ou a été interrompue.
final class PlaybackException extends AppException {
  const PlaybackException(super.message, {super.cause});
}
