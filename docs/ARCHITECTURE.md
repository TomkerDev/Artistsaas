# Architecture du projet

Ce document décrit en détail l'organisation du code de **Artistsaas**, une
application Android (Flutter) qui diffuse le catalogue musical d'un artiste :
lecture intégrée, téléchargement local, écoute hors connexion.

## Vue d'ensemble

```
lib/
├── main.dart                            # bootstrap : runApp + ProviderScope
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

### `player` — moteur audio (contrats + écran)

- `domain/entities/` : `PlaybackMedia`, `PlaybackSource`, `PlaybackState`
- `domain/services/audio_player_service.dart` : interface du moteur (queue, play/pause,
  seek, skip, flux d'état). Les erreurs d'exécution sont publiées dans
  `PlaybackState.errorMessage` plutôt que levées, pour ne pas casser le flux observé.
- `domain/services/playback_source_resolver.dart` : résolution des sources
  (asset embarqué vs fichier téléchargé)
- `presentation/player_screen.dart` : écran Lecteur (squelette)

### `library` — téléchargements (contrats + écran)

- `domain/entities/downloaded_track.dart` / `download_progress.dart`
- `domain/repositories/download_repository.dart` : contrat de téléchargement
  (« matérialiser » le morceau dans `<documents>/downloads/<id>.mp3`)
- `presentation/my_music_screen.dart` : écran « Ma musique » (squelette)

## Assets et contenu embarqué

- `assets/catalog/catalog.json` : catalogue du MVP, embarqué dans le bundle.
- `assets/audio/demo-0*.wav` : fichiers audio de démonstration.
- `tool/generate_demo_audio.dart` : script de génération des audio de démo
  (`dart run tool/generate_demo_audio.dart`).

Le catalogue est donc **versionné dans le dépôt** : toute modification passe par
une nouvelle version de l'application (voir les conséquences dans le README).

## Tests

La suite (`flutter test`) couvre chaque couche :

- `test/app/` : widget test de la racine applicative ;
- `test/assets/` : validité du `catalog.json` embarqué ;
- `test/core/` : utilitaires (`collections`, `duration_formatter`) ;
- `test/features/…` : entités, sources de données, repositories, contrôleurs, écrans ;
- `test/helpers/fakes.dart` : doublures réutilisables des interfaces de `domain/`.

## Évolutions prévues

1. Étape 3 : implémentation `just_audio` de `AudioPlayerService` + mini-lecteur,
   décision sur la lecture en arrière-plan.
2. Étape 4 : implémentation `DownloadRepository` (copie locale + `sqflite`),
   `DownloadsController` et branchement de l'écran « Ma musique ».
3. Étape 5 : intégration, build release (`flutter build appbundle --release`).
