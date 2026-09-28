import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../app/config/ads_config.dart';

/// Bannière publicitaire affichée en bas de l'écran, au-dessus de la barre
/// d'onglets.
///
/// Le composant est **toujours présent** dans l'arbre : il se contente de
/// renvoyer `SizedBox.shrink()` quand la publicité est désactivée. Réserver la
/// place même vide évite que la mise en page ne change selon le build, et
/// supprime tout `setState` au chargement de l'annonce.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _banner;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (AdsConfig.adsEnabled) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final BannerAd banner = BannerAd(
      adUnitId: AdsConfig.effectiveBannerId,
      request: const AdRequest(),
      size: const AdSize(
        // Format le plus répandu ; couvre la quasi-totalité des téléphones
        //Android en portrait comme en paysage.
        width: 320,
        height: 50,
      ),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          // `BannerAd` est de type `Ad` dans l'API de callback : le cast est
          // sûr, c'est toujours le bloc.banner qui notifie.
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _banner = ad as BannerAd;
            _failed = false;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          if (!mounted) {
            return;
          }
          setState(() => _failed = true);
        },
      ),
    );
    await banner.load();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const SizedBox.shrink();
    }
    final BannerAd? banner = _banner;
    if (banner == null) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: SizedBox(
        width: banner.size.width.toDouble(),
        height: banner.size.height.toDouble(),
        child: AdWidget(ad: banner),
      ),
    );
  }
}