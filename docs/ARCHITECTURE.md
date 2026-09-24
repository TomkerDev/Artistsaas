# Architecture du projet

Ce document décrit en détail l'organisation du code de **Artistsaas**, une
application Android (Flutter) qui diffuse le catalogue musical d'un artiste :
lecture intégrée, téléchargement local, écoute hors connexion.

## Vue d'ensemble

```
lib/
├── main.dart                            # entrée « application artiste » (Android)
├── main_admin.dart                      # entrée « panneau d'administration » (Flutter Web)
├── firebase_options.dart                # options Firebase par plateforme (--dart-define)
├── admin/                               # écrans du panneau d'administration
│   ├── admin_login_page.dart            # connexion Firebase Auth (e-mail + mot de passe)
│   └── admin_upload_page.dart           # publication d'un titre (audio + pochette)
├── services/
│   └── supabase_storage_service.dart    # client Supabase Storage (bucket `artist-media`)
├── app/
│   ├── artist_app.dart                  # MaterialApp : thème, locale fr, coquille
│   ├── di/
│   │   └── app_providers.dart           # composition root (injection Riverpod)
│   ├── shell/
│   │   └── home_shell.dart              # coquille à 3 onglets (Accueil/Lecteur/Ma musique)
│   └── theme/
│       └── app_theme.dart               # thème clair et sombre
├── core/
│   ├── constants/app_strings.dart       # libellés de l'interface
│   ├── errors/app_exception.dart        # erreur applicative transverse
│   └── utils/                           # collections.dart, duration_formatter.dart
└── features/
    ├── catalog/                         # catalogue musical        → écran Accueil
    ├── player/                          # moteur audio et lecture  → écran Lecteur
    └── library/                         # téléchargements          → écran Ma musique
```

## Deux points d'entrée

Le dépôt produit deux binaires à partir de la même base de code :

| Fichier | Cible | Rôle |
| --- | --- | --- |
| `lib/main.dart` | Android (les 12 flavors) | application artiste : catalogue, lecteur, téléchargements |
| `lib/main_admin.dart` | Flutter Web (Firebase Hosting) | panneau d'administration : Auth, publication de titres |

Le binaire artiste n'embarque **jamais** les écrans d'administration : la
séparation est faite au niveau du point d'entrée, pas par un drapeau d'exécution.

## Panneau d'administration (web)

| Élément | Détail |
| --- | --- |
| Authentification | Firebase Auth, e-mail + mot de passe (`signInWithEmailAndPassword`) |
| Médias lourds | Supabase Storage, bucket public `artist-media`, chemin `<artistId>/<fichier>` |
| Métadonnées | Cloud Firestore, collection `tracks` (titre, album, numéro de piste, année, URLs) |
| Sélection de fichiers | `file_picker` (MP3 + pochette) |
| Navigation | routes `MaterialApp` : `/admin/login` et `/admin/upload` |

`lib/services/supabase_storage_service.dart` crée son client **paresseusement**
au premier téléversement et lit ses paramètres dans des constantes
`String.fromEnvironment` (voir le piège `const` dans le README). `main_admin.dart`
n'initialise `Supabase.initialize` que si les deux valeurs sont présentes, afin
qu'un build sans `--dart-define=SUPABASE_*` démarre quand même et affiche
l'erreur au moment de l'upload plutôt qu'au lancement.

### Section KPI — indicateurs clés de performance

Le panneau affiche une grille de **4 cartes KPI** en temps réel en haut de
`admin_upload_page.dart` :

| Carte | Source | Description |
| --- | --- | --- |
| Titres en ligne | `tracks` | Nombre total de morceaux publiés |
| Albums & Singles | `tracks.album` | Nombre d'albums/singles distincts |
| Artiste / Total Artistes | `tracks.artistId` | Nom de l'artiste (rôle `artist`) ou total d'artistes (rôle `agency_admin` global) |
| Dernier Ajout | `tracks.createdAt` | Titre + date du dernier morceau ajouté |

**Filtrage par rôle** :

- `agency_admin` + `assignedArtistId == 'all'` : écoute sur la collection
  `tracks` complète (tous les artistes) ;
- `artist` ou `agency_admin` avec artiste spécifique : écoute filtrée par
  `where('artistId', isEqualTo: _selectedArtistId)`.

> Le `StreamBuilder` se reconnecte automatiquement quand `_selectedArtistId`
> change (changement d'artiste dans le dropdown), ce qui rafraîchit les
> cartes KPI sans recharger la page.

**Responsive** : la grille utilise `LayoutBuilder` + `Wrap` pour afficher 4
colonnes sur web/PC et une grille 2×2 sur mobile. Un squelette de chargement
(`_kpiLoadingSkeleton` avec `CircularProgressIndicator`) est affiché pendant
l'attente du premier snapshot Firestore ou pendant le chargement du rôle.

## Distribution multi-artistes

Une seule base de code produit **une application par artiste** :

- `android/app/build.gradle.kts` déclare `flavorDimensions += "artist"` et douze
  *product flavors* (`dilson_le_mustang`, `jethsonat`, `artist1`…`artist10`),
  chacun fixant son `applicationId` (`com.music.<flavor>`) et son nom affiché
  (`resValue("string", "app_name", …)`) ;
- `flutter_launcher_icons.yaml` porte le bloc `flavors` et
  `tool/generate_brand_assets.dart` génère les icônes et visuels de marque ;
- l'identité embarquée de chaque artiste est un simple
  `assets/artists/<dossier>/artist.json` (`id`, `name`, `applicationId`, `icon`) ;
- le catalogue audible est **partagé** (`assets/catalog/catalog.json`) tandis que
  les titres réellement publiés proviennent de Firestore, filtrés par identifiant
  d'artiste.

Le nom du flavor n'est **pas** transmis au code Dart : aucune exécution ne lit
`--dart-define=ARTIST_FOLDER`, l'identité affichée vient du flavor Android et le
contenu distant de Firestore.

## Principes

### 1. Clean architecture par feature

Chaque feature est découpée en trois couches, avec un sens de dépendance
strict : `presentation → domain ← data`.

| Couche | Contenu | Interdits |
| --- | --- | --- |
| `domain/` | entités, interfaces (`Repository`, `Service`, `DataSource`) | aucune dépendance à Flutter, `just_audio`, `sqflite` ou au système de fichiers |
| `data/` | implémentations concrètes (assets, fichiers, base de données) | n'importe jamais `presentation/` ni `app/` |
| `presentation/` | écrans, contrôleurs Riverpod, widgets | ne parle jamais directement au stockage ou au moteur audio |

### 2. La composition root est unique

`lib/app/di/app_providers.dart` est le **seul** endroit où les implémentations
concrètes sont choisies. Passer d'un catalogue embarqué à une API distante
(NestJS/PostgreSQL) revient à y fournir une nouvelle implémentation de
`CatalogDataSource` / `MusicRepository`, sans toucher aux écrans.

### 3. État via Riverpod 2.x

Les contrôleurs étendent `AsyncNotifier` (ex. `CatalogController`) et exposent
des `AsyncValue` (`loading` / `error` / `data`). Les écrans n'appellent jamais
le repository : ils observent les providers.

## Features

### `catalog` — catalogue musical (complet)

- `domain/entities/track.dart` : modèle `Track` (id, titre, durée, source audio…)
- `domain/datasources/catalog_data_source.dart` : contrat de lecture brute
- `domain/repositories/music_repository.dart` : contrat `getTracks()`
- `data/datasources/asset_catalog_data_source.dart` : lit `assets/catalog/catalog.json`
- `data/repositories/music_repository_impl.dart` : implémente le contrat avec mise en cache
- `presentation/` : `CatalogController` (état async), `HomeScreen`, `TrackListTile`

### `player` — moteur audio (complet)

- `domain/entities/` : `PlaybackMedia`, `PlaybackSource` (sealed : asset /
  fichier / réseau), `PlaybackState`
- `domain/services/audio_player_service.dart` : interface du moteur (queue,
  play/pause, seek, skip, flux d'état). Les erreurs d'exécution sont publiées
  dans `PlaybackState.errorMessage` plutôt que levées.
- `domain/services/playback_source_resolver.dart` : contrat de résolution des
  sources (copie locale → distant → embarqué)
- `data/just_audio_player_service.dart` : implémentation `just_audio` — seul
  endroit de l'application qui connaît la bibliothèque de lecture
- `data/default_playback_source_resolver.dart` : applique la règle de priorité
- `presentation/` : `PlaybackController` (file, commandes, état),
  `PlayerScreen` (pochette, barre de progression avec seek, contrôles,
  erreur acquittable)

### `library` — téléchargements (complet)

- `domain/entities/downloaded_track.dart` / `download_progress.dart`
- `domain/repositories/download_repository.dart` : contrat (flux de copies,
  téléchargement, suppression, chemin local)
- `data/local_download_repository.dart` : copie des assets vers
  `<documents>/downloads/<id>.<ext>` par blocs de 64 Ko (progression réelle),
  indexation `sqflite` (`<databases>/artistsaas.db`, table `downloaded_tracks`)
- `presentation/` : `downloadedTracksProvider` / `downloadProgressProvider`,
  `MyMusicScreen` (liste avec taille et date, lecture, suppression confirmée)

### `app/shell` — coquille et mini-lecteur

- `home_shell.dart` : `IndexedStack` + `NavigationBar` ; l'onglet actif est
  partagé via `selectedTabNotifier` pour permettre la navigation depuis le
  mini-lecteur
- `mini_player.dart` : barre persistante (progression, titre, play/pause,
  suivant) affichée dès qu'un morceau est en file ; un tap ouvre le lecteur

## Assets et contenu embarqué

| Chemin | Contenu |
| --- | --- |
| `assets/catalog/catalog.json` | catalogue embarqué (partagé par tous les artistes) |
| `assets/audio/demo-0*.wav` | audio de démonstration |
| `assets/covers/cover-0*.png` | pochettes de démonstration |
| `assets/artists/artist_1…10/artist.json` | identité embarquée de chaque artiste |
| `assets/brand/` | logo et icône source de la marque |
| `assets/icons/artist_*_icon.png` | icônes générées par artiste |

Scripts de génération (à relancer uniquement quand les sources changent) :

- `dart run tool/generate_demo_audio.dart` — audio de démonstration ;
- `dart run tool/generate_brand_assets.dart` — visuels et icônes par flavor.

Le catalogue embarqué est **versionné dans le dépôt** : toute modification passe
par une nouvelle version de l'application (voir les conséquences dans le README).
Les titres publiés après coup passent par Firestore et Supabase Storage, donc
sans nouvelle version de l'application.

## Tests

La suite (`flutter test`) couvre chaque couche :

- `test/app/` : widget test de la racine applicative ;
- `test/assets/` : validité du `catalog.json` embarqué ;
- `test/core/` : utilitaires (`collections`, `duration_formatter`) ;
- `test/features/…` : entités, sources de données, repositories, contrôleurs, écrans ;
- `test/helpers/fakes.dart` : doublures réutilisables des interfaces de `domain/`.

## Dette technique

- `lib/features/admin/` (7 fichiers : `AdminAuthService`, `TrackPublisher`, leurs
  implémentations Firebase, `admin_login_page.dart`, `admin_upload_page.dart`,
  `admin_providers.dart`) est **entièrement orphelin** : plus aucun `import` ne
  le référence depuis que le panneau vit dans `lib/admin/` et `lib/services/`.
  À supprimer.
- `lib/admin/admin_routes.dart` (`AdminScreenIds`, `AdminArtistOption`,
  `allAdminArtists`) n'est importé nulle part : la liste des artistes est
  dupliquée en dur dans `admin_upload_page.dart`. À supprimer ou à réutiliser.
- `lib/app/config/app_config.dart` (`AppConfig`) n'est pas utilisé : aucun build
  ne définit `ARTIST_FOLDER` et `AppConfig.configAssetPath` pointe vers un
  `assets/artists/<dossier>/config.json` qui n'existe pas (seul `artist.json`
  subsiste). Sans danger aujourd'hui, mais à retirer ou à brancher.

## Évolutions prévues

1. Supprimer la dette technique ci-dessus (fichiers orphelins et doublons).
2. Générer les APK des dix autres flavors (`artist1`…`artist10`).
3. Mettre en place une vraie signature de release : `android/app/build.gradle.kts`
   signe encore avec la clé de debug (`signingConfigs.getByName("debug")`).
4. Publier sur le Play Store (`flutter build appbundle --release`).
