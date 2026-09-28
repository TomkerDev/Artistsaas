import 'package:artistsaas/core/errors/app_exception.dart';
import 'package:artistsaas/features/catalog/data/repositories/track_repository_impl.dart';
import 'package:artistsaas/features/catalog/domain/datasources/remote_catalog_data_source.dart';
import 'package:artistsaas/features/catalog/domain/entities/track.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fakes.dart';

/// Source distante pilotée par le test : nouveautés publiées après le build.
final class _FakeRemoteCatalogDataSource implements RemoteCatalogDataSource {
  _FakeRemoteCatalogDataSource(
      {this.newTracks = const <Track>[], this.failure});

  List<Track> newTracks;
  Object? failure;

  @override
  Future<List<Track>> fetchNewTracks(String artistId) async {
    final Object? currentFailure = failure;
    if (currentFailure != null) {
      throw currentFailure;
    }
    return newTracks;
  }
}

TrackRepositoryImpl repositoryWith(
  FakeCatalogDataSource local, {
  List<Track> newTracks = const <Track>[],
  Object? remoteFailure,
  FakeDownloadRepository? downloads,
  bool? streamOnly,
}) {
  return TrackRepositoryImpl(
    local: local,
    remote: _FakeRemoteCatalogDataSource(
      newTracks: newTracks,
      failure: remoteFailure,
    ),
    downloads: downloads ?? FakeDownloadRepository(),
    artistId: 'artist_test',
    streamOnly: streamOnly,
  );
}

void main() {
  group('TrackRepositoryImpl (ex MusicRepositoryImpl)', () {
    test('renvoie les pistes du catalogue embarqué', () async {
      final FakeCatalogDataSource source = FakeCatalogDataSource(
        tracks: <Track>[buildTrack(id: 'a'), buildTrack(id: 'b')],
      );

      final List<Track> tracks = await repositoryWith(source).getTracks();

      expect(tracks, hasLength(2));
      expect(tracks.first.id, 'a');
      expect(tracks.last.id, 'b');
    });

    test('ne lit le catalogue embarqué qu\'une seule fois (mise en cache)',
        () async {
      final FakeCatalogDataSource source = FakeCatalogDataSource(
        tracks: <Track>[buildTrack()],
      );
      final TrackRepositoryImpl repository = repositoryWith(source);

      await repository.getTracks();
      await repository.getTracks();

      expect(source.fetchCount, 1);
    });

    test('deux appels simultanés ne déclenchent qu\'une lecture', () async {
      final FakeCatalogDataSource source = FakeCatalogDataSource(
        tracks: <Track>[buildTrack()],
      );
      final TrackRepositoryImpl repository = repositoryWith(source);

      await Future.wait(<Future<List<Track>>>[
        repository.getTracks(),
        repository.getTracks(),
      ]);

      expect(source.fetchCount, 1);
    });

    test('renvoie une liste non modifiable', () async {
      final List<Track> tracks = await repositoryWith(
        FakeCatalogDataSource(tracks: <Track>[buildTrack()]),
      ).getTracks();

      expect(() => tracks.add(buildTrack(id: 'autre')), throwsUnsupportedError);
    });

    test('place les nouveautés distantes en tête et écarte les doublons',
        () async {
      final FakeCatalogDataSource source = FakeCatalogDataSource(
        tracks: <Track>[buildTrack(id: 'embarque', title: 'Embarqué')],
      );

      final List<Track> tracks = await repositoryWith(
        source,
        newTracks: <Track>[
          buildTrack(id: 'nouveaute', title: 'Nouveauté', isNew: true),
          buildTrack(id: 'embarque', title: 'Doublon', isNew: true),
        ],
      ).getTracks();

      expect(tracks, hasLength(2));
      expect(tracks.first.id, 'nouveaute');
      expect(tracks.last.id, 'embarque');
      expect(tracks.last.title, 'Embarqué');
    });

    test('absorbe une source distante injoignable', () async {
      final FakeCatalogDataSource source = FakeCatalogDataSource(
        tracks: <Track>[buildTrack(id: 'a')],
      );

      final List<Track> tracks = await repositoryWith(
        source,
        remoteFailure: const CatalogException('Firestore injoignable'),
      ).getTracks();

      expect(tracks, hasLength(1));
      expect(tracks.first.id, 'a');
    });

    test('marque les pistes déjà téléchargées', () async {
      final FakeCatalogDataSource source = FakeCatalogDataSource(
        tracks: <Track>[buildTrack(id: 'a'), buildTrack(id: 'b')],
      );
      final FakeDownloadRepository downloads = FakeDownloadRepository()
        ..addDownloaded(buildTrack(id: 'a'));

      final List<Track> tracks = await repositoryWith(
        source,
        downloads: downloads,
      ).getTracks();

      expect(
        tracks.firstWhere((Track t) => t.id == 'a').isDownloaded,
        isTrue,
      );
      expect(
        tracks.firstWhere((Track t) => t.id == 'b').isDownloaded,
        isFalse,
      );
    });

    test('propage l\'erreur du catalogue embarqué', () async {
      final TrackRepositoryImpl repository = repositoryWith(
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
      final TrackRepositoryImpl repository = repositoryWith(source);

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

  // Application « 100 % audio » (Jethsonat) : le catalogue embarqué est
  // ignoré, Firestore est la source unique du catalogue.
  group('TrackRepositoryImpl — mode 100 % audio', () {
    test('ignore le catalogue embarqué et ne lit que Firestore', () async {
      final FakeCatalogDataSource source = FakeCatalogDataSource(
        tracks: <Track>[
          buildTrack(id: 'demo-01', title: 'Nuit blanche', artistName: 'NOVAA'),
        ],
      );

      final List<Track> tracks = await repositoryWith(
        source,
        streamOnly: true,
        newTracks: <Track>[
          buildTrack(
            id: 'jethsonat-01',
            title: 'Sec Sec',
            artistName: 'Jethsonat',
            label: 'Tete Roh Studio',
            isNew: true,
          ),
        ],
      ).getTracks();

      // Le morceau d'un autre artiste (issu du catalog.json partagé) ne doit
      // jamais apparaître dans l'application de Jethsonat.
      expect(tracks, hasLength(1));
      expect(tracks.single.id, 'jethsonat-01');
      expect(tracks.single.label, 'Tete Roh Studio');
      expect(source.fetchCount, 0);
    });

    test('remonte l\'erreur distante au lieu d\'afficher un catalogue vide',
        () async {
      final FakeCatalogDataSource source = FakeCatalogDataSource(
        tracks: <Track>[buildTrack(id: 'demo-01')],
      );

      await expectLater(
        repositoryWith(
          source,
          streamOnly: true,
          remoteFailure: const CatalogException('Firestore injoignable'),
        ).getTracks(),
        throwsA(isA<CatalogException>()),
      );
    });

    test('conserve la fusion lorsque le catalogue embarqué est actif',
        () async {
      final FakeCatalogDataSource source = FakeCatalogDataSource(
        tracks: <Track>[buildTrack(id: 'embarque')],
      );

      final List<Track> tracks = await repositoryWith(
        source,
        streamOnly: false,
        newTracks: <Track>[buildTrack(id: 'distant', isNew: true)],
      ).getTracks();

      expect(tracks, hasLength(2));
      expect(tracks.first.id, 'distant');
      expect(source.fetchCount, 1);
    });
  });
}
