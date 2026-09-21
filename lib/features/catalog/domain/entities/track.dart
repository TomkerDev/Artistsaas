import '../../../../core/errors/app_exception.dart';

/// Piste du catalogue de l'artiste.
///
/// Entité de domaine : elle ne connaît ni Flutter, ni le stockage, ni le moteur
/// audio. La sérialisation JSON est portée par cette classe (aucun DTO
/// intermédiaire) tant que le format de l'API distante correspondra exactement
/// au format du catalogue embarqué ; un DTO sera introduit dans `data/` le jour
/// où les deux formats divergeront.
///
/// Clés JSON attendues, identiques au futur catalogue distant :
/// `id`, `title`, `artist`, `duration_ms`, `audio_asset` (obligatoires) ;
/// `album`, `track_number`, `release_year`, `cover_asset`, `audio_url`,
/// `is_downloadable` (facultatives, `is_downloadable` valant `true` par défaut).
/// `audio_url` restera absente pendant toute la phase « contenu embarqué ».
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.audioAsset,
    this.album,
    this.trackNumber,
    this.releaseYear,
    this.coverAsset,
    this.audioUrl,
    this.isDownloadable = true,
  });

  /// Construit une piste à partir d'une entrée du catalogue JSON.
  ///
  /// Lève une `CatalogException` si un champ obligatoire est absent, vide ou
  /// d'un type inattendu : mieux vaut échouer explicitement que produire une
  /// piste silencieusement incomplète.
  factory Track.fromJson(Map<String, dynamic> json) {
    final String id = _requireText(json, 'id');
    final int durationMs = _requireInt(json, 'duration_ms');
    if (durationMs <= 0) {
      throw CatalogException(
        'Durée invalide pour la piste « $id » : duration_ms = $durationMs.',
      );
    }

    return Track(
      id: id,
      title: _requireText(json, 'title'),
      artist: _requireText(json, 'artist'),
      duration: Duration(milliseconds: durationMs),
      audioAsset: _requireText(json, 'audio_asset'),
      album: _optionalText(json, 'album'),
      trackNumber: _optionalInt(json, 'track_number'),
      releaseYear: _optionalInt(json, 'release_year'),
      coverAsset: _optionalText(json, 'cover_asset'),
      audioUrl: _optionalUri(json, 'audio_url'),
      isDownloadable: _optionalBool(json, 'is_downloadable') ?? true,
    );
  }

  /// Identifiant stable de la piste, utilisé comme clé du stockage local.
  final String id;

  /// Titre du morceau.
  final String title;

  /// Nom de scène de l'artiste.
  final String artist;

  /// Durée totale du morceau.
  final Duration duration;

  /// Chemin de l'audio embarqué dans le bundle de l'application.
  final String audioAsset;

  /// Album ou projet de rattachement.
  final String? album;

  /// Position du morceau dans son album.
  final int? trackNumber;

  /// Année de publication.
  final int? releaseYear;

  /// Pochette embarquée ; `null` déclenche un visuel de remplacement.
  final String? coverAsset;

  /// Source distante, absente de la version embarquée du MVP.
  final Uri? audioUrl;

  /// Indique si l'application autorise la matérialisation locale du morceau.
  final bool isDownloadable;

  /// `true` si le catalogue fournit une source distante pour cette piste.
  bool get hasRemoteSource => audioUrl != null;

  /// Sérialise la piste au format du catalogue.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'artist': artist,
    'duration_ms': duration.inMilliseconds,
    'audio_asset': audioAsset,
    if (album != null) 'album': album,
    if (trackNumber != null) 'track_number': trackNumber,
    if (releaseYear != null) 'release_year': releaseYear,
    if (coverAsset != null) 'cover_asset': coverAsset,
    if (audioUrl != null) 'audio_url': audioUrl.toString(),
    'is_downloadable': isDownloadable,
  };

  @override
  bool operator ==(Object other) {
    return other is Track &&
        other.id == id &&
        other.title == title &&
        other.artist == artist &&
        other.duration == duration &&
        other.audioAsset == audioAsset &&
        other.album == album &&
        other.trackNumber == trackNumber &&
        other.releaseYear == releaseYear &&
        other.coverAsset == coverAsset &&
        other.audioUrl == audioUrl &&
        other.isDownloadable == isDownloadable;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    artist,
    duration,
    audioAsset,
    album,
    trackNumber,
    releaseYear,
    coverAsset,
    audioUrl,
    isDownloadable,
  );

  @override
  String toString() => 'Track($id, « $title » par $artist)';

  static String _requireText(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw CatalogException(
        'Champ obligatoire « $key » absent ou invalide dans le catalogue.',
      );
    }
    return value.trim();
  }

  static String? _optionalText(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw CatalogException('Champ « $key » : un texte était attendu.');
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int _requireInt(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value is! num) {
      throw CatalogException(
        'Champ obligatoire « $key » absent ou non numérique dans le catalogue.',
      );
    }
    return value.toInt();
  }

  static int? _optionalInt(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! num) {
      throw CatalogException('Champ « $key » : un nombre était attendu.');
    }
    return value.toInt();
  }

  static bool? _optionalBool(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! bool) {
      throw CatalogException('Champ « $key » : un booléen était attendu.');
    }
    return value;
  }

  static Uri? _optionalUri(Map<String, dynamic> json, String key) {
    final String? raw = _optionalText(json, key);
    if (raw == null) {
      return null;
    }
    final Uri? uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      throw CatalogException(
        'Champ « $key » : « $raw » n\'est pas une URL absolue valide.',
      );
    }
    return uri;
  }
}
