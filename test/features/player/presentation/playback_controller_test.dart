import 'package:artistsaas/app/di/app_providers.dart';
import 'package:artistsaas/core/errors/app_exception.dart';
import 'package:artistsaas/features/catalog/domain/entities/track.dart';
import 'package:artistsaas/features/player/domain/entities/playback_state.dart';
import 'package:artistsaas/features/player/presentation/playback_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeAudioPlayerService service;
  late FakePlaybackSourceResolver resolver;
  late ProviderContainer container;

  ProviderContainer buildContainer() {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        audioPlayerServiceProvider.overrideWithValue(service),
        playbackSourceResolverProvider.overrideWithValue(resolver),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    service = FakeAudioPlayerService();
    resolver = FakePlaybackSourceResolver();
    container = buildContainer();
  });

  group('PlaybackController', () {
    test('prépare la file, sélectionne le morceau et lance la lecture',
        () async {
      final PlaybackController controller = container.read(
        playbackControllerProvider.notifier,
      );

      await controller.playCatalog(
        <Track>[buildTrack(id: 'a'), buildTrack(id: 'b')],
        initialIndex: 1,
      );
      await pumpEventQueue();

      expect(resolver.resolveCount, 2);
      expect(service.setQueueCount, 1);
      expect(service.lastInitialIndex, 1);
      expect(service.playCount, 1);
      final PlaybackState state = container.read(playbackControllerProvider);
      expect(state.currentMedia?.trackId, 'b');
      expect(state.isPlaying, isTrue);
    });

    test('togglePlayPause alterne entre lecture et pause', () async {
      final PlaybackController controller = container.read(
        playbackControllerProvider.notifier,
      );

      await controller.playCatalog(<Track>[buildTrack(id: 'a')]);
      await pumpEventQueue();

      await controller.togglePlayPause();
      await pumpEventQueue();
      expect(service.pauseCount, 1);

      await controller.togglePlayPause();
      await pumpEventQueue();
      expect(service.playCount, 2);
    });

    test('next et previous naviguent dans la file', () async {
      final PlaybackController controller = container.read(
        playbackControllerProvider.notifier,
      );

      await controller.playCatalog(
        <Track>[buildTrack(id: 'a'), buildTrack(id: 'b')],
      );
      await pumpEventQueue();

      await controller.next();
      await pumpEventQueue();
      expect(
        container.read(playbackControllerProvider).currentMedia?.trackId,
        'b',
      );

      await controller.previous();
      await pumpEventQueue();
      expect(
        container.read(playbackControllerProvider).currentMedia?.trackId,
        'a',
      );
    });

    test('un échec de préparation publie une erreur puis est acquitté',
        () async {
      service.setQueueFailure = const PlaybackException('Source illisible');
      final PlaybackController controller = container.read(
        playbackControllerProvider.notifier,
      );

      await expectLater(
        controller.playCatalog(<Track>[buildTrack(id: 'a')]),
        throwsA(isA<PlaybackException>()),
      );
      await pumpEventQueue();

      final PlaybackState state = container.read(playbackControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.errorMessage, contains('Source illisible'));

      controller.dismissError();
      expect(
        container.read(playbackControllerProvider).hasError,
        isFalse,
      );
    });

    test('playAt rejoue la file à un autre index', () async {
      final PlaybackController controller = container.read(
        playbackControllerProvider.notifier,
      );

      await controller.playCatalog(
        <Track>[buildTrack(id: 'a'), buildTrack(id: 'b')],
      );
      await pumpEventQueue();

      await controller.playAt(1);
      await pumpEventQueue();

      expect(service.setQueueCount, 2);
      expect(service.lastInitialIndex, 1);
    });
  });
}
