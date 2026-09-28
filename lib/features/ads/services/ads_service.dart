import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../app/config/ads_config.dart';

/// Cycle de vie du SDK Google Mobile Ads.
///
/// L'initialisation est tolérante à l'échec : un build sans identifiants
/// AdMob (ou avec des identifiants invalides) ne doit jamais empêcher
/// l'application de démarrer. Les erreurs remontent uniquement en console, en
/// mode debug.
abstract final class AdsService {
  /// Identifiant interstitiel en cours d'affichage, `null` si aucun.
  ///
  /// Un interstitiel déjà affiché n'est pas relancé : Google n'autorise qu'une
  /// seule présentation par chargement.
  static InterstitialAd? _interstitial;

  /// Date du dernier interstitiel présenté, pour respecter la cadence.
  static DateTime? _lastShownAt;

  /// Délai minimal entre deux interstitiels.
  ///
  /// Google sanctionne les applications qui en montrent trop souvent : cet
  /// intervalle protège le classement comme le confort d'écoute.
  static const Duration _minInterval = Duration(minutes: 2);

  /// Initialise le SDK si la publicité est activée pour ce build.
  ///
  /// À appeler après `WidgetsFlutterBinding.ensureInitialized()` et avant
  /// `runApp`. Sans identifiants, la méthode ne fait rien.
  static Future<void> initialize() async {
    if (!AdsConfig.adsEnabled) {
      return;
    }
    await MobileAds.instance.initialize();
  }

  /// Prépare un interstitiel pour la prochaine occasion.
  ///
  /// L'appel est sans effet si la publicité est désactivée, si un interstitiel
  /// est déjà chargé, ou si l'un vient d'être présenté.
  static Future<void> loadInterstitial() async {
    if (!AdsConfig.adsEnabled || _interstitial != null) {
      return;
    }
    final DateTime? last = _lastShownAt;
    if (last != null && DateTime.now().difference(last) < _minInterval) {
      return;
    }
    await InterstitialAd.load(
      adUnitId: AdsConfig.effectiveInterstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) => _interstitial = ad,
        onAdFailedToLoad: (LoadAdError error) {
          // Échec courant (pas de réseau, quota, format indisponible) : on
          // abandonne proprement, la prochaine tentative repartira de zéro.
          if (kDebugMode) {
            debugPrint('AdMob : chargement interstitiel impossible (${error.code})');
          }
        },
      ),
    );
  }

  /// Présente l'interstitiel préparé, s'il y en a un de prêt.
  ///
  /// L'écouteur `onFullScreenContentClosed` libère l'annonce et réarme
  /// [loadInterstitial] pour la prochaine visite.
  static Future<void> showInterstitial() async {
    final InterstitialAd? ad = _interstitial;
    if (ad == null) {
      return;
    }
    _interstitial = null;
    _lastShownAt = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (Ad ad) {
        ad.dispose();
        unawaited(loadInterstitial());
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        ad.dispose();
        if (kDebugMode) {
          debugPrint('AdMob : affichage interstitiel impossible (${error.code})');
        }
      },
    );
    await ad.show();
  }

  /// Libération des annonces en cours, appelée si l'application est détruite.
  static void dispose() {
    _interstitial?.dispose();
    _interstitial = null;
  }
}