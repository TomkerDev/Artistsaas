import '../../../core/errors/app_exception.dart';
import '../../catalog/domain/entities/track.dart';
import '../../library/domain/repositories/download_repository.dart';
import '../domain/entities/playback_media.dart';
import '../domain/entities/playback_source.dart';
import '../domain/services/playback_source_resolver.dart';

/// Résolution concrète des sources de lecture.
///
/// Applique la règle de priorité définie par le domaine :
/// 1. la copie locale, si le morceau a été téléchargé ;
/// 2. la source distante du catalogue, si elle existe ;
/// 3. l'audio embarqué dans le bundle de l'application.
///
/// Le moteur audio ne voit jamais cette logique : il ne reçoit qu'une
/// `PlaybackSource` déjà résolue.
class DefaultPlaybackSourceResolver implements PlaybackSourceResolver {
  DefaultPlaybackSourceResolver(this._downloads);

  final DownloadRepository _downloads;

  @override
  Future<PlaybackMedia> resolve(Track track) async {
    final String? localPath = await _downloads.getLocalPath(track.id);
    if (localPath != null) {
      return _media(track, FilePlaybackSource(localPath));
    }
    final Uri? remoteUrl = track.audioUrl;
    if (remoteUrl != null) {
      return _media(track, NetworkPlaybackSource(remoteUrl));
    }
    if (track.audioAssetPath.isEmpty) {
      throw PlaybackException(
        'Aucune source audio disponible pour « ${track.title} ».',
      );
    }
    return _media(track, AssetPlaybackSource(track.audioAssetPath));
  }

  PlaybackMedia _media(Track track, PlaybackSource source) {
    return PlaybackMedia(
      trackId: track.id,
      title: track.title,
      artist: track.artistName,
      source: source,
      artAsset: track.coverAsset,
      coverUrl: track.coverUrl,
    );
  }
}
