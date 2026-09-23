import 'dart:convert';

import 'package:artistsaas/core/errors/app_exception.dart';
import 'package:artistsaas/features/catalog/data/datasources/local_catalog_data_source.dart';
import 'package:artistsaas/features/catalog/domain/entities/track.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fakes.dart';

void main() {
  const String path = LocalCatalogDataSource.defaultAssetPath;

  LocalCatalogDataSource sourceWith(String content) => LocalCatalogDataSource(
    bundle: InMemoryAssetBundle(<String, String>{path: content}),
  );

  String encode(List<Map<String, dynamic>> entries) => jsonEncode(entries);

  Map<String, dynamic> rawTrack({String id = 'demo-01'}) => <String, dynamic>{
    'id': id,
    'title': 'Titre',
    'artist': 'Artiste',
    'duration_ms': 30000,
    'audio_asset': 'assets/audio/$id.wav',
  };

  group('AssetCatalogDataSource', () {
    test('lit les pistes du catalogue embarqué', () async {
      final LocalCatalogDataSource source = sourceWith(
        encode(<Map<String, dynamic>>[rawTrack(), rawTrack(id: 'demo-02')]),
      );

      final List<Track> tracks = await source.fetchTracks();

      expect(tracks, hasLength(2));
      expect(tracks.first.id, 'demo-01');
      expect(tracks.last.id, 'demo-02');
      expect(tracks.first.duration, const Duration(seconds: 30));
    });

    test('renvoie une liste vide lorsque le catalogue est vide', () async {
      expect(await sourceWith('[]').fetchTracks(), isEmpty);
    });

    test('accepte un chemin d\'asset personnalisé', () async {
      const String customPath = 'assets/catalog/autre.json';
      final LocalCatalogDataSource source = LocalCatalogDataSource(
        assetPath: customPath,
        bundle: InMemoryAssetBundle(<String, String>{
          customPath: encode(<Map<String, dynamic>>[rawTrack()]),
        }),
      );

      expect(await source.fetchTracks(), hasLength(1));
    });

    test('échoue lorsque l\'asset est absent', () async {
      final LocalCatalogDataSource source = LocalCatalogDataSource(
        bundle: InMemoryAssetBundle(const <String, String>{}),
      );

      await expectLater(source.fetchTracks(), throwsA(isA<CatalogException>()));
    });

    test('échoue lorsque le JSON est invalide', () async {
      await expectLater(
        sourceWith('{ ceci n\'est pas du JSON').fetchTracks(),
        throwsA(isA<CatalogException>()),
      );
    });

    test('échoue lorsque la racine n\'est pas une liste', () async {
      await expectLater(
        sourceWith('{"tracks": []}').fetchTracks(),
        throwsA(isA<CatalogException>()),
      );
    });

    test('échoue lorsqu\'une entrée n\'est pas un objet', () async {
      await expectLater(
        sourceWith('[1, 2]').fetchTracks(),
        throwsA(isA<CatalogException>()),
      );
    });

    test('propage l\'erreur d\'une entrée invalide', () async {
      final LocalCatalogDataSource source = sourceWith(
        encode(<Map<String, dynamic>>[
          rawTrack(),
          <String, dynamic>{'id': 'sans-titre'},
        ]),
      );

      await expectLater(source.fetchTracks(), throwsA(isA<CatalogException>()));
    });
  });
}
