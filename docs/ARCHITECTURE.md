onglets billetterie et boutique : titres, concerts et articles restent ainsi
rattachés au même artiste.

# Architecture du projet

Organisation du code de **Artistsaas** : deux binaires (application Android et
panneau d'administration web) construits depuis une base de code unique.

> Ce document décrit l'état **courant** du code. La procédure d'ajout d'un
> artiste est dans [`ONBOARDING_ARTISTE.md`](ONBOARDING_ARTISTE.md).

## Vue d'ensemble

```
lib/
├── main.dart                            # binaire ARTISTE (Android)
├── main_admin.dart                      # binaire ADMIN (Flutter Web)
├── firebase_options.dart                # clés Firebase (--dart-define)
│
├── core/
│   ├── constants/
│   │   ├── artist_config.dart           # ★ REGISTRE DES ARTISTES
│   │   └── app_strings.dart             # libellés de l'interface
│   ├── errors/app_exception.dart        # erreur applicative transverse
│   └── utils/                           # byte_formatter, collections, duration_formatter
│
├── app/
│   ├── config/app_config.dart           # ★ variables de compilation
│   ├── di/app_providers.dart            # composition root (Riverpod)
│   ├── shell/
│   │   ├── home_shell.dart              # coquille à 5 onglets
│   │   └── mini_player.dart             # barre de lecture persistante
│   └── theme/                           # app_colors, app_theme
│
├── features/                            # un dossier par domaine
│   ├── catalog/     (12 fichiers)       # Track, catalogue embarqué + Firestore → Accueil
│   ├── player/      (10 fichiers)       # moteur audio, file de lecture    → Lecteur
│   ├── library/     ( 6 fichiers)       # téléchargements                   → Ma musique
│   ├── favorites/   ( 6 fichiers)       # favoris (sqflite)
│   ├── store/       ( 5 fichiers)       # events, merch, tickets   → Boutique & Show
│   └── platform/    ( 1 fichier )       # service de partage
│
├── admin/                               # écrans du panneau (web)
│   ├── admin_login_page.dart            # connexion Firebase Auth
│   ├── admin_identity.dart              # ★ rôle + artiste (admin_users)
│   ├── admin_routes.dart                # sélecteur d'artiste (dérivé du registre)
│   ├── admin_upload_page.dart           # publication audio + KPI
│   └── admin_store_page.dart            # Dashboard, profil, billetterie, boutique
│
└── services/supabase_storage_service.dart
```

Chaque dossier de `features/` suit la même découpe en couches, avec une règle de
dépendance stricte :

```
presentation/  →  app/di  →  data/  →  domain/
```

`domain/` n'importe rien du projet ; `presentation/` et `data/` s'appuient
dessous, jamais l'inverse.

## Deux points d'entrée

| Fichier | Cible | Rôle |
| --- | --- | --- |
| `lib/main.dart` | Android (12 flavors) | catalogue, lecteur, boutique, à propos |
| `lib/main_admin.dart` | Flutter Web (Firebase Hosting) | publication, billetterie, merch |

Le binaire artiste n'embarque **jamais** les écrans d'administration : la
séparation est faite au niveau du point d'entrée, pas par un drapeau
d'exécution.

### Identité de l'artiste

`ARTIST_ID` (via `--dart-define`) détermine la fiche artiste, le filtre Firestore
et le contenu affiché ; `ARTIST_FOLDER` ne sert qu'aux contenus embarqués. Le
détail est dans [`ONBOARDING_ARTISTE.md`](ONBOARDING_ARTISTE.md).

## Modèle de données Firestore

Cinq collections, cloisonnées par `artistId` côté requête.

| Collection | Écrit par | Lue par | Index |
| --- | --- | --- | --- |
| `tracks` | panneau (upload) | application | `artistId` + `createdAt` |
| `events` | panneau (billetterie) | application | `artistId` + `date` |
| `merch` | panneau (boutique) | application | `artistId` + `name` |
| `tickets` | application (public) | application, panneau | `event_id` |
| `admin_users` | console Firebase | panneau | — |

Les règles (`firestore.rules`) déclarent les cinq collections : lecture publique
pour le contenu, écriture authentifiée pour la publication. Sur `tickets`, un
client ne peut créer qu'un billet `pending` et ne modifier que le `status` — un
QR code validé ne peut pas être réécrit par le public. `admin_users` est en
lecture seule : un compte ne peut pas s'attribuer `agency_admin` lui-même.

## Panneau d'administration (web)

| Élément | Détail |
| --- | --- |
| Authentification | Firebase Auth, e-mail + mot de passe |
| Rôle / artiste | document `admin_users/{uid}`, lu une fois et partagé (`AdminIdentity`) |
| Médias lourds | Supabase Storage, bucket `artist-media`, chemin `<artistId>/<fichier>` |
| Métadonnées | Cloud Firestore (voir le tableau des collections) |
| Navigation | `NavigationRail` : Dashboard, Catalogue & Upload, Boutique & Shows, Profil, Paramètres |

`SupabaseStorageService` lit ses paramètres dans des constantes
`String.fromEnvironment` (voir le piège `const` dans le README). `main_admin.dart`
n'initialise `Supabase.initialize` que si les deux valeurs sont présentes, afin
qu'un build sans `--dart-define=SUPABASE_*` démarre quand même et affiche
l'erreur au moment de l'upload plutôt qu'au lancement.

Le binaire est produit et publié par `scripts/build_web.ps1` (mêmes règles de
lecture de `.env` que `scripts/build_apk.ps1`), puis `firebase deploy --only
hosting --project novaa-music-tchaddd`. Le script échoue si
`build/web/main.dart.js` est absent : `firebase.json` publie ce dossier, et un
dossier vide mettrait en ligne une 404 silencieuse. La CI
(`.github/workflows/deploy.yml`) exécute la même séquence sur `main`, avec
`FIREBASE_SERVICE_ACCOUNT` comme seul secret d'authentification.

### Publication : le `artistId` ne peut pas être oublié

Toutes les écritures passent par des services dédiés qui posent le champ
`artistId` et valident le schéma — `StoreAdminService` pour la billetterie et le
merch, `admin_upload_page.dart` pour les titres.

> Sans ce champ, un document publié resterait **invisible** : toutes les requêtes
> mobiles filtrent sur `artistId`. C'était le défaut le plus coûteux du panneau,
> aujourd'hui couvert par les règles Firestore et les tests.

### Section KPI

`admin_upload_page.dart` affiche **4 cartes** en temps réel, pour l'artiste
courant : titres en ligne, albums & singles, artiste, dernier ajout.

### Filtrage par rôle

Un seul identifiant pilote toutes les requêtes du panneau, `_effectiveArtistId` :

- rôle **`artist`** : verrouillé sur `assignedArtistId`, le sélecteur est
  désactivé et la requête ne peut pas sortir de ce périmètre ;
- rôle **`agency_admin`** : la liste déroulante est active et la bascule entre
  artistes recalcule la requête.

L'artiste sélectionné est publié via `shellArtistIdNotifier`, que consomment les
onglets billetterie et boutique : titres, concerts et articles restent ainsi
rattachés au même artiste.

## Fonctionnalités mobiles

`home_shell.dart` expose **5 onglets** :

| Onglet | Écran | Contenu |
| --- | --- | --- |
| Accueil | `HomeScreen` | header (pochette, nom, crédit de label) + catalogue |
| Lecteur | `PlayerScreen` | pochette, progression, contrôles, arrêt, partage |
| Ma musique | `MyMusicScreen` | titres téléchargés, taille, suppression |
| Boutique & Show | `StoreShowScreen` | concerts à venir + catalogue merch |
| À Propos | `AboutArtistScreen` | biographie, distinction, réseaux, version |

### Catalogue : trois sources combinées

`TrackRepositoryImpl` fusionne :

1. le catalogue embarqué (`catalog.json`), **cloisonné par `artistId`** ;
2. les nouveautés Firestore (une erreur distante est absorbée : les titres
   embarqués restent accessibles) ;
3. l'état de téléchargement local (`sqflite`).

Un artiste peut déclarer `STREAM_ONLY=true` pour ignorer le catalogue embarqué et
ne lire que Firestore. Par défaut (`false`), le catalogue est **hybride** :
titres embarqués jouables hors-ligne + nouveautés distantes.

> `catalog.json` étant **partagé**, le cloisonnement par `artistId` est
> indispensable : sans lui, l'application d'un artiste proposerait les titres
> des autres.

### Résolution de la source audio

`DefaultPlaybackSourceResolver` applique une priorité stricte :

```
copie locale téléchargée  →  URL distante (audioUrl)  →  audio_asset embarqué
```

`just_audio` consomme le résultat : `FilePlaybackSource → AudioSource.file`,
`NetworkPlaybackSource → AudioSource.uri`, `AssetPlaybackSource →
AudioSource.asset`.

### Lecture en arrière-plan

`just_audio_background` + `audio_service` : notification média, contrôles
casque/Bluetooth, écran de verrouillage. L'action d'arrêt coupe le flux et retire
la notification (`androidStopForegroundOnPause`).

### Billetterie et boutique

`StoreShowScreen` observe `StoreRepository` via Riverpod
(`store_providers.dart`) : chaque section affiche un état de chargement, une
erreur avec action « Réessayer », et un état vide explicite. Une panne réseau
reste ainsi distinguable d'un catalogue vide.

Les concerts passés sont masqués côté client ; ceux dont la date est inconnue sont
conservés, l'organisateur n'ayant pas encore fixé la date.

## Publicité (AdMob)

La publicité est pilotée par `google_mobile_ads` et s'appuie sur trois
identifiants injectés à la compilation (`--dart-define`, relayés par
`scripts/build_apk.ps1` depuis `.env`) : `ADMOB_APP_ID`, `ADMOB_BANNER_ID` et
`ADMOB_INTERSTITIAL_ID`. `AdsConfig` (`lib/app/config/ads_config.dart`) les
expose et décide si la publicité est active.

Points structurants :

- **un compte AdMob par artiste.** Les douze applications sont des apps
  distinctes ; partager des identifiants viole les règles Google et expose à
  la désactivation du compte. Le manifeste déclare donc
  `com.google.android.gms.ads.APPLICATION_ID` via un `manifestPlaceholder`
  propre à chaque build (`android/app/build.gradle.kts`).
- **la publicité est facultative.** Sans identifiant valide, `adsEnabled` vaut
  `false` : `AdBanner` se rend invisible, `AdsService.initialize()` ne fait
  rien. Un build sans monétisation reste livrable.
- **en debug, repli sur les identifiants de test de Google**, ce qui permet
  d'exercer le vrai chemin de code sans compte ni revenu.
- la bannière est insérée dans la colonne de `HomeShell`, entre le
  mini-lecteur et la barre d'onglets ; elle réserve sa place uniquement une
  fois l'annonce chargée, pour éviter tout rechargement de mise en page.
- `AdsService` gère l'interstitiel : chargement anticipé, cadence minimale de
  deux minutes entre deux affichages, et libération de l'annonce à la fermeture.

### iOS : un seul artiste, en preuve de concept

Contrairement à Android, iOS **n'est pas configuré en multi-artiste**. Le
dossier `ios/` ne contient qu'une seule cible Xcode, qui produit un seul bundle
`com.music.jethsonat`. C'est un choix assumé : distribuer les douze artistes
exigerait douze configurations Xcode, et le mécanisme de flavors Gradle
d'Android n'a pas d'équivalent direct.

Le bundle id a volontairement été aligné sur la convention Android
(`com.music.jethsonat`) plutôt que sur le nom généré par `flutter create`.

Côté publicité, le même `AdsConfig` est utilisé — le code Dart n'a aucune
branchement conditionnel de plateforme. Seule la configuration change :
`Info.plist` référence `$(ADMOB_IOS_APP_ID)` et `$(ADMOB_IOS_BANNER_ID)`, valeurs
déclarées dans `ios/Flutter/Debug.xcconfig` et `Release.xcconfig`, et injectées
par `scripts/build_ipa.sh` (bash, macOS uniquement).

**Avant toute publication iOS**, deux éléments manuels sont obligatoires et
documentés dans le `Info.plist` lui-même :

- `SKAdNetworkItems` est **vide**. La liste est mise à jour par Google et doit
  être recopiée depuis la documentation officielle ; sans elle, l'attribution
  se dégrade silencieusement. Cette valeur n'a volontairement pas été inventée
  dans le dépôt.
- `ADMOB_TRACKING_USAGE_DESCRIPTION` doit être personnalisé : iOS affiche ce
  texte à l'utilisateur lors de la demande de suivi (ATT).

Aucun build iOS n'a pu être exécuté : la compilation exige macOS et Xcode, la
machine courante étant sous Windows. Seuls le XML du `Info.plist` et
l'analyse Dart sont vérifiés.

## Signature de release (Android)

`android/app/build.gradle.kts` lit `android/key.properties` s'il existe et
retombe sinon sur `~/.android/debug.keystore`, uniquement pour que
`flutter build apk` aboutisse sans configuration préalable. Un APK signé avec
cette clé de debug s'installe en direct mais **n'est pas publiable** : l'identité
d'une application installée est celle de sa clé, et en changer impose une
désinstallation.

- keystore : `android/app/upload-keystore.jks` (PKCS12, alias `upload`) ;
- mots de passe : `android/key.properties`, ignoré par git au même titre que
  `.env` ;
- `storeFile` est résolu **relativement à `android/app/`** (Gradle résout
  `file(…)` depuis le dossier du module).

Ces deux fichiers sont irremplaçables : perdus, l'application ne peut plus être
mise à jour sous la même identité. La procédure complète figure dans le README
(§ « Signature de release »).

## Assets et contenu embarqué

| Chemin | Contenu |
| --- | --- |
| `assets/catalog/catalog.json` | catalogue partagé, cloisonné par `artistId` |
| `assets/audio/jethsonat_*.m4a` | les 5 titres hors-ligne de Jethsonat |
| `assets/covers/` | pochettes, dont `jethsonat_cover.png` |
| `assets/icons/` | icônes de lancement par artiste |

> Tout fichier déposé dans `assets/audio/` part dans **chaque** APK, quel que
> soit le flavor : un dossier déclaré en bloc dans `pubspec.yaml` n'est pas
> cloisonné par artiste. Ne doivent donc y figurer que les titres déclarés dans
> `catalog.json` — un master oublié là voyage dans toutes les applications.

Il n'y a plus de dossier `assets/artists/` : le catalogue est unique et cloisonné
par `artistId`, donc aucun asset n'est propre à un artiste. `ARTIST_FOLDER` ne
sert plus qu'à dériver `artistId` par défaut.

Scripts de génération (à relancer seulement quand les sources changent) :

- `dart run tool/generate_demo_audio.dart` — démo WAV + hors-ligne MP3, avec
  vérification des durées par `ffprobe` ;
- `dart run tool/generate_brand_assets.dart` — visuels, icônes, placeholder de
  pochette Jethsonat.

## Tests

`flutter test` couvre chaque couche :

- `test/app/` — racine applicative, navigation entre onglets ;
- `test/assets/` — validité du `catalog.json` embarqué (fichiers, durées) ;
- `test/core/` — registre des artistes, utilitaires ;
- `test/features/…` — entités, sources, repositories, contrôleurs, écrans ;
- `test/helpers/` — `fakes.dart` (domaine audio) et `fakes_store.dart` (boutique).

Les écrans de boutique et de billetterie sont testés via un faux dépôt injecté
par `storeRepositoryProvider` : les tests ne dépendent pas de Firestore et
vérifient notamment l'absence de données codées en dur.

## Dette technique connue

- `user_id` vaut `'anonymous-device'` pour les billets : l'authentification du
  public n'existe pas encore. Seuls le contrôle au guichet et la confirmation
  manuelle protègent une entrée.
- `event.date` est désormais un `Timestamp` ; les anciens documents à chaîne
  restent lisibles mais ne se trient pas, et les règles refusent toute écriture
  dessus. Une migration est nécessaire s'il en existe.

## Évolutions prévues

1. Authentification du public, pour remplacer `user_id` en dur.
2. Confirmation du paiement Mobile Money (le billet est déjà un vrai document,
   mais la transaction opérateur n'est pas vérifiée).
3. Publication sur le Play Store (`flutter build appbundle --release`) : la
   signature release est en place (`android/key.properties` +
   `android/app/upload-keystore.jks`), il reste à créer la fiche Play et à
   téléverser l'AAB.
4. Déplacer le registre `artistProfiles` vers Firestore, pour onboard un
   artiste sans modification de code.