import 'package:flutter/material.dart';

import '../../../../core/utils/duration_formatter.dart';
import '../../domain/entities/track.dart';

/// Ligne du catalogue : pochette, titre, artiste/album et durée.
///
/// Widget purement présentationnel : il reçoit sa piste et n'accède ni au
/// catalogue ni au moteur audio. La commande de lecture, puis l'indicateur de
/// téléchargement, lui seront ajoutés aux étapes 3 et 4.
class TrackListTile extends StatelessWidget {
  const TrackListTile({required this.track, super.key});

  /// Piste affichée.
  final Track track;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListTile(
      leading: _CoverPlaceholder(title: track.title),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(_subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        DurationFormatter.format(track.duration),
        style: theme.textTheme.labelMedium,
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

/// Visuel de remplacement utilisé tant qu'aucune pochette n'est fournie.
///
/// L'identité visuelle de l'artiste n'étant pas encore disponible, la pochette
/// est un dégradé portant l'initiale du titre : l'interface reste lisible sans
/// inventer de contenu graphique.
class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.title});

  final String title;

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
      child: Text(
        title.isEmpty ? '?' : title.substring(0, 1).toUpperCase(),
        style: theme.textTheme.titleMedium?.copyWith(
          color: colors.onPrimaryContainer,
        ),
      ),
    );
  }
}
