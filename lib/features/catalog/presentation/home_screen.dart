import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/errors/app_exception.dart';
import '../../library/domain/entities/download_progress.dart';
import '../../library/presentation/downloads_providers.dart';
import '../../player/domain/entities/playback_state.dart';
import '../../player/presentation/playback_controller.dart';
import '../domain/entities/track.dart';
import 'catalog_controller.dart';
import 'widgets/track_list_tile.dart';

/// Écran d'accueil : catalogue musical de l'artiste.
///
/// L'écran ignore totalement d'où viennent les données : il observe le
/// `CatalogController` et rend l'un des quatre états possibles — chargement,
/// erreur avec possibilité de réessayer, catalogue vide, ou liste des morceaux.
///
/// Actions par morceau :
/// - un tap lance la lecture du catalogue à partir de cette piste ;
/// - l'icône de téléchargement matérialise le morceau dans le stockage local.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Track>> catalog = ref.watch(
      catalogControllerProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.homeTitle)),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => _CatalogErrorView(
          error: error,
          onRetry: () => ref.read(catalogControllerProvider.notifier).reload(),
        ),
        data: (List<Track> tracks) => tracks.isEmpty
            ? const _EmptyCatalogView()
            : _TrackList(tracks: tracks),
      ),
    );
  }
}

/// Liste des pistes du catalogue, avec actions de lecture et de téléchargement.
class _TrackList extends ConsumerWidget {
  const _TrackList({required this.tracks});

  final List<Track> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, DownloadProgress> progress = ref.watch(
      downloadProgressProvider,
    ).value ?? const <String, DownloadProgress>{};
    final String? currentTrackId = ref.watch(
      playbackControllerProvider.select(
        (PlaybackState state) => state.currentMedia?.trackId,
      ),
    );

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tracks.length,
      separatorBuilder: (BuildContext context, int index) =>
          const Divider(height: 1, indent: 72),
      itemBuilder: (BuildContext context, int index) {
        final Track track = tracks[index];
        return TrackListTile(
          track: track,
          isPlaying: track.id == currentTrackId,
          downloadProgress: progress[track.id],
          onPlay: () => _play(ref, index),
          onDownload: () => _download(context, ref, track),
        );
      },
    );
  }

  Future<void> _play(WidgetRef ref, int index) async {
    try {
      await ref
          .read(playbackControllerProvider.notifier)
          .playCatalog(tracks, initialIndex: index);
    } on Object {
      // L'erreur est déjà publiée dans l'état de lecture et affichée par le
      // lecteur ; rien d'autre à faire ici.
    }
  }

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    Track track,
  ) async {
    try {
      await ref.read(downloadRepositoryProvider).download(track);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.downloadCompletedMessage),
          duration: Duration(seconds: 2),
        ),
      );
    } on Object catch (error) {
      if (context.mounted) {
        showErrorSnackBar(context, error);
      }
    }
  }
}

/// Message d'erreur uniforme pour les actions utilisateur.
///
/// Le message métier est privilégié lorsqu'il existe (`AppException`) ; le
/// message technique reste destiné aux journaux.
void showErrorSnackBar(BuildContext context, Object error) {
  final String message = error is AppException
      ? error.message
      : 'Une erreur inattendue est survenue.';
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }
}

/// Message affiché lorsque le catalogue ne contient aucune piste.
class _EmptyCatalogView extends StatelessWidget {
  const _EmptyCatalogView();

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
              Icons.album_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.homeEmptyMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

/// Erreur de chargement : message lisible et bouton de réessai.
class _CatalogErrorView extends StatelessWidget {
  const _CatalogErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Le message technique reste dans les logs ; l'utilisateur voit le message
    // métier lorsqu'il existe, un texte générique sinon.
    final Object raised = error;
    final String message = raised is AppException
        ? raised.message
        : AppStrings.homeErrorGeneric;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(AppStrings.homeErrorTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text(AppStrings.retryAction),
            ),
          ],
        ),
      ),
    );
  }
}
