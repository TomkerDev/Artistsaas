import 'package:artistsaas/app/di/app_providers.dart';
import 'package:artistsaas/core/errors/app_exception.dart';
import 'package:artistsaas/features/catalog/domain/entities/track.dart';
import 'package:artistsaas/features/catalog/presentation/catalog_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

void main() {
  ProviderContainer containerWith(FakeMusicRepository repository) {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        musicRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('CatalogController', () {
    test('expose le catalogue du dépôt', () async {
      final ProviderContainer container = containerWith(
        FakeMusicRepository(
          tracks: <Track>[
            buildTrack(id: 'a'),
            buildTrack(id: 'b'),
          ],
        ),
      );

      final List<Track> tracks = await container.read(
        catalogControllerProvider.future,
      );

      expect(tracks, hasLength(2));
      expect(
        container.read(catalogControllerProvider),
        isA<AsyncData<List<Track>>>(),
      );
    });

    test('expose l\'erreur du dépôt dans son état', () async {
      final ProviderContainer container = containerWith(
        FakeMusicRepository(
          failure: const CatalogException('Catalogue illisible'),
        ),
      );

      await expectLater(
        container.read(catalogControllerProvider.future),
        throwsA(isA<CatalogException>()),
      );
      expect(
        container.read(catalogControllerProvider),
        isA<AsyncError<List<Track>>>(),
      );
    });

    test('reload relit le dépôt après un échec', () async {
      final FakeMusicRepository repository = FakeMusicRepository(
        failure: const CatalogException('Catalogue illisible'),
      );
      final ProviderContainer container = containerWith(repository);

      await expectLater(
        container.read(catalogControllerProvider.future),
        throwsA(isA<CatalogException>()),
      );

      repository
        ..failure = null
        ..tracks = <Track>[buildTrack()];

      await container.read(catalogControllerProvider.notifier).reload();

      expect(container.read(catalogControllerProvider).value, hasLength(1));
      expect(repository.callCount, 2);
    });
  });
}
