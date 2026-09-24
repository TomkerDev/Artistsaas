/// Chaînes de caractères affichées par l'application.
///
/// L'application est monolingue (français) pour le MVP. Les chaînes visibles
/// sont centralisées ici afin de pouvoir introduire une internationalisation
/// (`flutter_localizations` + fichiers ARB) sans réécrire les écrans.
abstract final class AppStrings {
  /// Nom affiché de l'application — nom de scène fictif retenu pour la démo.
  ///
  /// `android:label` (AndroidManifest.xml) doit rester aligné.
  static const String appTitle = 'Novaa';

  // Libellés de la barre d'onglets.
  static const String tabHome = 'Accueil';
  static const String tabPlayer = 'Lecteur';
  static const String tabMyMusic = 'Ma musique';

  // Titres des écrans.
  static const String homeTitle = 'Musique';
  static const String playerTitle = 'Lecteur';
  static const String myMusicTitle = 'Ma musique';

  // Écran Accueil : états vide et erreur.
  static const String homeEmptyMessage = 'Le catalogue est encore vide.';
  static const String homeErrorTitle = 'Catalogue indisponible';
  static const String homeErrorGeneric =
      'Le catalogue n\'a pas pu être chargé.';
  static const String retryAction = 'Réessayer';

  // Textes provisoires : remplacés par les vrais contenus aux étapes 3 et 4.
  static const String playerPlaceholder = 'Le lecteur audio sera affiché ici.';
  static const String myMusicPlaceholder =
      'Les morceaux téléchargés seront affichés ici.';

  // Écran Lecteur.
  static const String playerEmptyMessage =
      'Choisissez un morceau dans le catalogue pour lancer la lecture.';
  static const String playerQueueTitle = 'File de lecture';
  static const String playerErrorTitle = 'Lecture impossible';

  // Actions de lecture.
  static const String playAction = 'Lire';
  static const String pauseAction = 'Pause';
  static const String previousAction = 'Morceau précédent';
  static const String nextAction = 'Morceau suivant';
  static const String shuffleOnAction = 'Aléatoire activé';
  static const String shuffleOffAction = 'Aléatoire désactivé';
  static const String repeatOffAction = 'Sans répétition';
  static const String repeatAllAction = 'Répéter la file';
  static const String repeatOneAction = 'Répéter le morceau';
  static const String seekBackAction = 'Reculer de 5 secondes';
  static const String seekForwardAction = 'Avancer de 5 secondes';

  // Écran Ma musique.
  static const String myMusicEmptyMessage =
      'Aucun morceau téléchargé pour le moment.\n'
      'Téléchargez un morceau depuis le catalogue pour l\'écouter hors connexion.';
  static const String myMusicDownloadedAt = 'Téléchargé le';

  // Actions de téléchargement.
  static const String downloadAction = 'Télécharger';
  static const String deleteAction = 'Supprimer';
  static const String downloadStartedMessage = 'Téléchargement en cours…';
  static const String downloadCompletedMessage =
      'Morceau disponible hors connexion.';
  static const String deleteConfirmTitle = 'Supprimer ce morceau ?';
  static const String deleteConfirmMessage =
      'La copie locale sera définitivement supprimée de l\'appareil.';
  static const String deleteFirestoreTrackMessage =
      'Cette action supprimera le document Firestore. '
      'Les fichiers Supabase resteront dans le bucket.';
  static const String cancelAction = 'Annuler';
}
