# Artistsaas — application officielle de l'artiste

Application Android (Flutter) permettant de consulter le catalogue musical de
l'artiste, de l'écouter dans un lecteur intégré et de retrouver les morceaux
téléchargés hors connexion.

## État d'avancement

| Étape | Périmètre | État |
| --- | --- | --- |
| 0 | Squelette du projet Android, thème, coquille à 3 onglets | **réalisée** |
| 1 | Modèles et contrats de domaine (`Track`, `PlaybackState`, interfaces) | **réalisée** |
| 2 | Catalogue local (`catalog.json` + audio en assets) et écran Accueil | **réalisée** |
| 3 | Moteur audio `just_audio`, écran Lecteur, mini-lecteur | **réalisée** |
| 4 | Téléchargements (copie locale + `sqflite`) et écran Ma musique | **réalisée** |
| 5 | Intégration, README complet, build release | à venir |

## Décisions actées

| Sujet | Décision |
| --- | --- |
| Plateforme | Android uniquement (`flutter create --platforms=android`) |
| `applicationId` | `com.tomker.artistsaas` |
| `minSdk` / `targetSdk` / `compileSdk` | `24` / `36` / `36` |
| Nom affiché | `Artistsaas` — **provisoire**, en attente du nom de scène définitif |
| Contenu | 100 % embarqué : `assets/catalog/catalog.json` + MP3 dans `assets/audio/` |
| Gestion d'état et injection | `flutter_riverpod` 2.6.1 |
| Moteur audio | `just_audio` 0.10.6 |
| Persistance locale | `sqflite` + `path_provider` |
| Lecture en arrière-plan | **non tranché** (décision attendue avant l'étape 3) |

### Conséquences du contenu embarqué

- L'application fonctionne hors connexion **dès l'installation**.
- « Télécharger » signifie donc **matérialiser** le morceau dans le stockage privé
  de l'application (`<documents>/downloads/<id>.mp3`), avec suivi de la taille et
  suppression possible. Le jour où les sources deviendront distantes, le même
  bouton et le même écran deviendront un véritable téléchargement réseau.
- Métadonnées télémétriques : **aucune** permission de stockage n'est requise
  (dossier privé de l'application), ni permission `INTERNET` en release.
- Toute modification du catalogue nécessite une nouvelle version de l'application.
- Les MP3 présents dans l'AAB sont extractibles par un utilisateur averti :
  **aucune protection de contenu** dans ce modèle.
- Les fichiers audio sont versionnés dans le dépôt : compter ≈ 1 Mo par minute en
  128 kbps, soit ≈ 3,5 Mo pour un morceau de 3 min 30.

## Architecture cible

> Détail complet des couches, features et conventions : voir
> [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

Trois features (`catalog`, `player`, `library`), chacune découpée en trois couches :

- `domain/` — modèles et **interfaces**. Aucune dépendance à Flutter, `sqflite`,
  `just_audio` ou au système de fichiers ;
- `data/` — implémentations concrètes (assets, fichiers, base de données) ;
- `presentation/` — écrans, contrôleurs et widgets.

L'interface utilisateur ne parle jamais directement au stockage ni au moteur
audio : elle passe par des contrôleurs qui ne dépendent que des interfaces de
`domain/`. Le remplacement du catalogue embarqué par une API distante
(NestJS/PostgreSQL) consiste donc à fournir une nouvelle implémentation de
`CatalogDataSource` / `MusicRepository`, sans toucher aux écrans.

```
lib/
├── main.dart                  # bootstrap + ProviderScope
├── app/                       # racine applicative : app, thème, coquille, DI
├── core/                      # constantes, utilitaires, erreurs transverses
└── features/
    ├── catalog/               # catalogue musical          → écran Accueil
    ├── player/                # moteur audio et lecture    → écran Lecteur
    └── library/               # téléchargements            → écran Ma musique
```

## Commandes

```bash
flutter pub get
flutter analyze          # 0 issue attendu
flutter test             # tests unitaires et widget
flutter run -d Pixel_9   # émulateur Android (Pixel_6, Pixel_Tablet disponibles)
flutter build apk --debug
flutter build appbundle --release
```

## Contraintes de l'environnement

- Flutter 3.41.9 (stable) / Dart 3.11.5 — Android SDK 36.1.0, Java 21 (JBR).
- `flutter_riverpod` 3.x **n'est pas installable** : elle exige Dart ≥ 3.12.
  Le projet reste donc sur Riverpod 2.6.1 (API `Notifier`/`AsyncNotifier` 2.x).
