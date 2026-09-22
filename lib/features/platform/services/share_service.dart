import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_strings.dart';
import '../domain/entities/playback_media.dart';

/// Interface du service de partage, injectable.
///
/// Sépare le domaine de l'implémentation native (`share_plus`) pour permettre
/// le test sans dépendance native.
abstract interface class ShareService {
  /// Partage un message d'invitation pour le [media] donné.
  Future< void> shareTrack(PlaybackMedia media);

  /// Partage un message avec le [title] et [artist] pour une piste via le
  /// mécanisme natif de partage.
  Future<void> shareMessage(String title, String artist);
}

/// Implémentation native via `share_plus`.
final class SharePlusService implements ShareService {
  const SharePlusService();

  @override
  Future<void> shareTrack(PlaybackMedia media) async {
    await shareMessage(media.title, media.artist);
  }

  @override
  Future<void> shareMessage(String title, String artist) async {
    final String message = _buildShareMessage(title, artist);
    await Share.share(message);
  }

  static String _buildShareMessage(String title, String artist) {
    return "Écoute le titre '$title' de $artist sur l'application officielle Novaa !\n\n"
        "Découvrez et écoutez tous les morceaux de l'artiste dans l'app Novaa. ❤️🎵";
  }
}
