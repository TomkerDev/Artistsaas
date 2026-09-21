import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../domain/entities/download_progress.dart';
import '../domain/entities/downloaded_track.dart';

/// Morceaux disponibles hors connexion, réémis à chaque ajout ou suppression.
final StreamProvider<List<DownloadedTrack>> downloadedTracksProvider =
    StreamProvider<List<DownloadedTrack>>(
      (Ref ref) => ref.watch(downloadRepositoryProvider).watchDownloadedTracks(),
    );

/// État de matérialisation par identifiant de piste, progression incluse.
final StreamProvider<Map<String, DownloadProgress>> downloadProgressProvider =
    StreamProvider<Map<String, DownloadProgress>>(
      (Ref ref) => ref.watch(downloadRepositoryProvider).watchProgress(),
    );
