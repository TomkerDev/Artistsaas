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

  /// `true` dès qu'une file a été chargée avec succès dans le moteur.
  ///
  /// Sert à distinguer l'état `idle` initial (aucune file : rien à faire) de
  /// l'état `idle` publié après un arrêt demandé hors de l'application (bouton
  /// « stop » de la notification système).
  bool _hasActiveQueue = false;

  /// `true` pendant le chargement d'une file : le moteur peut transiter par
  /// `idle` entre deux files, ce qui n'est pas un arrêt.
  bool _settingQueue = false;

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
      // Un retour à l'état `idle` APRÈS chargement d'une file signifie un
      // arrêt demandé hors de l'application : bouton « stop » de la
      // notification système, casque ou écran de verrouillage. La file
      // publiée est alors vidée pour que le mini-lecteur et l'écran du
      // lecteur se ferment, comme pour un arrêt local. L'`idle` initial et
      // les transitoires de chargement sont ignorés.
      _player.processingStateStream.listen(
        (ja.ProcessingState processingState) {
          if (processingState != ja.ProcessingState.idle ||
              !_hasActiveQueue ||
              _settingQueue) {
            return;
          }
          _hasActiveQueue = false;
          _publish(const PlaybackState());
        },
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
      _settingQueue = true;
      final Duration? duration = await _player.setAudioSources(
        sources,
        initialIndex: initialIndex,
      );
      // La file est chargée : à partir de cet instant, un état `idle` du
      // moteur signifiera un arrêt (notification, casque), pas une
      // initialisation.
      _hasActiveQueue = true;
      // Boucle et aléa sont relus au moteur : `just_audio` les conserve d'une
      // file à l'autre, et l'état publié doit suivre ce que le moteur
      // applique réellement.
      _publish(
        _state.copyWith(
          duration: duration,
          loopMode: _domainLoopMode(_player.loopMode),
          shuffleEnabled: _player.shuffleModeEnabled,
        ),
      );
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
    } finally {
      _settingQueue = false;
    }
  }

  @override
  Future<void> play() async {
    // `just_audio` : le futur de `play()` ne se termine qu'à la pause, à
    // l'arrêt ou à la fin du morceau — et jamais si la session audio refuse
    // l'activation. L'attendre laisserait chaque appel de lecture suspendu
    // indéfiniment (`playCatalog`, lecture/pause) : la lecture est donc
    // lancée sans attendre sa fin, et un échec éventuel est publié dans
    // l'état, conformément au contrat du domaine.
    unawaited(
      _player.play().catchError((Object error) {
        _publish(
          _state.copyWith(errorMessage: 'La lecture a échoué : $error'),
        );
      }),
    );
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
    // L'arrêt est explicite : l'événement `idle` du moteur qui va suivre n'a
    // plus à être traité comme un arrêt distant.
    _hasActiveQueue = false;
    try {
      await _player.stop();
      // `stop()` interrompt le média et vide le tampon de lecture. La position
      // repart à zéro et la lecture est suspendue : publié explicitement car
      // `stop()` ne déclenche pas toujours de flux position.
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
      await _player.setLoopMode(switch (mode) {
        LoopMode.off => ja.LoopMode.off,
        LoopMode.all => ja.LoopMode.all,
        LoopMode.one => ja.LoopMode.one,
      });
      // Publié à chaque émission suivante du moteur : le contrôleur remplace
      // intégralement son état à la réception, sans quoi l'icône de boucle
      // repasserait en « off » au prochain tick de position.
      _publish(_state.copyWith(loopMode: mode));
    } on Object catch (error) {
      _publish(
        _state.copyWith(errorMessage: 'Mode de boucle impossible : $error'),
      );
    }
  }

  @override
  Future<void> setShuffleModeEnabled(bool enabled) async {
    try {
      await _player.setShuffleModeEnabled(enabled);
      // Même raison que [setLoopMode] : le mode aléatoire doit figurer dans
      // TOUTES les émissions du moteur, sinon l'icône de l'écran Lecteur
      // clignote puis revient en « off » au tick suivant.
      _publish(_state.copyWith(shuffleEnabled: enabled));
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

  /// Traduit un mode de boucle du moteur vers le domaine.
  LoopMode _domainLoopMode(ja.LoopMode mode) => switch (mode) {
        ja.LoopMode.off => LoopMode.off,
        ja.LoopMode.all => LoopMode.all,
        ja.LoopMode.one => LoopMode.one,
      };

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
      NetworkPlaybackSource(:final Uri uri) => ja.AudioSource.uri(
        uri,
        tag: tag,
      ),
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
