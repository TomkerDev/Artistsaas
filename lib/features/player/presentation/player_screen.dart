import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/duration_formatter.dart';
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

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            _CoverArt(artAsset: media.artAsset, title: media.title),
            const SizedBox(height: 24),
            Text(
              media.title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              media.artist,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _SeekBar(state: state),
            const SizedBox(height: 8),
            _TransportControls(state: state),
            if (state.hasError) ...<Widget>[
              const SizedBox(height: 12),
              _PlaybackError(state: state),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pochette du morceau, ou visuel de remplacement.
class _CoverArt extends StatelessWidget {
  const _CoverArt({required this.artAsset, required this.title});

  final String? artAsset;
  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    if (artAsset != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          artAsset!,
          width: 280,
          height: 280,
          fit: BoxFit.cover,
          errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
            return _FallbackCover(colors: colors, title: title);
          },
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
        borderRadius: BorderRadius.circular(16),
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

// MARKER_COVER_METHOD

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

/// Contrôles de transport : précédent, lecture/pause, suivant.
class _TransportControls extends ConsumerWidget {
  const _TransportControls({required this.state});

  final PlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlaybackController controller = ref.read(
      playbackControllerProvider.notifier,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        IconButton(
          iconSize: 40,
          tooltip: AppStrings.previousAction,
          onPressed: state.hasPrevious ? controller.previous : null,
          icon: const Icon(Icons.skip_previous),
        ),
        const SizedBox(width: 12),
        // Bouton principal : buffering -> indicateur d'attente, sinon
        // lecture/pause selon l'état courant.
        _PlayPauseButton(state: state, controller: controller),
        const SizedBox(width: 12),
        IconButton(
          iconSize: 40,
          tooltip: AppStrings.nextAction,
          onPressed: state.hasNext ? controller.next : null,
          icon: const Icon(Icons.skip_next),
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
            Icon(
              Icons.graphic_eq,
              size: 64,
              color: theme.colorScheme.primary,
            ),
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
