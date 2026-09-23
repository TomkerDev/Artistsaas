# Novaa — application officielle de l'artiste

Application Android (Flutter) permettant de consulter le catalogue musical de
l'artiste, de l'écouter dans un lecteur intégré et de retrouver les morceaux
téléchargés hors connexion.

Le dépôt héberge également le **panneau d'administration** (Flutter Web), qui
permet à l'agence et aux artistes de publier titres et pochettes depuis un
navigateur : voir [Build et déploiement](#build-et-déploiement).

## État d'avancement

| Étape | Périmètre | État |
| --- | --- | --- |
| 0 | Squelette du projet Android, thème, coquille à 3 onglets | **réalisée** |
| 1 | Modèles et contrats de domaine (`Track`, `PlaybackState`, interfaces) | **réalisée** |
| 2 | Catalogue local (`catalog.json` + audio en assets) et écran Accueil | **réalisée** |
| 3 | Moteur audio `just_audio`, écran Lecteur, mini-lecteur | **réalisée** |
| 4 | Téléchargements (copie locale + `sqflite`) et écran Ma musique | **réalisée** |
| 5 | Intégration, README complet, build release | **réalisée** |
| 6 | Firebase (Auth, Firestore, Storage) + Supabase Storage pour les médias | **réalisée** |
| 7 | Panneau d'administration web (connexion + publication) déployé sur Firebase Hosting | **réalisée** |
| 8 | Distribution multi-artistes : une application Android par flavor | **réalisée** |

## Décisions actées

| Sujet | Décision |
| --- | --- |
| Plateforme | Android uniquement (`flutter create --platforms=android`) |
| `applicationId` | `com.tomker.artistsaas` |
| `minSdk` / `targetSdk` / `compileSdk` | `24` / `36` / `36` |
| Nom affiché | `Novaa` (nom de scène retenu pour la démo) — `android:label` et `AppStrings.appTitle` alignés |
| Contenu | catalogue partagé embarqué (`assets/catalog/catalog.json`) + audio de démo ; les titres publiés arrivent de Firestore et Supabase Storage |
| Gestion d'état et injection | `flutter_riverpod` 2.6.1 |
| Moteur audio | `just_audio` 0.10.6 |
| Persistance locale | `sqflite` + `path_provider` |
| Lecture en arrière-plan | `just_audio_background` + `audio_service` (service natif + notification média + boutons casque/Bluetooth) |
| Backend applicatif | Firebase, projet `novaa-music-tchaddd` : Auth (connexion admin), Firestore (publication, nouveautés), Storage |
| Médias lourds | Supabase Storage, bucket public `artist-media` (MP3 + pochettes) — offre gratuite 5 Go |
| Panneau d'administration | application **Flutter Web distincte** (`lib/main_admin.dart`), déployée sur Firebase Hosting |
| Distribution | une application par artiste via les *flavors* Android (identifiant, nom et icône propres) |

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
├── main.dart                  # entrée de l'application artiste + ProviderScope
├── main_admin.dart            # entrée du panneau d'administration (web)
├── firebase_options.dart      # options Firebase résolues par plateforme (--dart-define)
├── admin/                     # écrans du panneau d'administration (connexion, publication)
├── services/                  # services transverses (Supabase Storage)
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
flutter analyze          # 10 infos connues, 0 erreur
flutter test             # tests unitaires et widget
flutter run -d Pixel_9   # émulateur Android (Pixel_6, Pixel_Tablet disponibles)
flutter build apk --flavor artist1 --release --no-tree-shake-icons
```

> `--no-tree-shake-icons` est **obligatoire sur ce poste** : voir
> [Pièges connus](#pièges-connus).

## Configuration à la compilation

Aucune clé n'est versionnée : Firebase et Supabase sont injectés par
`--dart-define` au moment du build.

| Variable | Rôle |
| --- | --- |
| `FIREBASE_API_KEY` | SDK Firebase (Auth, Firestore, Storage) |
| `FIREBASE_APP_ID` | identifiant de l'application Web Firebase |
| `FIREBASE_MESSAGING_SENDER_ID` | identifiant d'expéditeur du projet |
| `FIREBASE_PROJECT_ID` | `novaa-music-tchaddd` |
| `FIREBASE_AUTH_DOMAIN` | `<projet>.firebaseapp.com` |
| `FIREBASE_STORAGE_BUCKET` | `<projet>.firebasestorage.app` |
| `SUPABASE_URL` | `https://<ref>.supabase.co` |
| `SUPABASE_ANON_KEY` | clé publique (`anon`) du projet Supabase |

> ⚠️ `String.fromEnvironment()` n'est substitué par le compilateur **que dans un
> contexte `const`**. Déclarez toujours `static const String x =
> String.fromEnvironment('X')` plutôt qu'un appel dans un getter : hors contexte
> `const`, la valeur renvoyée est la valeur par défaut (`''`) et le service
> reste silencieusement non configuré dans le build publié.

## Build et déploiement

### Panneau d'administration (web)

```powershell
flutter build web -t lib/main_admin.dart --release --no-tree-shake-icons `
  --dart-define=FIREBASE_API_KEY=...                 `
  --dart-define=FIREBASE_APP_ID=...                  `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=...     `
  --dart-define=FIREBASE_PROJECT_ID=novaa-music-tchaddd `
  --dart-define=FIREBASE_AUTH_DOMAIN=novaa-music-tchaddd.firebaseapp.com `
  --dart-define=FIREBASE_STORAGE_BUCKET=novaa-music-tchaddd.firebasestorage.app `
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=...

firebase deploy --only hosting --project novaa-music-tchaddd
```

Publication : <https://novaa-music-tchaddd.web.app>

Les en-têtes de cache de `firebase.json` sont **indispensables** :
`flutter_bootstrap.js` charge `main.dart.js` sans paramètre de version, donc
tout cache `immutable` sur les `.js` figerait l'application pour un an. Sont
servis en `no-cache` : `/`, `/index.html`, `/main.dart.js`,
`/flutter_bootstrap.js`, `/flutter_service_worker.js`, `/flutter.js`,
`/version.json`. Le reste (polices, images, `canvaskit/`) est immuable.
À noter : Hosting applique les règles d'en-tête sur **l'URL demandée, avant les
rewrites** — d'où la règle explicite sur `/` en plus de `/index.html`.

### Applications artistes (Android)

Une application par artiste : même base de code, identité choisie par le flavor
(`applicationId`, nom affiché, icône).

```powershell
flutter build apk --flavor dilson_le_mustang -t lib/main.dart --release --no-tree-shake-icons
flutter build apk --flavor jethsonat        -t lib/main.dart --release --no-tree-shake-icons
```

Sortie : `build/app/outputs/flutter-apk/app-<flavor>-release.apk` (≈ 55 Mo,
ABI `arm64-v8a`, `armeabi-v7a` et `x86_64`, `targetSdk 36`). Le contenu embarqué
étant partagé, aucun `--dart-define` n'est requis pour un APK : l'identité vient
du flavor et le catalogue distant de Firestore.

> Les APK vivent sous `build/`, que `flutter clean` efface : **copiez-les hors
> de `build/`** dès qu'ils sont produits.

## Pièges connus

| Symptôme | Cause | Correctif |
| --- | --- | --- |
| `auth/invalid-api-key` dans le panneau admin | build sans les `--dart-define=FIREBASE_*` | recompiler avec toutes les variables ci-dessus |
| Upload Supabase en échec (403, bucket introuvable) | `String.fromEnvironment` appelé hors contexte `const`, ou `--dart-define=SUPABASE_*` manquant | déclarer la valeur en `static const` puis recompiler avec les defines |
| Le navigateur sert une ancienne version du panneau | cache `immutable` sur `main.dart.js` | vérifier les en-têtes de `firebase.json`, puis `Ctrl+Shift+R` |
| `IconTreeShakerException: ConstFinder failure` | `const_finder.dart.snapshot` absent de `bin/cache/artifacts/engine/windows-x64/` (le *snapshot* n'est plus fourni par les artefacts de l'engine, et `flutter precache` ne le restaure pas) | passer `--no-tree-shake-icons` (coût : ≈ 1,6 Mo par artefact) |
| `Execution failed for task … Espace insuffisant sur le disque` | Gradle réclame ≈ 3 Go libres pour un APK release | libérer de l'espace, puis relancer : les tâches déjà produites sont réutilisées |
| Panneau admin : page blanche au premier chargement | ancien *service worker* et modules WASM en cache | `Ctrl+Shift+R` |

## Contraintes de l'environnement

- Flutter 3.41.9 (stable) / Dart 3.11.5 — Android SDK 36.1.0, Java 21 (JBR).
- `flutter_riverpod` 3.x **n'est pas installable** : elle exige Dart ≥ 3.12.
  Le projet reste donc sur Riverpod 2.6.1 (API `Notifier`/`AsyncNotifier` 2.x).
- Poste de développement modeste : **8 Go de RAM** et disque quasi plein.
  `android/gradle.properties` est calibré en conséquence (`-Xmx1536m`) et un
  build APK release exige ≈ 3 Go libres. En cas de manque d'espace,
  `system-images` du SDK Android (9,9 Go d'images d'émulateur) est le premier
  candidat à la suppression : il est **sans effet** sur les builds APK.
- `android/gradle.properties` active `-XX:+HeapDumpOnOutOfMemoryError` : sur un
  disque saturé, un OOM peut écrire un *heap dump* de ≈ 1,5 Go. À retirer si
  l'espace devient critique.
