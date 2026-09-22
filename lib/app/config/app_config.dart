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
  static const String catalogAssetPath = '$artistAssetsRoot/catalog.json';

  /// Configuration de l'artiste courant (identité, thème, réglages).
  static const String configAssetPath = '$artistAssetsRoot/config.json';

  /// Identifiant de l'artiste utilisé par la source distante (Firestore).
  ///
  /// Dérivé de [artistFolder] (`artist_1` → `artist1`) afin de rester aligné sur
  /// les identifiants du catalogue embarqué et sur les `applicationId` des
  /// flavors Android, sans second `--dart-define` à maintenir.
  static String get artistId => artistFolder.replaceAll('_', '');
}