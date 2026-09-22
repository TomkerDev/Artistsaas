import 'dart:async';
import 'dart:convert';

import 'package:artistsaas/features/catalog/domain/datasources/catalog_data_source.dart';
import 'package:artistsaas/features/catalog/domain/entities/track.dart';
import 'package:artistsaas/features/catalog/domain/repositories/music_repository.dart';
import 'package:artistsaas/features/library/domain/entities/download_progress.dart';
import 'package:artistsaas/features/library/domain/entities/downloaded_track.dart';
import 'package:artistsaas/features/library/domain/repositories/download_repository.dart';
import 'package:artistsaas/features/player/domain/entities/loop_mode.dart';
import 'package:artistsaas/features/player/domain/entities/playback_media.dart';
import 'package:artistsaas/features/player/domain/entities/playback_source.dart';
import 'package:artistsaas/features/player/domain/entities/playback_state.dart';
import 'package:artistsaas/features/player/domain/services/audio_player_service.dart';
import 'package:artistsaas/features/player/domain/services/playback_source_resolver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Construit une piste de test, seules les valeurs utiles au cas testé étant
/// surchargées.
Track buildTrack({
  String id = 'track-1',
  String title = 'Titre de test',
  String artistName = 'Artiste de test',
  String? album = 'Album de test',
  int? trackNumber,
  int? releaseYear,
  Duration duration = const Duration(seconds: 30),
  String? coverAsset,
  Uri? audioUrl,
  String? audioAssetPath,
  bool isDownloadable = true,
  bool isNew = false,
  bool isDownloaded = false,
}) {
  return Track(
    id: id,
    title: title,
    artistName: artistName,
    album: album,
    trackNumber: trackNumber,
    releaseYear: releaseYear,
    duration: duration,
    coverAsset: coverAsset,
    audioUrl: audioUrl,
    audioAssetPath: audioAssetPath ?? 'assets/audio/$id.wav',
    isDownloadable: isDownloadable,
    isNew: isNew,
    isDownloaded: isDownloaded,
  );
}

/// Source de catalogue pilotée par le test : liste fixe, panne simulée, et
/// comptage des lectures pour vérifier la mise en cache.
final class FakeCatalogDataSource implements CatalogDataSource {
  FakeCatalogDataSource({List<Track>? tracks, this.failure})
    : tracks = tracks ?? const <Track>[];

  /// Nombre de lectures demandées à la source.
  int fetchCount = 0;

  /// Pistes renvoyées lors des prochaines lectures.
  List<Track> tracks;

  /// Erreur levée lors des prochaines lectures, `null` pour réussir.
  Object? failure;

  @override
  Future<List<Track>> fetchTracks() async {
    fetchCount++;
    final Object? currentFailure = failure;
    if (currentFailure != null) {
      throw currentFailure;
    }
    return tracks;
  }
}

/// Dépôt de catalogue factice, utilisé par les tests de contrôleur et d'écran.
final class FakeMusicRepository implements MusicRepository {
  FakeMusicRepository({List<Track>? tracks, this.failure})
    : tracks = tracks ?? const <Track>[];

  /// Nombre d'appels reçus.
  int callCount = 0;

  /// Pistes renvoyées lors des prochains appels.
  List<Track> tracks;

  /// Erreur levée lors des prochains appels, `null` pour réussir.
  Object? failure;

  @override
  Future<List<Track>> getTracks() async {
    callCount++;
    final Object? currentFailure = failure;
    if (currentFailure != null) {
      throw currentFailure;
    }
    return tracks;
  }
}

/// Bundle d'assets en mémoire.
///
/// Permet de tester la lecture du catalogue sans dépendre du regroupement
/// d'assets produit par la compilation.
final class InMemoryAssetBundle extends CachingAssetBundle {
  InMemoryAssetBundle(this._entries);

  final Map<String, String> _entries;

  @override
  Future<ByteData> load(String key) async {
    final String? content = _entries[key];
    if (content == null) {
      throw FlutterError('Asset absent du bundle de test : $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
  }
}

/// Dépôt de téléchargement factice : stockage en mémoire du chemin « local ».
final class FakeDownloadRepository implements DownloadRepository {
  final StreamController<List<DownloadedTrack>> _tracksController =
      StreamController<List<DownloadedTrack>>.broadcast();

  final StreamController<Map<String, DownloadProgress>> _progressController =
      StreamController<Map<String, DownloadProgress>>.broadcast();

  final Map<String, DownloadedTrack> _stored = <String, DownloadedTrack>{};
  final Map<String, DownloadProgress> _progress = <String, DownloadProgress>{};

  /// Nombre d'appels à [download], pour vérifier l'idempotence.
  int downloadCount = 0;

  /// Nombre d'appels à [deleteDownload].
  int deleteCount = 0;

  /// Échec à lever au prochain appel de [download].
  Object? downloadFailure;

  /// Ajoute directement une copie locale, sans passer par [download].
  void addDownloaded(Track track) {
    final DownloadedTrack downloaded = DownloadedTrack(
      track: track,
      localPath: '/tmp/${track.id}.mp3',
      fileSizeBytes: 1024,
      downloadedAt: DateTime(2026, 1, 1),
    );
    _stored[track.id] = downloaded;
    _tracksController.add(List<DownloadedTrack>.unmodifiable(_stored.values));
    _progress[track.id] = DownloadProgress(
      trackId: track.id,
      state: DownloadState.completed,
      receivedBytes: 1024,
      totalBytes: 1024,
    );
    _progressController.add(
      Map<String, DownloadProgress>.unmodifiable(_progress),
    );
  }

  @override
  Future<void> download(Track track) async {
    downloadCount++;
    final Object? failure = downloadFailure;
    if (failure != null) {
      throw failure;
    }
    addDownloaded(track);
  }

  @override
  Future<void> deleteDownload(String trackId) async {
    deleteCount++;
    _stored.remove(trackId);
    _progress.remove(trackId);
    _tracksController.add(List<DownloadedTrack>.unmodifiable(_stored.values));
    _progressController.add(
      Map<String, DownloadProgress>.unmodifiable(_progress),
    );
  }

  @override
  Future<String?> getLocalPath(String trackId) async =>
      _stored[trackId]?.localPath;

  @override
  Future<Set<String>> getDownloadedTrackIds() async => _stored.keys.toSet();

  @override
  Stream<List<DownloadedTrack>> watchDownloadedTracks() async* {
    yield List<DownloadedTrack>.unmodifiable(_stored.values);
    yield* _tracksController.stream;
  }

  @override
  Stream<Map<String, DownloadProgress>> watchProgress() async* {
    yield Map<String, DownloadProgress>.unmodifiable(_progress);
    yield* _progressController.stream;
  }

  /// Libère les contrôleurs à la fin du test.
  void dispose() {
    _tracksController.close();
    _progressController.close();
  }
}

/// Résolveur de sources factice : asset pour chaque piste.
final class FakePlaybackSourceResolver implements PlaybackSourceResolver {
  int resolveCount = 0;

  @override
  Future<PlaybackMedia> resolve(Track track) async {
    resolveCount++;
    return PlaybackMedia(
      trackId: track.id,
      title: track.title,
      artist: track.artistName,
      source: AssetPlaybackSource(track.audioAssetPath),
      artAsset: track.coverAsset,
    );
  }
}

/// Moteur audio factice : publie ses propres états via le flux.
final class FakeAudioPlayerService implements AudioPlayerService {
  PlaybackState _state = const PlaybackState();

  final StreamController<PlaybackState> _states =
      StreamController<PlaybackState>.broadcast();

  /// Nombre de files préparées.
  int setQueueCount = 0;

  /// Nombre de commandes play / pause.
  int playCount = 0;
  int pauseCount = 0;
  int stopCount = 0;

  /// Dernier index demandé à [setQueue].
  int lastInitialIndex = 0;

  /// Échec à lever au prochain appel de [setQueue].
  Object? setQueueFailure;

  /// Publie un état dans le flux, comme le ferait le vrai moteur.
  void emit(PlaybackState state) {
    _state = state;
    _states.add(state);
  }

  @override
  PlaybackState get state => _state;

  @override
  Stream<PlaybackState> get stateStream => _states.stream;

  @override
  Future<void> setQueue(
    List<PlaybackMedia> queue, {
    int initialIndex = 0,
  }) async {
    setQueueCount++;
    lastInitialIndex = initialIndex;
    final Object? failure = setQueueFailure;
    if (failure != null) {
      throw failure;
    }
    emit(
      PlaybackState(
        queue: List<PlaybackMedia>.unmodifiable(queue),
        currentIndex: initialIndex,
      ),
    );
  }

  @override
  Future<void> play() async {
    playCount++;
    emit(_state.copyWith(isPlaying: true));
  }

  @override
  Future<void> pause() async {
    pauseCount++;
    emit(_state.copyWith(isPlaying: false));
  }

  @override
  Future<void> seek(Duration position) async {
    emit(_state.copyWith(position: position));
  }

  @override
  Future<void> skipToNext() async {
    if (!_state.hasNext) {
      return;
    }
    emit(
      _state.copyWith(
        currentIndex: _state.currentIndex! + 1,
        position: Duration.zero,
      ),
    );
  }

  @override
  Future<void> skipToPrevious() async {
    if (!_state.hasPrevious) {
      return;
    }
    emit(
      _state.copyWith(
        currentIndex: _state.currentIndex! - 1,
        position: Duration.zero,
      ),
    );
  }

  @override
  Future<void> stop() async {
    stopCount++;
    emit(
      _state.copyWith(
        isPlaying: false,
        isBuffering: false,
        position: Duration.zero,
      ),
    );
  }

  @override
  Future<void> setLoopMode(LoopMode mode) async {
    emit(_state.copyWith(loopMode: mode));
  }

  @override
  Future<void> setShuffleModeEnabled(bool enabled) async {
    emit(_state.copyWith(shuffleEnabled: enabled));
  }

  @override
  Future<void> dispose() async {
    await _states.close();
  }
}
