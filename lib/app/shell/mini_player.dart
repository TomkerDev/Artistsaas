import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/utils/duration_formatter.dart';
import '../../features/player/domain/entities/playback_state.dart';
import '../../features/player/presentation/playback_controller.dart';
import 'home_shell.dart' show selectedTabNotifier;

/// Mini-lecteur persistant, affiché entre le contenu et la barre d'onglets.
///
/// Il n'apparaît que lorsqu'un morceau est sélectionné dans la file. Un tap
/// ouvre le lecteur complet ; il offre lecture/pause et morceau suivant sans
/// changer d'onglet.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlaybackState state = ref.watch(playbackControllerProvider);
    if (!state.hasCurrent) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final PlaybackController controller = ref.read(
      playbackControllerProvider.notifier,
    );

    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            LinearProgressIndicator(
              value: state.progress,
              minHeight: 3,
              backgroundColor: Colors.transparent,
            ),
            ListTile(
              dense: true,
              onTap: () => _openPlayer(context),
              leading: Icon(
                state.isPlaying ? Icons.equalizer : Icons.music_note,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                state.currentMedia!.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              subtitle: Text(
                '${state.currentMedia!.artist} · '
                '${DurationFormatter.format(state.position)} / '
                '${DurationFormatter.format(state.duration)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _MiniPlayPause(state: state, controller: controller),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    tooltip: AppStrings.nextAction,
                    onPressed: state.hasNext ? controller.next : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: AppStrings.cancelAction,
                    onPressed: () =>
                        ref.read(playbackControllerProvider.notifier).stop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ouvre l'onglet Lecteur via le sélecteur d'onglet partagé.
  void _openPlayer(BuildContext context) {
    selectedTabNotifier.value = 1;
  }
}

/// Bouton lecture/pause compact du mini-lecteur.
class _MiniPlayPause extends StatelessWidget {
  const _MiniPlayPause({required this.state, required this.controller});

  final PlaybackState state;
  final PlaybackController controller;

  @override
  Widget build(BuildContext context) {
    if (state.isBuffering) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: Padding(
          padding: EdgeInsets.all(2),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
      tooltip: state.isPlaying ? AppStrings.pauseAction : AppStrings.playAction,
      onPressed: controller.togglePlayPause,
    );
  }
}
