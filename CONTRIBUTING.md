# Guide de contribution — Artistsaas

Merci de votre intérêt pour **Artistsaas** ! Ce document décrit comment
installer, construire, tester et contribuer au code.

---

## 1. Prérequis

| Outil | Version |
| --- | --- |
| Flutter | 3.41.9 (stable) |
| Dart | 3.11.5 |
| Android SDK | 36.1.0 |
| Java | 21 (JBR) |
| Git | 2.x |

> **Important** : Riverpod 3.x n'est pas installable (nécessite Dart ≥ 3.12).
> Le projet reste sur Riverpod 2.6.1.

## 2. Installation

```bash
git clone https://github.com/TomkerDev/Artistsaas.git
cd Artistsaas
flutter pub get
```

## 3. Configuration à la compilation

Aucune clé n'est versionnée. Firebase et Supabase sont injectés par
`--dart-define` :

| Variable | Rôle |
| --- | --- |
| `FIREBASE_API_KEY` | SDK Firebase (Auth, Firestore, Storage) |
| `FIREBASE_APP_ID` | ID application Web Firebase |
| `FIREBASE_MESSAGING_SENDER_ID` | ID expéditeur |
| `FIREBASE_PROJECT_ID` | `novaa-music-tchaddd` |
| `FIREBASE_AUTH_DOMAIN` | `<projet>.firebaseapp.com` |
| `FIREBASE_STORAGE_BUCKET` | `<projet>.firebasestorage.app` |
| `SUPABASE_URL` | `https://<ref>.supabase.co` |
| `SUPABASE_ANON_KEY` | Clé publique du bucket `artist-media` |

> ⚠️ `String.fromEnvironment()` n'est substitué par le compilateur que dans un
> contexte `const`. Toujours déclarer :
> ```dart
> static const String key = String.fromEnvironment('FIREBASE_API_KEY');
> ```

## 4. Architecture du code

### 3 couches (clean architecture)

- **`domain/`** — Modèles et interfaces. Aucune dépendance à Flutter, `sqflite`,
  `just_audio` ou au système de fichiers.
- **`data/`** — Implémentations concrètes (assets, fichiers, base de données).
- **`presentation/`** — Écrans, contrôleurs et widgets.

L'UI ne parle jamais directement au stockage : elle passe par des
**contrôleurs** qui ne dépendent que des interfaces de `domain/`.

### Points d'entrée

| Fichier | Cible | Rôle |
| --- | --- | --- |
| `lib/main.dart` | Android | Application artiste (catalogue, lecteur, téléchargements) |
| `lib/main_admin.dart` | Flutter Web | Panneau d'administration (auth, publication, KPI) |

### Panneau d'administration (`lib/admin/`)

| Fichier | Rôle |
| --- | --- |
| `admin_routes.dart` | Constantes : `AdminScreenIds`, `AdminArtistOption`, `allAdminArtists` |
| `admin_upload_page.dart` | Publication d'un titre + **section KPI** (indicateurs clés) |
| `admin_login_page.dart` | Connexion Firebase Auth (e-mail + mot de passe) |

#### Section KPI — `admin_upload_page.dart`

La section KPI se compose de :

- **`_buildKpiSection`** — `StreamBuilder` qui écoute Firestore en temps réel
  sur la collection `tracks`.
- **`_computeKpis`** — Calcule totaux, albums distincts, artistes distincts,
  dernier morceau.
- **`_kpiLoadingSkeleton`** — Squelette de chargement (4 placeholders avec
  `CircularProgressIndicator`).
- **`_KpiGrid`** — Grille responsive via `LayoutBuilder` + `Wrap`.
- **`_StatCard`** — Carte visuelle (fond sombre, bordure fine, ombre).
- **`_KpiData`** / **`_StatCardData`** — Classes de données.

**Filtrage par rôle** :
- `agency_admin` + `assignedArtistId == 'all'` → tous les morceaux
- `artist` ou admin avec artiste spécifique → filtré par `artistId`

## 5. Convention de code

- **Dart format** : `dart format .` avant chaque commit.
- **Analyze** : `flutter analyze` (objectif : 0 erreur, 0 warning, 0 info).
- **Nomenclature** :
  - Variables/methods : `camelCase`
  - Classes : `PascalCase`
  - Fichiers : `snake_case.dart`
- **Imports** : ordre `dart:` → `package:` → `relative`.
- **Strings** : préférer l'interpolation `'$variable'` à la concaténation `+`.
- **Widgets** : utiliser `<Widget>[]` pour les listes typées, `const` lorsque
  possible.

## 6. Tests

```bash
flutter test               # Tous les tests
flutter test test/features/catalog/  # Tests d'une feature spécifique
flutter test --coverage    # Avec couverture
```

Structure des tests :
```
test/
├── app/            # Widget test de la racine
├── assets/         # Validité du catalog.json
├── core/           # Utilitaires
├── features/       # Entités, data sources, repos, écrans
│   ├── catalog/
│   ├── player/
│   └── library/
└── helpers/
    └── fakes.dart   # Doublures réutilisables
```

## 7. Commits

Utiliser le format **Conventional Commits** :

```
feat: ajouter la section KPI au panneau admin
fix: corriger le filtrage des morceaux par artiste
docs: mettre à jour l'architecture du panneau admin
style: appliquer dart format
refactor: extraire _computeKpis en méthode separer
test: ajouter un test pour le filtrage des morceaux
chore: mettre a jour les dependencies
```

| Type | Usage |
| --- | --- |
| `feat` | Nouvelle fonctionnalite |
| `fix` | Correction de bug |
| `docs` | Documentation |
| `style` | Formatage, espaces, etc. |
| `refactor` | Refactorisation sans changement de comportement |
| `test` | Ajout/modification de tests |
| `chore` | Taches diverses (dependances, config) |

## 8. Pieges connus

| Symptome | Cause | Solution |
| --- | --- | --- |
| `auth/invalid-api-key` | Build sans `--dart-define=FIREBASE_*` | Rebuilder avec toutes les variables |
| Upload 403 | `--dart-define=SUPABASE_*` manquant | Verifier les `String.fromEnvironment` en `const` |
| Cache fige | `immutable` sur `main.dart.js` | Verifier `firebase.json`, `Ctrl+Shift+R` |
| `ConstFinder failure` | `const_finder` absent | Passer `--no-tree-shake-icons` |
| Page blanche web | Cache du service worker | `Ctrl+Shift+R` |
| `Espace insuffisant` | Gradle necessite ~3 Go | Liberer de l'espace |

## 9. Build

### Panneau admin (web)

```powershell
flutter build web -t lib/main_admin.dart --release --no-tree-shake-icons `
  --dart-define=FIREBASE_API_KEY=... `
  --dart-define=FIREBASE_APP_ID=... `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... `
  --dart-define=FIREBASE_PROJECT_ID=novaa-music-tchaddd `
  --dart-define=FIREBASE_AUTH_DOMAIN=novaa-music-tchaddd.firebaseapp.com `
  --dart-define=FIREBASE_STORAGE_BUCKET=novaa-music-tchaddd.firebasestorage.app `
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=...

firebase deploy --only hosting --project novaa-music-tchaddd
```

### Application artiste (Android)

```bash
flutter build apk --flavor artist1 --release --no-tree-shake-icons
```