import '../../../../core/utils/collections.dart';
import 'loop_mode.dart';
import 'playback_media.dart';

/// Valeur « non fournie » pour les paramètres nullables de `copyWith`.
const Object _unset = Object();

/// État du lecteur exposé à l'interface utilisateur.
///
/// Classe immuable : chaque évolution produit une nouvelle instance et l'égalité
/// est implémentée, ce qui permet à l'interface de ne se reconstruire que
/// lorsque l'état a réellement changé.
class PlaybackState {
  const PlaybackState({
    this.queue = const <PlaybackMedia>[],
    this.currentIndex,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.errorMessage,
    this.loopMode = LoopMode.off,
    this.shuffleEnabled = false,
  });

  /// File de lecture courante.
  ///
  /// La liste est traitée comme immuable : l'appelant fournit un instantané
  /// (`List.unmodifiable`) plutôt qu'une liste qu'il modifiera ensuite, ce qui
  /// préserve l'immutabilité de l'état tout en conservant un constructeur
  /// `const` utilisable comme valeur par défaut.
  final List<PlaybackMedia> queue;

  /// Index de la piste courante dans [queue], `null` si la file est vide.
  final int? currentIndex;

  /// `true` lorsque la lecture est en cours.
  final bool isPlaying;

  /// `true` pendant une mise en mémoire tampon ou un chargement de source.
  final bool isBuffering;

  /// Position de lecture connue.
  final Duration position;

  /// Durée de la piste courante, `Duration.zero` tant qu'elle est inconnue.
  final Duration duration;

  /// Dernier message d'erreur de lecture.
  ///
  /// Les erreurs du moteur audio sont publiées ici plutôt que levées : le flux
  /// d'état ne doit jamais être interrompu par une erreur d'exécution.
  final String? errorMessage;

  /// Mode de lecture en boucle courant.
  final LoopMode loopMode;

  /// `true` lorsque le mode aléatoire est activé.
  final bool shuffleEnabled;

  /// `true` si une piste valide est sélectionnée dans la file.
  bool get hasCurrent {
    final int? index = currentIndex;
    return index != null && index >= 0 && index < queue.length;
  }

  /// Piste courante, ou `null` si la file est vide.
  PlaybackMedia? get currentMedia => hasCurrent ? queue[currentIndex!] : null;

  /// `true` si une piste suit la piste courante.
  bool get hasNext => hasCurrent && currentIndex! < queue.length - 1;

  /// `true` si une piste précède la piste courante.
  bool get hasPrevious => hasCurrent && currentIndex! > 0;

  /// `true` si la dernière lecture a échoué.
  bool get hasError => errorMessage != null;

  /// Progression de la piste courante, bornée entre 0 et 1.
  double get progress {
    final int totalMs = duration.inMilliseconds;
    if (totalMs <= 0) {
      return 0;
    }
    final double ratio = position.inMilliseconds / totalMs;
    return ratio.clamp(0, 1);
  }

  /// Copie l'état en remplaçant les champs fournis.
  ///
  /// `errorMessage` peut être explicitement remis à `null` en passant
  /// `errorMessage: null`, grâce à une valeur sentinelle interne.
  PlaybackState copyWith({
    List<PlaybackMedia>? queue,
    int? currentIndex,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    Object? errorMessage = _unset,
    LoopMode? loopMode,
    bool? shuffleEnabled,
  }) {
    return PlaybackState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      loopMode: loopMode ?? this.loopMode,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PlaybackState &&
        itemsEqual(other.queue, queue) &&
        other.currentIndex == currentIndex &&
        other.isPlaying == isPlaying &&
        other.isBuffering == isBuffering &&
        other.position == position &&
        other.duration == duration &&
        other.errorMessage == errorMessage &&
        other.loopMode == loopMode &&
        other.shuffleEnabled == shuffleEnabled;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(queue),
    currentIndex,
    isPlaying,
    isBuffering,
    position,
    duration,
    errorMessage,
    loopMode,
    shuffleEnabled,
  );

  @override
  String toString() =>
      'PlaybackState(media: ${currentMedia?.trackId}, '
      'index: $currentIndex, playing: $isPlaying, '
      'position: ${position.inSeconds}s/${duration.inSeconds}s, '
      'loop: $loopMode, shuffle: $shuffleEnabled)';
}
