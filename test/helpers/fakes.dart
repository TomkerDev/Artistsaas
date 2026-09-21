import 'dart:convert';
import 'dart:typed_data';

import 'package:artistsaas/features/catalog/domain/datasources/catalog_data_source.dart';
import 'package:artistsaas/features/catalog/domain/entities/track.dart';
import 'package:artistsaas/features/catalog/domain/repositories/music_repository.dart';
import 'package:flutter/services.dart';

/// Construit une piste de test, seules les valeurs utiles au cas testé étant
/// surchargées.
Track buildTrack({
  String id = 'track-1',
  String title = 'Titre de test',
  String artist = 'Artiste de test',
  String? album = 'Album de test',
  int? trackNumber,
  int? releaseYear,
  Duration duration = const Duration(seconds: 30),
  String? coverAsset,
  Uri? audioUrl,
  String? audioAsset,
  bool isDownloadable = true,
}) {
  return Track(
    id: id,
    title: title,
    artist: artist,
    album: album,
    trackNumber: trackNumber,
    releaseYear: releaseYear,
    duration: duration,
    coverAsset: coverAsset,
    audioUrl: audioUrl,
    audioAsset: audioAsset ?? 'assets/audio/$id.wav',
    isDownloadable: isDownloadable,
  );
}

/// Source de catalogue pilotée par le test : liste fixe, panne simulée, et
/// comptage des lectures pour vérifier la mise en cache.
final class FakeCatalogDataSource implements CatalogDataSource {
  FakeCatalogDataSource({List<Track>? tracks, Object? failure})
    : _tracks = tracks ?? const <Track>[],
      _failure = failure;

  List<Track> _tracks;
  Object? _failure;

  /// Nombre de lectures demandées à la source.
  int fetchCount = 0;

  /// Pistes renvoyées lors des prochaines lectures.
  List<Track> get tracks => _tracks;
  set tracks(List<Track> value) => _tracks = value;

  /// Erreur levée lors des prochaines lectures, `null` pour réussir.
  Object? get failure => _failure;
  set failure(Object? value) => _failure = value;

  @override
  Future<List<Track>> fetchTracks() async {
    fetchCount++;
    final Object? failure = _failure;
    if (failure != null) {
      throw failure;
    }
    return _tracks;
  }
}

/// Dépôt de catalogue factice, utilisé par les tests de contrôleur et d'écran.
final class FakeMusicRepository implements MusicRepository {
  FakeMusicRepository({List<Track>? tracks, Object? failure})
    : _tracks = tracks ?? const <Track>[],
      _failure = failure;

  List<Track> _tracks;
  Object? _failure;

  /// Nombre d'appels reçus.
  int callCount = 0;

  /// Pistes renvoyées lors des prochains appels.
  List<Track> get tracks => _tracks;
  set tracks(List<Track> value) => _tracks = value;

  /// Erreur levée lors des prochains appels, `null` pour réussir.
  Object? get failure => _failure;
  set failure(Object? value) => _failure = value;

  @override
  Future<List<Track>> getTracks() async {
    callCount++;
    final Object? failure = _failure;
    if (failure != null) {
      throw failure;
    }
    return _tracks;
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
