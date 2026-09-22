import 'package:flutter/material.dart';

import '../../../../core/utils/duration_formatter.dart';
import '../../../library/domain/entities/download_progress.dart';
import '../../domain/entities/track.dart';

/// Ligne du catalogue : pochette, titre, artiste/album, durée et actions.
///
/// Widget purement présentationnel : il reçoit sa piste et les callbacks
/// (`onPlay`, `onDownload`) sans accéder ni au catalogue ni au moteur audio ni
/// au stockage. L'indicateur de téléchargement reflète le [DownloadProgress]
/// fourni par l'écran parent.
class TrackListTile extends StatelessWidget {
  const TrackListTile({
    required this.track,
    this.onPlay,
    this.onDownload,
    this.downloadProgress,
    this.isPlaying = false,
    super.key,
  });

  /// Piste affichée.
  final Track track;

  /// Lecture de la piste ; `null` rend la ligne non cliquable.
  final VoidCallback? onPlay;

  /// Téléchargement de la piste ; `null` masque l'action.
  final VoidCallback? onDownload;

  /// État de matérialisation locale, `null` si jamais demandée.
  final DownloadProgress? downloadProgress;

  /// `true` lorsque la piste est celle en cours de lecture.
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListTile(
      onTap: onPlay,
      leading: track.coverAsset == null
          ? _CoverPlaceholder(title: track.title, isPlaying: isPlaying)
          : _CoverImage(
              asset: track.coverAsset!,
              isPlaying: isPlaying,
              fallbackTitle: track.title,
            ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isPlaying
            ? theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              )
            : null,
      ),
      subtitle: Text(_subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: _TrailingAction(
        track: track,
        onDownload: onDownload,
        progress: downloadProgress,
        durationLabel: DurationFormatter.format(track.duration),
      ),
    );
  }

  /// « Artiste · Album » lorsque l'album est connu, « Artiste » sinon.
  String get _subtitle {
    final String? album = track.album;
    if (album == null || album.isEmpty) {
      return track.artist;
    }
    return '${track.artist} · $album';
  }
}

/// Zone de droite de la ligne : progression, état ou durée.
class _TrailingAction extends StatelessWidget {
  const _TrailingAction({
    required this.track,
    required this.durationLabel,
    this.onDownload,
    this.progress,
  });

  final Track track;
  final String durationLabel;
  final VoidCallback? onDownload;
  final DownloadProgress? progress;

  @override
  Widget build(BuildContext context) {
    final DownloadProgress? progress = this.progress;
    if (progress != null && progress.isRunning) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          value: progress.fraction,
          strokeWidth: 2.5,
        ),
      );
    }
    if (progress != null && progress.hasFailed) {
      return Tooltip(
        message: progress.errorMessage ?? 'Échec du téléchargement',
        child: Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
        ),
      );
    }
    if (progress != null && progress.isCompleted) {
      return const Tooltip(
        message: 'Disponible hors connexion',
        child: Icon(Icons.download_done_outlined),
      );
    }
    if (onDownload != null && track.isDownloadable) {
      return IconButton(
        icon: const Icon(Icons.download_outlined),
        tooltip: 'Télécharger',
        onPressed: onDownload,
      );
    }
    return Text(durationLabel);
  }
}

/// Pochette embarquée de la piste, avec repli sur le visuel de marque.
class _CoverImage extends StatelessWidget {
  const _CoverImage({
    required this.asset,
    required this.isPlaying,
    required this.fallbackTitle,
  });

  final String asset;
  final bool isPlaying;
  final String fallbackTitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: isPlaying
          ? Container(
              width: 48,
              height: 48,
              color: colors.primaryContainer,
              alignment: Alignment.center,
              child: Icon(Icons.equalizer, color: colors.onPrimaryContainer),
            )
          : Image.asset(
              asset,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stack) =>
                      _CoverPlaceholder(title: fallbackTitle, isPlaying: false),
            ),
    );
  }
}

/// Visuel de remplacement utilisé tant qu'aucune pochette n'est fournie.
///
/// L'identité visuelle de l'artiste n'étant pas encore disponible, la pochette
/// est un dégradé portant l'initiale du titre : l'interface reste lisible sans
/// inventer de contenu graphique.
class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.title, this.isPlaying = false});

  final String title;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[colors.primaryContainer, colors.primary],
        ),
      ),
      alignment: Alignment.center,
      child: isPlaying
          ? Icon(Icons.equalizer, color: colors.onPrimaryContainer)
          : Text(
              title.isEmpty ? '?' : title.substring(0, 1).toUpperCase(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
    );
  }
}
