import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../favorites/domain/services/favorites_service.dart';
import '../../favorites/presentation/favorites_provider.dart';
import '../domain/entities/loop_mode.dart';
import '../domain/entities/playback_media.dart';
import '../domain/entities/playback_state.dart';
import 'playback_controller.dart';

/// Écran du lecteur : pochette, progression, contrôles et file de lecture.
///
/// L'écran observe exclusivement [PlaybackController] : il ne connaît ni le
/// moteur audio, ni les sources, ni le catalogue. Toutes les commandes passent
/// par le contrôleur.
class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlaybackState state = ref.watch(playbackControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.playerTitle)),
      body: state.hasCurrent
          ? _NowPlaying(state: state)
          : const _PlayerEmptyView(),
    );
  }
}

/// Morceau en cours : pochette, titre, progression et contrôles.
class _NowPlaying extends ConsumerWidget {
  const _NowPlaying({required this.state});

  final PlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final PlaybackMedia media = state.currentMedia!;
    final bool isFavorite = ref
        .watch(favoriteIdsProvider)
        .contains(media.trackId);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            _CoverArt(
              artAsset: media.artAsset,
              coverUrl: media.coverUrl,
              title: media.title,
            ),
            const SizedBox(height: 24),
            // Titre + bouton Favori sur la même ligne.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Text(
                    media.title,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 8),
                _FavoriteButton(
                  isFavorite: isFavorite,
                  onToggle: () => _toggleFavorite(ref, media.trackId),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Nom réel de l'artiste (track.artistName → media.artist).
            Text(
              media.artist,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _SeekBar(state: state),
            const SizedBox(height: 16),
            // Toutes les commandes sur une seule ligne, bien centrée.
            _PlaybackControls(state: state),
            const SizedBox(height: 24),
            // Bouton de partage sous le bloc de lecture.
            IconButton(
              iconSize: 28,
              tooltip: 'Partager la musique de ${media.artist}',
              onPressed: () => _shareTrack(context, media),
              icon: const Icon(Icons.share_outlined, color: Colors.white),
            ),
            if (state.hasError) ...<Widget>[
              const SizedBox(height: 12),
              _PlaybackError(state: state),
            ],
          ],
        ),
      ),
    );
  }

  void _toggleFavorite(WidgetRef ref, String trackId) {
    final FavoritesService service = ref.read(favoritesServiceProvider);
    final bool currentlyFavorite = ref
        .read(favoriteIdsProvider)
        .contains(trackId);
    if (currentlyFavorite) {
      service.removeFavorite(trackId);
    } else {
      service.addFavorite(trackId);
    }
  }

  void _shareTrack(BuildContext context, PlaybackMedia media) {
    final String text =
        'Découvre l\'application officielle de ${media.artist} sur '
        '${AppStrings.appTitle} ! Écoute tous ses titres en exclusivité : '
        'https://novaa-music-tchaddd.web.app';
    Share.share(
      text,
      subject: 'Écouter ${media.artist} sur ${AppStrings.appTitle}',
    );
  }
}

/// Bouton de favori du lecteur : cœur vide ou rempli.
class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.isFavorite, required this.onToggle});

  final bool isFavorite;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
      onPressed: onToggle,
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: isFavorite ? colors.error : colors.onSurfaceVariant,
      ),
    );
  }
}

/// Toutes les commandes de lecture sur une seule ligne :
/// Shuffle, Précédent, Lecture/Pause, Suivant, Répéter.
class _PlaybackControls extends ConsumerWidget {
  const _PlaybackControls({required this.state});

  final PlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlaybackController controller = ref.read(
      playbackControllerProvider.notifier,
    );
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        // Shuffle
        IconButton(
          iconSize: 28,
          tooltip: 'Lecture aléatoire',
          onPressed: () =>
              controller.setShuffleModeEnabled(!state.shuffleEnabled),
          icon: Icon(
            Icons.shuffle,
            color: state.shuffleEnabled ? colors.primary : Colors.white,
          ),
        ),
        const SizedBox(width: 16),
        // Skip Previous
        IconButton(
          iconSize: 40,
          tooltip: AppStrings.previousAction,
          onPressed: state.hasPrevious ? controller.previous : null,
          icon: const Icon(Icons.skip_previous, color: Colors.white),
        ),
        const SizedBox(width: 16),
        // Play/Pause (grand format)
        _PlayPauseButton(state: state, controller: controller),
        const SizedBox(width: 16),
        // Skip Next
        IconButton(
          iconSize: 40,
          tooltip: AppStrings.nextAction,
          onPressed: state.hasNext ? controller.next : null,
          icon: const Icon(Icons.skip_next, color: Colors.white),
        ),
        const SizedBox(width: 16),
        // Repeat
        IconButton(
          iconSize: 28,
          tooltip: 'Mode de lecture en boucle',
          onPressed: () =>
              controller.setLoopMode(_nextLoopMode(state.loopMode)),
          icon: Icon(
            switch (state.loopMode) {
              LoopMode.off => Icons.repeat,
              LoopMode.all => Icons.repeat,
              LoopMode.one => Icons.repeat_one,
            },
            color: state.loopMode == LoopMode.off
                ? Colors.white
                : colors.primary,
          ),
        ),
      ],
    );
  }

  /// Cycle du mode de boucle : off → toute la file → piste courante → off.
  static LoopMode _nextLoopMode(LoopMode mode) => switch (mode) {
    LoopMode.off => LoopMode.all,
    LoopMode.all => LoopMode.one,
    LoopMode.one => LoopMode.off,
  };
}

/// Pochette du morceau, ou visuel de remplacement.
class _CoverArt extends StatelessWidget {
  const _CoverArt({this.artAsset, this.coverUrl, required this.title});

  final String? artAsset;
  final String? coverUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    final bool isUrlValid = coverUrl != null && coverUrl!.startsWith('http');

    if (isUrlValid) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(
            coverUrl!,
            width: 280,
            height: 280,
            fit: BoxFit.cover,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stack) {
                  return _FallbackCover(colors: colors, title: title);
                },
          ),
        ),
      );
    }
    if (artAsset != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            artAsset!,
            width: 280,
            height: 280,
            fit: BoxFit.cover,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stack) {
                  return _FallbackCover(colors: colors, title: title);
                },
          ),
        ),
      );
    }
    return _FallbackCover(colors: colors, title: title);
  }
}

/// Visuel de remplacement : dégradé portant l'initiale du titre.
class _FallbackCover extends StatelessWidget {
  const _FallbackCover({required this.colors, required this.title});

  final ColorScheme colors;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[colors.primaryContainer, colors.primary],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.album, size: 96, color: colors.onPrimaryContainer),
    );
  }
}

/// Barre de progression : position courante, curseur et durée totale.
class _SeekBar extends ConsumerWidget {
  const _SeekBar({required this.state});

  final PlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return Column(
      children: <Widget>[
        Slider(
          value: state.progress,
          onChanged: (double value) {
            final int totalMs = state.duration.inMilliseconds;
            ref
                .read(playbackControllerProvider.notifier)
                .seek(Duration(milliseconds: (value * totalMs).round()));
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                DurationFormatter.format(state.position),
                style: theme.textTheme.labelMedium,
              ),
              Text(
                DurationFormatter.format(state.duration),
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bouton lecture/pause, avec indicateur de mise en mémoire tampon.
class _PlayPauseButton extends ConsumerWidget {
  const _PlayPauseButton({required this.state, required this.controller});

  final PlaybackState state;
  final PlaybackController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isBuffering) {
      return const SizedBox(
        width: 72,
        height: 72,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }
    return IconButton.filled(
      iconSize: 48,
      tooltip: state.isPlaying ? AppStrings.pauseAction : AppStrings.playAction,
      onPressed: controller.togglePlayPause,
      icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
    );
  }
}

/// Message d'erreur de lecture, avec bouton d'acquittement.
class _PlaybackError extends ConsumerWidget {
  const _PlaybackError({required this.state});

  final PlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              state.errorMessage ?? AppStrings.playerErrorTitle,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            color: theme.colorScheme.onErrorContainer,
            tooltip: AppStrings.cancelAction,
            onPressed: () =>
                ref.read(playbackControllerProvider.notifier).dismissError(),
          ),
        ],
      ),
    );
  }
}

/// État vide : aucun morceau sélectionné dans la file.
class _PlayerEmptyView extends StatelessWidget {
  const _PlayerEmptyView();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.graphic_eq, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              AppStrings.playerEmptyMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
