/// Chaînes de caractères affichées par l'application.
///
/// L'application est monolingue (français) pour le MVP. Les chaînes visibles
/// sont centralisées ici afin de pouvoir introduire une internationalisation
/// (`flutter_localizations` + fichiers ARB) sans réécrire les écrans.
abstract final class AppStrings {
  /// Nom affiché de l'application.
  ///
  /// Valeur provisoire : à remplacer par le nom de scène définitif avant toute
  /// publication. `android:label` (AndroidManifest.xml) doit être aligné.
  static const String appTitle = 'Artistsaas';

  // Libellés de la barre d'onglets.
  static const String tabHome = 'Accueil';
  static const String tabPlayer = 'Lecteur';
  static const String tabMyMusic = 'Ma musique';

  // Titres des écrans.
  static const String homeTitle = 'Catalogue';
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
}
