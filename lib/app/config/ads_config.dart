/// Configuration de la publicité AdMob, paramétrée à la compilation.
///
/// Chaque artiste est distribué comme une application distincte et **doit
/// utiliser son propre compte AdMob** : partager des identifiants entre
/// plusieurs applications viole les règles de Google et expose le compte à une
/// désactivation. Les identifiants sont donc injectés par `--dart-define`, sur le
/// même modèle que les clés Firebase :
///
/// ```sh
/// flutter build apk --flavor jethsonat \
///   --dart-define=ADMOB_APP_ID=ca-app-pub-…~… \
///   --dart-define=ADMOB_BANNER_ID=ca-app-pub-…/… \
///   --dart-define=ADMOB_INTERSTITIAL_ID=ca-app-pub-…/…
/// ```
///
/// En release, si ces identifiants manquent, [adsEnabled] vaut `false` : aucune
/// annonce n'est demandée et l'application se comporte comme avant
/// l'intégration. En debug, les identifiants de test officiels de Google sont
/// utilisés en repli pour que `flutter run` exerce réellement le code.
library;

import 'package:flutter/foundation.dart' show kDebugMode;

/// Identifiants de publicité et état d'activation du build courant.
abstract final class AdsConfig {
  /// Identifiant de l'application AdMob Android (`…/…` absent, forme `~`).
  static const String appId = String.fromEnvironment('ADMOB_APP_ID');

  /// Identifiant d'un bloc publicitaire bannière.
  static const String bannerId = String.fromEnvironment('ADMOB_BANNER_ID');

  /// Identifiant d'un bloc publicitaire interstitiel.
  static const String interstitialId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID',
  );

  /// Identifiants de test publiés par Google : ils ne rapportent rien, mais
  /// permettent de valider l'intégration sans compte réel.
  static const String _testAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String _testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';

  /// Identifiant d'application effectif.
  ///
  /// En debug, un identifiant absent devient celui de test ; en release il
  /// reste vide, ce qui maintient la publicité désactivée.
  static String get effectiveAppId => _resolve(appId, _testAppId);

  /// Identifiant de bannière effectif, avec le même repli que
  /// [effectiveAppId].
  static String get effectiveBannerId => _resolve(bannerId, _testBannerId);

  /// Identifiant interstitiel effectif, avec le même repli que
  /// [effectiveAppId].
  static String get effectiveInterstitialId =>
      _resolve(interstitialId, _testInterstitialId);

  /// La publicité doit-elle être affichée et demandée au SDK ?
  ///
  /// Un identifiant mal formé (mauvais préfixe) est traité comme absent : le SDK
  /// refuse de démarrer sur une configuration partielle, et mieux vaut n'afficher
  /// aucune annonce que faire échouer l'application au lancement.
  static bool get adsEnabled =>
      effectiveAppId.startsWith('ca-app-pub-') &&
      effectiveBannerId.startsWith('ca-app-pub-') &&
      effectiveInterstitialId.startsWith('ca-app-pub-');

  /// Une valeur injectée est prioritaire ; sinon, l'identifiant de test en
  /// debug, et une chaîne vide en release.
  static String _resolve(String configured, String testId) {
    if (configured.isNotEmpty) {
      return configured;
    }
    return kDebugMode ? testId : '';
  }
}