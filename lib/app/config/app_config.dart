/// Configuration de l'application, paramétrée à la compilation.
///
/// L'identité distribuée est choisie au moment du build via `--dart-define` :
///
/// ```sh
/// flutter build apk --flavor jethsonat --dart-define=ARTIST_ID=jethsonat
/// flutter run --flavor artist1 --dart-define=ARTIST_FOLDER=artist_1
/// ```
///
/// Deux notions à ne pas confondre :
/// - `ARTIST_ID` : l'identité canonique (`jethsonat`), alignée sur
///   `ArtistProfile.id` et sur le champ Firestore `artistId`. **C'est elle qui
///   détermine le contenu affiché.**
/// - `ARTIST_FOLDER` : le dossier d'assets (`artist_1`, …), utile uniquement
///   pour d'éventuels contenus embarqués propres à un artiste.
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
  /// Sert uniquement à [artistId] lorsque `ARTIST_ID` n'est pas fourni :
  /// le format `artist_1` devient `artist1`. Aucun asset n'est lu depuis
  /// `assets/artists/<dossier>/` — le catalogue est partagé et filtré par
  /// `artistId` (voir [catalogAssetPath]).
  static const String artistFolder = String.fromEnvironment(
    'ARTIST_FOLDER',
    defaultValue: 'artist_1',
  );

  /// Catalogue musical de l'artiste courant.
  ///
  /// Le catalogue est **partagé** entre toutes les applications
  /// (`assets/catalog/catalog.json`) ; il est cloisonné par `artistId` au
  /// moment de la lecture (voir `LocalCatalogDataSource`), afin qu'un artiste
  /// ne voie pas les titres d'un autre.
  static const String catalogAssetPath = 'assets/catalog/catalog.json';

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
