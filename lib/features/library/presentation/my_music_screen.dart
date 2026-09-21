import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/byte_formatter.dart';
import '../../catalog/domain/entities/track.dart';
import '../../player/presentation/playback_controller.dart';
import '../domain/entities/downloaded_track.dart';
import 'downloads_providers.dart';

/// Écran « Ma musique » : morceaux disponibles hors connexion.
///
/// L'écran observe [downloadedTracksProvider] : une matérialisation terminée
/// apparaît sans action manuelle. Chaque ligne permet de lire le morceau ou de
/// supprimer sa copie locale (avec confirmation).
class MyMusicScreen extends ConsumerWidget {
  const MyMusicScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<DownloadedTrack>> downloads = ref.watch(
      downloadedTracksProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.myMusicTitle)),
      body: downloads.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              error is Exception ? error.toString() : 'Index local illisible.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (List<DownloadedTrack> tracks) => tracks.isEmpty
            ? const _EmptyDownloadsView()
            : _DownloadsList(tracks: tracks),
      ),
    );
  }
}

/// Liste des morceaux matérialisés sur l'appareil.
class _DownloadsList extends ConsumerWidget {
  const _DownloadsList({required this.tracks});

  final List<DownloadedTrack> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tracks.length,
      separatorBuilder: (BuildContext context, int index) =>
          const Divider(height: 1, indent: 72),
      itemBuilder: (BuildContext context, int index) {
        final DownloadedTrack downloaded = tracks[index];
        return ListTile(
          leading: const Icon(Icons.music_note),
          title: Text(
            downloaded.track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(_subtitle(downloaded)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.play_circle_outline),
                tooltip: AppStrings.playAction,
                onPressed: () => _play(context, ref, downloaded),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: AppStrings.deleteAction,
                onPressed: () => _confirmDelete(context, ref, downloaded),
              ),
            ],
          ),
        );
      },
    );
  }

  /// « Artiste · taille · date » sur une seule ligne.
  String _subtitle(DownloadedTrack downloaded) {
    final String date = _formatDate(downloaded.downloadedAt);
    return '${downloaded.track.artist} · '
        '${ByteFormatter.format(downloaded.fileSizeBytes)} · $date';
  }

  /// Date au format `jj/mm/aaaa`, sans dépendance `intl`.
  static String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _play(
    BuildContext context,
    WidgetRef ref,
    DownloadedTrack downloaded,
  ) async {
    try {
      await ref
          .read(playbackControllerProvider.notifier)
          .playCatalog(<Track>[downloaded.track]);
    } on Object catch (error) {
      if (context.mounted) {
        showDownloadError(context, error);
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    DownloadedTrack downloaded,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text(AppStrings.deleteConfirmTitle),
        content: const Text(AppStrings.deleteConfirmMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref
          .read(downloadRepositoryProvider)
          .deleteDownload(downloaded.trackId);
    } on Object catch (error) {
      if (context.mounted) {
        showDownloadError(context, error);
      }
    }
  }
}

/// Message d'erreur de l'écran « Ma musique ».
void showDownloadError(BuildContext context, Object error) {
  final String message = error is AppException
      ? error.message
      : 'Une erreur inattendue est survenue.';
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }
}

/// État vide : aucun morceau téléchargé.
class _EmptyDownloadsView extends StatelessWidget {
  const _EmptyDownloadsView();

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
              Icons.folder_off_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.myMusicEmptyMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
