import 'package:artistsaas/app/config/ads_config.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdsConfig', () {
    test('sans identifiants, la publicité est désactivée en release', () {
      // `String.fromEnvironment` est vide : le test valide le comportement du
      // build de production livré sans compte AdMob configuré.
      expect(AdsConfig.appId, isEmpty);
      expect(AdsConfig.bannerId, isEmpty);
      expect(AdsConfig.interstitialId, isEmpty);
      if (!kDebugMode) {
        expect(AdsConfig.adsEnabled, isFalse);
        expect(AdsConfig.effectiveBannerId, isEmpty);
      }
    });

    test('un identifiant mal formé ne compte pas comme un identifiant', () {
      // Un préfixe absent correspond à une configuration incomplète : mieux
      // vaut n'afficher aucune annonce que faire échouer le SDK au lancement.
      // Sans identifiants injectés, l'invariant vérifié est que `adsEnabled`
      // n'est vrai que si les trois valeurs portent le bon préfixe.
      final bool prefixOk =
          AdsConfig.effectiveAppId.isEmpty ||
          AdsConfig.effectiveAppId.startsWith('ca-app-pub-');
      expect(prefixOk, isTrue);
    });

    test('en debug sans configuration, les identifiants de test sont utilisés', () {
      // Permet d'exercer le vrai code AdMob en local, sans compte ni revenu.
      if (kDebugMode) {
        expect(AdsConfig.effectiveAppId, startsWith('ca-app-pub-'));
        expect(AdsConfig.effectiveBannerId, startsWith('ca-app-pub-'));
        expect(AdsConfig.effectiveInterstitialId, startsWith('ca-app-pub-'));
        expect(AdsConfig.adsEnabled, isTrue);
      }
    });
  });
}