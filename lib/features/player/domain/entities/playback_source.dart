/// Source audio prête à être confiée au moteur de lecture.
///
/// Les trois variantes correspondent exactement aux constructeurs `AudioSource`
/// `.asset`, `.file` et `.uri` de `just_audio` : la bibliothèque de lecture reste
/// ainsi connue du seul dossier `player/data/`, et une piste peut indifféremment
/// provenir du bundle, du stockage local ou du réseau.
sealed class PlaybackSource {
  const PlaybackSource();
}

/// Fichier embarqué dans le bundle de l'application.
final class AssetPlaybackSource extends PlaybackSource {
  const AssetPlaybackSource(this.assetPath);

  /// Chemin de l'asset, par exemple `assets/audio/single-001.mp3`.
  final String assetPath;

  @override
  bool operator ==(Object other) =>
      other is AssetPlaybackSource && other.assetPath == assetPath;

  @override
  int get hashCode => Object.hash(AssetPlaybackSource, assetPath);

  @override
  String toString() => 'AssetPlaybackSource($assetPath)';
}

/// Fichier présent dans le stockage privé de l'application.
final class FilePlaybackSource extends PlaybackSource {
  const FilePlaybackSource(this.filePath);

  /// Chemin absolu du fichier local.
  final String filePath;

  @override
  bool operator ==(Object other) =>
      other is FilePlaybackSource && other.filePath == filePath;

  @override
  int get hashCode => Object.hash(FilePlaybackSource, filePath);

  @override
  String toString() => 'FilePlaybackSource($filePath)';
}

/// Ressource distante, utilisée lorsque le catalogue exposera des URLs.
final class NetworkPlaybackSource extends PlaybackSource {
  const NetworkPlaybackSource(this.uri);

  /// URL absolue du morceau.
  final Uri uri;

  @override
  bool operator ==(Object other) =>
      other is NetworkPlaybackSource && other.uri == uri;

  @override
  int get hashCode => Object.hash(NetworkPlaybackSource, uri);

  @override
  String toString() => 'NetworkPlaybackSource($uri)';
}
