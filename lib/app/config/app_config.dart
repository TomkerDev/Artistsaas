/// Configuration de l'application, paramétrée à la compilation.
///
/// L'identité distribuée est choisie au moment du build via `--dart-define` :
///
/// ```sh
/// flutter build apk --flavor artist3 --dart-define=ARTIST_FOLDER=artist_3
/// flutter run --flavor artist1 --dart-define=ARTIST_FOLDER=artist_1
/// ```
///
/// Sans `--dart-define`, l'application retombe sur `artist_1`, ce qui permet de
/// lancer le projet sans configuration supplémentaire. Les chemins exposés ici
/// sont les seuls endroits où le dossier de l'artiste est concaténé : le reste
/// du code ne manipule que des constantes nommées.
library;

import '../../core/constants/artist_config.dart';

/// Point d'accès unique aux ressources propres à l'artiste courant.
abstract final class AppConfig {
  /// Dossier de l'artiste courant, défini via `--dart-define=ARTIST_FOLDER=…`.
  ///
  /// La valeur attendue correspond à un dossier sous `assets/artists/`
  /// (`artist_1`, `artist_2`, … `artist_10`).
  static const String artistFolder = String.fromEnvironment(
    'ARTIST_FOLDER',
    defaultValue: 'artist_1',
  );

  /// Racine des contenus embarqués de l'artiste courant.
  static const String artistAssetsRoot = 'assets/artists/$artistFolder';

  /// Catalogue musical de l'artiste courant.
  ///
  /// À ce jour, le catalogue est **partagé** entre les dix applications
  /// (`assets/catalog/catalog.json`) ; les dossiers d'artiste ne portent que
  /// l'identité (`artist.json`). Le chemin reste centralisé ici pour qu'un
  /// catalogue par artiste ne soit qu'un changement local.
  static const String catalogAssetPath = 'assets/catalog/catalog.json';

  /// Configuration de l'artiste courant (identité, thème, réglages).
  static const String configAssetPath = '$artistAssetsRoot/config.json';

  /// Identifiant de l'artiste utilisé par la source distante (Firestore).
  ///
  /// Fixé explicitement via `--dart-define=ARTIST_ID=…` : c'est la valeur qui
  /// doit correspondre au champ `artistId` des documents `tracks` et à
  /// l'`applicationId` du flavor Android. À défaut, il est dérivé de
  /// [artistFolder] (`artist_1` → `artist1`).
  static String get artistId {
    const String defined = String.fromEnvironment('ARTIST_ID');
    if (defined.isNotEmpty) {
      return defined;
    }
    return artistFolder.replaceAll('_', '');
  }

  /// Fiche complète de l'artiste courant (identité, label, biographie,
  /// pochette de header et liens officiels) issue du registre central.
  static ArtistProfile get artist => resolveArtistProfile(artistId);

  /// Pochette officielle affichée en en-tête de l'accueil.
  ///
  /// Le visuel de remplacement est déposé tel quel dans `assets/covers/`.
  /// Point d'attention : `pubspec.yaml` déclare le **dossier**
  /// `assets/covers/`, pas le fichier ; un remplacement doit donc conserver le
  /// nom `jethsonat_cover.png` (ou exiger un `flutter pub get` après tout
  /// renommage, le regroupement d'assets étant résolu à la compilation).
  static String get coverAsset => artist.coverAsset;

  /// `true` lorsque l'application se passe totalement du catalogue embarqué.
  ///
  /// Cas des artistes « 100 % audio » : leurs morceaux sont diffusés en
  /// streaming depuis Firestore/Supabase, et aucun MP3 n'est livré dans l'APK.
  /// Le `catalog.json` partagé contient alors les titres d'autres artistes
  /// (démo, Dilson) qu'il ne faut surtout pas afficher dans leur application.
  ///
  /// Le drapeau est piloté à la compilation :
  /// `--dart-define=STREAM_ONLY=true`.
  static const bool streamOnly = bool.fromEnvironment(
    'STREAM_ONLY',
    defaultValue: false,
  );
}
