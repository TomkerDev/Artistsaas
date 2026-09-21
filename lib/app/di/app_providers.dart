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
import '../../features/library/data/local_download_repository.dart';
import '../../features/library/domain/repositories/download_repository.dart';
import '../../features/player/data/default_playback_source_resolver.dart';
import '../../features/player/data/just_audio_player_service.dart';
import '../../features/player/domain/services/audio_player_service.dart';
import '../../features/player/domain/services/playback_source_resolver.dart';

/// Source brute du catalogue : fichier JSON embarqué dans les assets.
final Provider<CatalogDataSource> catalogDataSourceProvider =
    Provider<CatalogDataSource>((Ref ref) => const AssetCatalogDataSource());

/// Accès au catalogue musical, avec mise en cache du contenu embarqué.
final Provider<MusicRepository> musicRepositoryProvider =
    Provider<MusicRepository>(
      (Ref ref) => MusicRepositoryImpl(ref.watch(catalogDataSourceProvider)),
    );

/// Index local des morceaux matérialisés (base `sqflite` + stockage privé).
final Provider<DownloadRepository> downloadRepositoryProvider =
    Provider<DownloadRepository>((Ref ref) {
      final LocalDownloadRepository repository = LocalDownloadRepository();
      ref.onDispose(repository.dispose);
      return repository;
    });

/// Moteur audio concret (`just_audio`), unique pour toute l'application.
///
/// Le moteur est instancié à la première commande de lecture (`ref.read` depuis
/// le contrôleur), d'où un `Provider` paresseux dont la libération est
/// enregistrée sur le conteneur.
final Provider<AudioPlayerService> audioPlayerServiceProvider =
    Provider<AudioPlayerService>((Ref ref) {
      final JustAudioPlayerService service = JustAudioPlayerService();
      ref.onDispose(service.dispose);
      return service;
    });

/// Résolution des sources de lecture : copie locale, distant puis embarqué.
final Provider<PlaybackSourceResolver> playbackSourceResolverProvider =
    Provider<PlaybackSourceResolver>(
      (Ref ref) => DefaultPlaybackSourceResolver(
        ref.watch(downloadRepositoryProvider),
      ),
    );
