import '../entities/playback_media.dart';
import '../entities/playback_state.dart';
import '../entities/loop_mode.dart';

/// Moteur audio de l'application.
///
/// L'interface utilisateur n'accède jamais directement à la bibliothèque de
/// lecture : elle observe [state] et [stateStream] et pilote la lecture par ces
/// méthodes. Le remplacement du moteur (autre bibliothèque, implémentation
/// factice de test) n'impacte donc aucun écran.
///
/// Les erreurs d'exécution (source illisible, réseau, focus audio) sont publiées
/// dans `PlaybackState.errorMessage` plutôt que levées, afin de ne pas
/// interrompre le flux d'état observé par l'interface.
abstract interface class AudioPlayerService {
  /// Dernier état connu, sans attendre une nouvelle émission du flux.
  PlaybackState get state;

  /// État courant, émis à chaque évolution du lecteur.
  Stream<PlaybackState> get stateStream;

  /// Remplace la file de lecture et sélectionne la piste à lire.
  ///
  /// [initialIndex] doit être un index valide de [queue] ; la lecture ne démarre
  /// pas automatiquement, l'appelant enchaîne sur `play()`.
  Future<void> setQueue(List<PlaybackMedia> queue, {int initialIndex = 0});

  /// Démarre ou reprend la lecture de la piste courante.
  Future<void> play();

  /// Met la lecture en pause sans perdre la position courante.
  Future<void> pause();

  /// Déplace la position de lecture dans la piste courante.
  Future<void> seek(Duration position);

  /// Passe à la piste suivante si elle existe.
  Future<void> skipToNext();

  /// Revient à la piste précédente si elle existe.
  Future<void> skipToPrevious();

  /// Arrête la lecture et remet le moteur à l'état d'attente (position à zéro).
  Future<void> stop();

  /// Modifie le mode de lecture en boucle.
  ///
  /// `LoopMode.off` : lecture normale.
  /// `LoopMode.all` : répéter toute la file.
  /// `LoopMode.one` : répéter la piste en cours.
  Future<void> setLoopMode(LoopMode mode);

  /// Active ou désactive le mode de lecture aléatoire.
  Future<void> setShuffleModeEnabled(bool enabled);

  /// Libère les ressources du moteur ; l'instance ne doit plus être utilisée.
  Future<void> dispose();
}
