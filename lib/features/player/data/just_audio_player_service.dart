import 'dart:async';

import 'package:just_audio/just_audio.dart' as ja;
import 'package:just_audio_background/just_audio_background.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/entities/loop_mode.dart';
import '../domain/entities/playback_media.dart';
import '../domain/entities/playback_source.dart';
import '../domain/entities/playback_state.dart';
import '../domain/services/audio_player_service.dart';

/// Moteur audio concret fondé sur `just_audio`.
///
/// C'est le **seul** endroit de l'application qui connaît la bibliothèque de
/// lecture : les entités de domaine (`PlaybackSource`) sont traduites ici en
/// `AudioSource`, et les flux natifs (`playerStateStream`, `positionStream`,
/// `durationStream`, `currentIndexStream`) sont agrégés en un unique
/// `PlaybackState` publié sur [stateStream].
///
/// Les erreurs d'exécution (asset illisible, fichier absent, focus audio) ne
/// sont jamais levées vers l'interface : elles sont publiées dans
/// `PlaybackState.errorMessage`, conformément au contrat du domaine.
///
/// Lecture en arrière-plan : chaque source est étiquetée avec une `MediaItem`
/// (`just_audio_background`) qui alimente la notification média système et les
/// contrôles casque / écran verrouillé. Le plugin exige un tag sur **toutes**
/// les sources de la file, sans quoi la lecture lève une erreur sur mobile.
class JustAudioPlayerService implements AudioPlayerService {
  final ja.AudioPlayer _player = ja.AudioPlayer();

  final StreamController<PlaybackState> _states =
      StreamController<PlaybackState>.broadcast();

  PlaybackState _state = const PlaybackState();

  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  bool _disposed = false;

  JustAudioPlayerService() {
    _subscriptions.addAll(<StreamSubscription<Object?>>[
      _player.playerStateStream.listen((ja.PlayerState playerState) {
        _publish(
          _state.copyWith(
            isPlaying: playerState.playing,
            isBuffering:
                playerState.processingState == ja.ProcessingState.loading ||
                playerState.processingState == ja.ProcessingState.buffering,
          ),
        );
      }),
      _player.positionStream.listen(
        (Duration position) => _publish(_state.copyWith(position: position)),
      ),
      _player.durationStream.listen(
        (Duration? duration) => duration == null
            ? null
            : _publish(_state.copyWith(duration: duration)),
      ),
      _player.currentIndexStream.listen(
        (int? index) => index == null
            ? null
            : _publish(_state.copyWith(currentIndex: index)),
      ),
    ]);
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
    if (queue.isEmpty) {
      throw const PlaybackException('File de lecture vide.');
    }
    if (initialIndex < 0 || initialIndex >= queue.length) {
      throw PlaybackException(
        'Index de lecture invalide : $initialIndex '
        '(file de ${queue.length} pistes).',
      );
    }

    final List<ja.AudioSource> sources = <ja.AudioSource>[
      for (final PlaybackMedia media in queue) _audioSourceOf(media),
    ];

    try {
      _publish(
        _state.copyWith(
          queue: List<PlaybackMedia>.unmodifiable(queue),
          currentIndex: initialIndex,
          position: Duration.zero,
          duration: Duration.zero,
          errorMessage: null,
        ),
      );
      final Duration? duration = await _player.setAudioSources(
        sources,
        initialIndex: initialIndex,
      );
      if (duration != null) {
        _publish(_state.copyWith(duration: duration));
      }
    } on Object catch (error) {
      _publish(
        _state.copyWith(
          errorMessage: 'Impossible de préparer la lecture : $error',
        ),
      );
      throw PlaybackException(
        'Impossible de préparer la lecture de la file.',
        cause: error,
      );
    }
  }

  @override
  Future<void> play() async {
    try {
      await _player.play();
    } on Object catch (error) {
      _publish(_state.copyWith(errorMessage: 'La lecture a échoué : $error'));
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } on Object catch (error) {
      _publish(_state.copyWith(errorMessage: 'La pause a échoué : $error'));
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } on Object catch (error) {
      _publish(
        _state.copyWith(errorMessage: 'Le déplacement a échoué : $error'),
      );
    }
  }

  @override
  Future<void> skipToNext() async {
    if (!_state.hasNext) {
      return;
    }
    try {
      await _player.seekToNext();
    } on Object catch (error) {
      _publish(
        _state.copyWith(errorMessage: 'Le morceau suivant a échoué : $error'),
      );
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (!_state.hasPrevious) {
      return;
    }
    try {
      await _player.seekToPrevious();
    } on Object catch (error) {
      _publish(
        _state.copyWith(errorMessage: 'Le morceau précédent a échoué : $error'),
      );
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      // La position repart à zéro et la lecture est suspendue : publié
      // explicitement car `stop()` ne déclenche pas toujours de flux position.
      _publish(
        _state.copyWith(
          isPlaying: false,
          isBuffering: false,
          position: Duration.zero,
        ),
      );
    } on Object catch (error) {
      _publish(_state.copyWith(errorMessage: "L'arrêt a échoué : $error"));
    }
  }

  @override
  Future<void> setLoopMode(LoopMode mode) async {
    try {
      await _player.setLoopMode(
        switch (mode) {
          LoopMode.off => ja.LoopMode.off,
          LoopMode.all => ja.LoopMode.all,
          LoopMode.one => ja.LoopMode.one,
        },
      );
    } on Object catch (error) {
      _publish(_state.copyWith(errorMessage: 'Mode de boucle impossible : $error'));
    }
  }

  @override
  Future<void> setShuffleModeEnabled(bool enabled) async {
    try {
      await _player.setShuffleModeEnabled(enabled);
    } on Object catch (error) {
      _publish(
        _state.copyWith(errorMessage: 'Mode aléatoire impossible : $error'),
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _states.close();
    await _player.dispose();
  }

  /// Traduit une source de domaine en source `just_audio` étiquetée.
  ///
  /// Le tag `MediaItem` est la seule exigence de `just_audio_background` :
  /// sans lui, la lecture échoue sur Android/iOS. La pochette n'est pas
  /// transmise à la notification pour le MVP (les pochettes du catalogue sont
  /// des assets Flutter, sans URI accessible au service natif) ; l'ajout se
  /// fera via `artUri` lorsque des pochettes fichier/distantes seront fournies.
  ja.AudioSource _audioSourceOf(PlaybackMedia media) {
    final MediaItem tag = MediaItem(
      id: media.trackId,
      title: media.title,
      artist: media.artist,
      album: 'Novaa',
    );
    return switch (media.source) {
      AssetPlaybackSource(:final String assetPath) => ja.AudioSource.asset(
        assetPath,
        tag: tag,
      ),
      FilePlaybackSource(:final String filePath) => ja.AudioSource.file(
        filePath,
        tag: tag,
      ),
      NetworkPlaybackSource(:final Uri uri) => ja.AudioSource.uri(uri, tag: tag),
    };
  }

  void _publish(PlaybackState state) {
    if (_disposed || _states.isClosed) {
      return;
    }
    if (_state == state) {
      return;
    }
    _state = state;
    _states.add(state);
  }
}
