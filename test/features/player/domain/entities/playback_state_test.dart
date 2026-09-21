import 'package:artistsaas/features/player/domain/entities/playback_media.dart';
import 'package:artistsaas/features/player/domain/entities/playback_source.dart';
import 'package:artistsaas/features/player/domain/entities/playback_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const PlaybackMedia first = PlaybackMedia(
    trackId: 'a',
    title: 'Titre A',
    artist: 'Artiste',
    source: AssetPlaybackSource('assets/audio/a.mp3'),
  );
  const PlaybackMedia second = PlaybackMedia(
    trackId: 'b',
    title: 'Titre B',
    artist: 'Artiste',
    source: AssetPlaybackSource('assets/audio/b.mp3'),
  );
  const PlaybackMedia third = PlaybackMedia(
    trackId: 'c',
    title: 'Titre C',
    artist: 'Artiste',
    source: FilePlaybackSource('/data/downloads/c.mp3'),
  );
  const List<PlaybackMedia> queue = <PlaybackMedia>[first, second, third];

  group('PlaybackState', () {
    test('un état initial ne contient ni piste ni erreur', () {
      const PlaybackState state = PlaybackState();

      expect(state.hasCurrent, isFalse);
      expect(state.currentMedia, isNull);
      expect(state.hasNext, isFalse);
      expect(state.hasPrevious, isFalse);
      expect(state.hasError, isFalse);
      expect(state.progress, 0);
    });

    test('expose la piste courante et la navigation possible', () {
      const PlaybackState state = PlaybackState(queue: queue, currentIndex: 1);

      expect(state.currentMedia, second);
      expect(state.hasNext, isTrue);
      expect(state.hasPrevious, isTrue);
      expect(state.queue.length, 3);
    });

    test('ne considère pas comme courante une piste hors de la file', () {
      const PlaybackState tropGrand = PlaybackState(
        queue: queue,
        currentIndex: 5,
      );
      const PlaybackState negatif = PlaybackState(
        queue: queue,
        currentIndex: -1,
      );

      expect(tropGrand.hasCurrent, isFalse);
      expect(tropGrand.currentMedia, isNull);
      expect(tropGrand.hasNext, isFalse);
      expect(negatif.hasCurrent, isFalse);
    });

    test('la dernière piste de la file n\'a pas de suivante', () {
      const PlaybackState state = PlaybackState(queue: queue, currentIndex: 2);

      expect(state.hasNext, isFalse);
      expect(state.hasPrevious, isTrue);
    });

    test('calcule une progression bornée entre 0 et 1', () {
      const PlaybackState moitie = PlaybackState(
        position: Duration(seconds: 30),
        duration: Duration(seconds: 60),
      );
      const PlaybackState auDela = PlaybackState(
        position: Duration(seconds: 90),
        duration: Duration(seconds: 60),
      );
      const PlaybackState sansDuree = PlaybackState(
        position: Duration(seconds: 30),
      );

      expect(moitie.progress, 0.5);
      expect(auDela.progress, 1);
      expect(sansDuree.progress, 0);
    });

    test('copyWith ne remplace que les champs fournis', () {
      const PlaybackState state = PlaybackState(queue: queue, currentIndex: 0);

      final PlaybackState updated = state.copyWith(
        isPlaying: true,
        position: const Duration(seconds: 12),
      );

      expect(updated.isPlaying, isTrue);
      expect(updated.position, const Duration(seconds: 12));
      expect(updated.queue, queue);
      expect(updated.currentIndex, 0);
      expect(updated.isBuffering, isFalse);
    });

    test('copyWith permet d\'effacer le message d\'erreur', () {
      const PlaybackState enEchec = PlaybackState(
        errorMessage: 'Source illisible',
      );

      expect(enEchec.hasError, isTrue);
      expect(enEchec.copyWith(errorMessage: null).hasError, isFalse);
      expect(
        enEchec.copyWith(isPlaying: true).errorMessage,
        'Source illisible',
      );
    });

    test('l\'égalité et le hash reflètent tous les champs', () {
      const PlaybackState reference = PlaybackState(
        queue: queue,
        currentIndex: 1,
        isPlaying: true,
        position: Duration(seconds: 5),
        duration: Duration(seconds: 60),
      );
      const PlaybackState identique = PlaybackState(
        queue: queue,
        currentIndex: 1,
        isPlaying: true,
        position: Duration(seconds: 5),
        duration: Duration(seconds: 60),
      );

      expect(reference, identique);
      expect(reference.hashCode, identique.hashCode);
      expect(
        reference == reference.copyWith(position: const Duration(seconds: 6)),
        isFalse,
      );
      expect(reference == reference.copyWith(isPlaying: false), isFalse);
      expect(reference == const PlaybackState(), isFalse);
    });
  });
}
