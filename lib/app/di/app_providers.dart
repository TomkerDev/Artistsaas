/// Composition root de l'application.
///
/// C'est le **seul** endroit où les implémentations concrètes sont choisies : les
/// écrans et les contrôleurs ne dépendent que des interfaces de `domain/`. Le
/// passage à un catalogue distant (API NestJS) se limite donc à ces deux
/// déclarations, sans toucher aux écrans ni au lecteur.
///
/// Sens de dépendance : `presentation` → `app/di` → `data` → `domain`. Les
/// couches `data/` et `domain/` n'importent jamais `app/`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/catalog/data/datasources/asset_catalog_data_source.dart';
import '../../features/catalog/data/repositories/music_repository_impl.dart';
import '../../features/catalog/domain/datasources/catalog_data_source.dart';
import '../../features/catalog/domain/repositories/music_repository.dart';

/// Source brute du catalogue : fichier JSON embarqué dans les assets.
final Provider<CatalogDataSource> catalogDataSourceProvider =
    Provider<CatalogDataSource>((Ref ref) => const AssetCatalogDataSource());

/// Accès au catalogue musical, avec mise en cache du contenu embarqué.
final Provider<MusicRepository> musicRepositoryProvider =
    Provider<MusicRepository>(
      (Ref ref) => MusicRepositoryImpl(ref.watch(catalogDataSourceProvider)),
    );
