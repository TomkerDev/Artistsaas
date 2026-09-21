import 'package:artistsaas/core/errors/app_exception.dart';
import 'package:artistsaas/features/catalog/data/repositories/music_repository_impl.dart';
import 'package:artistsaas/features/catalog/domain/entities/track.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fakes.dart';

void main() {
  group('MusicRepositoryImpl', () {
    test('renvoie les pistes fournies par la source', () async {
      final FakeCatalogDataSource source = FakeCatalogDataSource(
        tracks: <Track>[
          buildTrack(id: 'a'),
          buildTrack(id: 'b'),
        ],
      );

      final List<Track> tracks = await MusicRepositoryImpl(source).getTracks();

      expect(tracks, hasLength(2));
      expect(tracks.first.id, 'a');
    });

    test('ne lit la source qu\'une seule fois (mise en cache)', () async {
      final FakeCatalogDataSource source = FakeCatalogDataSource(
        tracks: <Track>[buildTrack()],
      );
      final MusicRepositoryImpl repository = MusicRepositoryImpl(source);

      await repository.getTracks();
      await repository.getTracks();

      expect(source.fetchCount, 1);
    });

    test('deux appels simultanés ne déclenchent qu\'une lecture', () async {
      final FakeCatalogDataSource source = FakeCatalogDataSource(
        tracks: <Track>[buildTrack()],
      );
      final MusicRepositoryImpl repository = MusicRepositoryImpl(source);

      await Future.wait(<Future<List<Track>>>[
        repository.getTracks(),
        repository.getTracks(),
      ]);

      expect(source.fetchCount, 1);
    });

    test('renvoie une liste non modifiable', () async {
      final List<Track> tracks = await MusicRepositoryImpl(
        FakeCatalogDataSource(tracks: <Track>[buildTrack()]),
      ).getTracks();

      expect(() => tracks.add(buildTrack(id: 'autre')), throwsUnsupportedError);
    });

    test('propage l\'erreur de la source', () async {
      final MusicRepositoryImpl repository = MusicRepositoryImpl(
        FakeCatalogDataSource(
          failure: const CatalogException('Catalogue illisible'),
        ),
      );

      await expectLater(
        repository.getTracks(),
        throwsA(isA<CatalogException>()),
      );
    });

    test('ne mémorise pas un échec : le réessai relit la source', () async {
      final FakeCatalogDataSource source = FakeCatalogDataSource(
        failure: const CatalogException('Catalogue illisible'),
      );
      final MusicRepositoryImpl repository = MusicRepositoryImpl(source);

      await expectLater(
        repository.getTracks(),
        throwsA(isA<CatalogException>()),
      );

      source
        ..failure = null
        ..tracks = <Track>[buildTrack()];

      expect(await repository.getTracks(), hasLength(1));
      expect(source.fetchCount, 2);
    });
  });
}
