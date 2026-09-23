import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../catalog/domain/entities/track.dart';
import '../domain/entities/loop_mode.dart';
import '../domain/entities/playback_media.dart';
import '../domain/entities/playback_state.dart';
import '../domain/services/audio_player_service.dart';
import '../domain/services/playback_source_resolver.dart';

class PlaybackController extends Notifier<PlaybackState> {
  StreamSubscription<PlaybackState>? _subscription;

  bool _disposed = false;

  @override
  PlaybackState build() {
    ref.onDispose(() async {
      _disposed = true;
      await _subscription?.cancel();
      _subscription = null;
    });
    return const PlaybackState();
  }

  /// Établit la file à partir des pistes du catalogue et lance la lecture.
  ///
  /// Chaque piste est résolue (copie locale, source distante ou asset). Une
  /// piste non résoluble interrompt la préparation : l'erreur est publiée dans
  /// l'état puis relancée pour un éventuel message à l'utilisateur.
  Future<void> playCatalog(List<Track> tracks, {int initialIndex = 0}) async {
    if (tracks.isEmpty) {
      return;
    }
    final PlaybackSourceResolver resolver = ref.read(
      playbackSourceResolverProvider,
    );
    final List<PlaybackMedia> queue = <PlaybackMedia>[];
    try {
      for (final Track track in tracks) {
        queue.add(await resolver.resolve(track));
      }
    } on Object catch (error) {
      state = state.copyWith(errorMessage: 'Piste non lisible : $error');
      rethrow;
    }
    await _start(queue, initialIndex);
  }

  /// Relance la lecture de la file à l'index [index].
  Future<void> playAt(int index) => _start(state.queue, index);

  /// Démarre ou reprend la lecture, selon l'état courant.
  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await ref.read(audioPlayerServiceProvider).pause();
    } else {
      await ref.read(audioPlayerServiceProvider).play();
    }
  }

  /// Déplace la position de lecture dans le morceau courant.
  Future<void> seek(Duration position) =>
      ref.read(audioPlayerServiceProvider).seek(position);

  /// Passe au morceau suivant de la file.
  Future<void> next() => ref.read(audioPlayerServiceProvider).skipToNext();

  /// Revient au morceau précédent de la file.
  Future<void> previous() =>
      ref.read(audioPlayerServiceProvider).skipToPrevious();

  /// Active ou désactive le mode de lecture aléatoire.
  Future<void> setShuffleModeEnabled(bool enabled) async {
    await ref.read(audioPlayerServiceProvider)
        .setShuffleModeEnabled(enabled);
    state = state.copyWith(shuffleEnabled: enabled);
  }

  /// Modifie le mode de lecture en boucle.
  Future<void> setLoopMode(LoopMode mode) async {
    await ref.read(audioPlayerServiceProvider).setLoopMode(mode);
    state = state.copyWith(loopMode: mode);
  }

  /// Avance de 5 secondes dans la piste courante.
  Future<void> seekForward() async {
    final Duration newPosition =
        state.position + const Duration(seconds: 5);
    await seek(newPosition);
  }

  /// Recule de 5 secondes dans la piste courante.
  Future<void> seekBackward() async {
    final Duration newPosition =
        state.position - const Duration(seconds: 5);
    await seek(newPosition);
  }

  /// Acquitte l'erreur affichée pour reprendre une interface propre.
  void dismissError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Arrête la lecture et réinitialise l'état publié (file vide, mini-lecteur
  /// masqué). Le moteur reste réutilisable pour une prochaine lecture.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await ref.read(audioPlayerServiceProvider).stop();
    } on Object catch (error) {
      state = state.copyWith(
          errorMessage: "L'arrêt a échoué : $error");
      rethrow;
    }
    state = const PlaybackState();
  }

  Future<void> _start(
    List<PlaybackMedia> queue,
    int initialIndex,
  ) async {
    final AudioPlayerService service =
        ref.read(audioPlayerServiceProvider);
    try {
      await service.setQueue(queue, initialIndex: initialIndex);
    } on Object catch (error) {
      state = state.copyWith(
        errorMessage: 'Préparation de la lecture impossible : $error',
      );
      rethrow;
    }
    _listen(service);
    await service.play();
  }

  void _listen(AudioPlayerService service) {
    _subscription?.cancel();
    _subscription = service.stateStream.listen((PlaybackState playbackState) {
      if (!_disposed) {
        state = playbackState;
      }
    });
  }
}

/// État de lecture observé par le lecteur, le mini-lecteur et le catalogue.
final NotifierProvider<PlaybackController, PlaybackState>
playbackControllerProvider =
    NotifierProvider<PlaybackController, PlaybackState>(PlaybackController.new);

