# Ajouter un artiste

Procédure complète pour onboard un nouvel artiste sur la plateforme, avec les
valeurs à renseigner et les points de contrôle.

> Architecture générale : [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Principe

L'identité d'un artiste vit dans **un seul fichier**,
`lib/core/constants/artist_config.dart`. Aucun écran, aucun lecteur et aucun
test ne contient de valeur d'artiste codée en dur.

Ce qui découle automatiquement de l'entrée dans le registre :

- la fiche « À Propos » (nom, biographie, distinction, réseaux) ;
- le header de l'accueil (pochette, nom, crédit de label) ;
- le crédit « Produced & Distributed by … » du lecteur et des fiches ;
- l'apparition de l'artiste dans le sélecteur du panneau d'administration.

## Les deux identifiants, à ne pas confondre

| Variable | Rôle | Exemple |
| --- | --- | --- |
| `ARTIST_ID` | Identité canonique : `ArtistProfile.id` et champ Firestore `artistId`. **Détermine le contenu affiché.** | `jethsonat` |
| `ARTIST_FOLDER` | Dossier d'assets, pour d'éventuels contenus embarqués. | `artist_2` |

Sans `ARTIST_ID`, le code dérive l'identifiant de `ARTIST_FOLDER`
(`artist_2` → `artist2`). Avec un `ArtistProfile.id` valant `mon_artiste`, la
fiche ne serait pas trouvée et l'app afficherait le profil de repli « Novaa ».

> **Avec un artiste nommé, passez toujours `-ArtistId` explicitement.**

## Étape 1 — Le registre (obligatoire)

Dans `lib/core/constants/artist_config.dart`, ajouter une entrée à
`artistProfiles` :

```dart
'mon_artiste': ArtistProfile(
  id: 'mon_artiste',              // = artistId Firestore ET nom du flavor
  stageName: 'Nom de scène',
  legalName: 'Nom civil',
  label: 'Tete Roh Studio',
  universe: 'Slogan court',
  biography: 'Biographie officielle…',
  distinction: 'Nomination, prix…',   // facultatif
  coverAsset: 'assets/covers/mon_artiste_cover.png',
  socials: ArtistSocials(
    facebook: Uri.parse('https://…'),
    youtube: Uri.parse('https://…'),
  ),
),
```

## Étape 2 — Le flavor Android (obligatoire)

Dans `android/app/build.gradle.kts`, dans `productFlavors` :

```kotlin
create("mon_artiste") {
    dimension = "artist"
    applicationId = "com.music.mon_artiste"   // unique sur Play Store
    resValue("string", "app_name", "Nom de scène")
}
```

`applicationId` doit être **unique** : deux artistes ne peuvent pas le partager.

## Étape 3 — Les visuels

- **Pochette** : déposer l'image dans `assets/covers/`. Le dossier est déclaré
  dans `pubspec.yaml` : si le nom correspond à `ArtistProfile.coverAsset`, aucun
  autre changement n'est requis.
- **Icône** : déposer `assets/icons/mon_artiste_icon.png`, ajouter une entrée
  dans `flutter_launcher_icons.yaml`, puis `dart run flutter_launcher_icons`.

## Étape 4 — Le contenu (facultatif)

- **Hors-ligne** : déposer les MP3 dans `assets/audio/` et ajouter les entrées
  dans `assets/catalog/catalog.json` avec `artistId` et `label`. Le catalogue est
  partagé et **cloisonné automatiquement** par `artistId` à la lecture.
- **Sans hors-ligne** : ne rien ajouter, et publier depuis le panneau. Le build
  reste en mode hybride (`STREAM_ONLY=false`), donc les titres distants
  s'afficheront et une panne réseau n'affichera pas de catalogue vide.

Définir `STREAM_ONLY=true` uniquement si l'artiste n'a **aucun** contenu
embarqué.

## Étape 5 — Firestore

Créer le document `admin_users/{uid}` dans la console Firebase :

```json
{ "role": "artist", "assignedArtistId": "mon_artiste" }
```

Pour un compte d'agence, qui voit tous les artistes :

```json
{ "role": "agency_admin", "assignedArtistId": "all" }
```

Aucune règle Firestore ni index à ajouter : le cloisonnement par `artistId` est
générique et les index sont déjà déclarés pour les cinq collections.

## Étape 6 — Le build

```powershell
# Une fois : copier le modèle et le remplir.
copy .env.example .env

powershell -ExecutionPolicy Bypass -File scripts/build_apk.ps1 `
  -Flavor mon_artiste -ArtistId mon_artiste -ArtistFolder artist_2
```

Le script lit `.env` (ou les variables du processus, en CI), construit la
commande complète, ajoute `--no-tree-shake-icons` et recopie l'APK dans
`releases/<flavor>/` — `flutter clean` efface `build/`.

Vérifier ensuite que l'identifiant est bien celui attendu :

```powershell
aapt2 dump packagename build\app\outputs\flutter-apk\app-mon_artiste-release.apk
# com.music.mon_artiste
```

## Étape 7 — Premier contenu

Se connecter au panneau d'administration, choisir l'artiste dans la barre
latérale, puis publier. **Aucun import manuel n'est nécessaire** : le filtre
`artistId` fait le reste.

## Étape 6 bis — La publicité AdMob (obligatoire pour monétiser)

Chaque artiste est une application Android distincte, et **Google AdMob
interdit de partager des identifiants entre plusieurs applications** : un
compte qui sert deux apps peut être désactivé, avec suppression des revenus.

Il faut donc **un compte AdMob par artiste**. Ce n'est pas technique : il faut
créer le compte sur [admob.google.com](https://admob.google.com) avec l'identité
de l'artiste (ou du label), puis y déclarer l'application avec son
`applicationId` exact (`com.music.mon_artiste`).

Une fois les trois identifiants obtenus, les renseigner dans `.env` :

```dotenv
# Identifiants AdMob — un compte par artiste, ne jamais partager.
ADMOB_APP_ID=ca-app-pub-1234567890123456~9876543210987654
ADMOB_BANNER_ID=ca-app-pub-1234567890123456/1111111111
ADMOB_INTERSTITIAL_ID=ca-app-pub-1234567890123456/2222222222
```

`scripts/build_apk.ps1` les transmet au build et affiche leur état. Le build
**fonctionne sans eux** : la publicité est simplement désactivée, ce qui permet
de livrer un artiste sans monétisation.

Aucun code à modifier : `AdsConfig` (`lib/app/config/ads_config.dart`) lit ces
valeurs, et la bannière s'insère seule dans la coquille.

## Récapitulatif

| # | Fichier / lieu | Action | Requis |
| --- | --- | --- | --- |
| 1 | `lib/core/constants/artist_config.dart` | Ajouter `ArtistProfile` | ✅ |
| 2 | `android/app/build.gradle.kts` | Ajouter `productFlavors` | ✅ |
| 3 | `assets/covers/`, `assets/icons/` | Déposer les visuels | ✅ |
| 4 | `flutter_launcher_icons.yaml` | Entrée icône | Pour l'icône |
| 5 | `assets/catalog/catalog.json` | Entrées `artistId` | Si hors-ligne |
| 6 | `admin_users/{uid}` (console) | Document rôle | Pour publier |
| 7 | `.env` / script de build | `-ArtistId` | ✅ |
| 8 | Compte AdMob de l'artiste | `ADMOB_*` dans `.env` | Pour monétiser |

Ni règle Firestore, ni index, ni écran à modifier.

## Contrôle avant livraison

- [ ] `flutter analyze` sans erreur
- [ ] `flutter test` au vert
- [ ] `flutter_launcher_icons` régénéré si icône dédiée
- [ ] `aapt2 dump packagename` confirme `com.music.mon_artiste`
- [ ] Un titre publié depuis le panneau apparaît dans l'application
- [ ] Le catalogue n'affiche **aucun** titre d'un autre artiste
- [ ] Les `ADMOB_*` correspondent au compte AdMob de cet artiste, pas à celui
      d'un autre (vérifier l'origine des identifiants avant livraison)