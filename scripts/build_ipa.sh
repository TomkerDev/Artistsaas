#!/usr/bin/env bash
#
# Archive iOS de l'application (un seul artiste : Jethsonat).
#
# Contrairement à `build_apk.ps1`, ce script ne couvre pas les douze flavors
# Android : iOS n'est pas configuré en multi-artiste. Une seule cible Xcode
# produit un seul bundle (`com.music.jethsonat`). Distribuer les autres artistes
# demanderait autant de configurations Xcode, ce qui n'est pas en place.
#
# Doit être exécuté sur macOS avec Xcode : `flutter build ipa` refuse ailleurs.
#
# Les identifiants AdMob sont lus dans l'environnement, comme sur Android.
# `Info.plist` y fait référence via les variables Xcode `$(ADMOB_IOS_*)`
# déclarées dans `ios/Flutter/*.xcconfig`.
#
# Usage :
#     ./scripts/build_ipa.sh
set -euo pipefail

artist_id="${ARTIST_ID:-jethsonat}"

echo "Configuration du build iOS"
echo "  artistId : $artist_id"
echo "  bundleId : com.music.${artist_id}"

# Les identifiants publicitaires ne sont pas des secrets : ils sont exportés
# comme variables d'environnement pour que Xcode les substitue dans Info.plist.
for var in ADMOB_IOS_APP_ID ADMOB_IOS_BANNER_ID ADMOB_TRACKING_USAGE_DESCRIPTION; do
    value="${!var:-}"
    if [ -n "$value" ]; then
        echo "  $var : ok"
    else
        echo "  $var : (absent)"
    fi
    export "$var=${value:-}"
done

if [ -z "${ADMOB_IOS_APP_ID:-}" ]; then
    echo "ATTENTION : pas de ADMOB_IOS_APP_ID — archive livrable, sans publicité." >&2
fi

echo
echo "flutter build ipa --release --dart-define=ARTIST_ID=$artist_id"
echo

flutter build ipa \
    --release \
    --dart-define="ARTIST_ID=$artist_id" \
    --no-tree-shake-icons

echo
echo "Archive : build/ios/ipa/*.ipa"
echo "À vérifier avant publication :"
echo "  - SKAdNetworkItems renseigné dans ios/Runner/Info.plist"
echo "  - ADMOB_TRACKING_USAGE_DESCRIPTION personnalisé"
echo "  - bundle id et App Store Connect"