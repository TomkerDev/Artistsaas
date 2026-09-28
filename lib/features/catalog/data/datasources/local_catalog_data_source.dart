import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../../app/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/datasources/catalog_data_source.dart';
import '../../domain/entities/track.dart';

/// Lit et décode le catalogue embarqué de l'artiste courant.
///
/// Le catalogue embarqué est **partagé** par toutes les applications : le même
/// `assets/catalog/catalog.json` sert les dix artistes, et chaque build y
/// applique le filtre [AppConfig.artistId] pour n'exposer que ses titres.
///
/// Le chemin comme le `AssetBundle` restent injectables : les tests fournissent
/// un bundle en mémoire au lieu de dépendre du regroupement d'assets produit par
/// la compilation, ce qui rend la lecture testable sans Flutter.
class LocalCatalogDataSource implements CatalogDataSource {
  // Non-`const` : le filtre par artiste dérive de `AppConfig.artistId`, un
  // getter calculé à partir de `--dart-define`, qui n'est pas une constante.
  LocalCatalogDataSource({
    String assetPath = defaultAssetPath,
    String? artistId,
    AssetBundle? bundle,
  })  : _assetPath = assetPath,
        _filterArtistId = artistId ?? AppConfig.artistId,
        _bundle = bundle;

  /// Chemin du catalogue de l'artiste courant.
  static const String defaultAssetPath = AppConfig.catalogAssetPath;

  final String _assetPath;

  /// Artiste auquel le catalogue est restreint ; `null` pour tout afficher.
  final String? _filterArtistId;

  final AssetBundle? _bundle;

  /// `true` si [track] relève de l'artiste filtré.
  ///
  /// Une piste dépourvue de `artistId` n'est attribuée à personne et reste donc
  /// visible : la masquer viderait les catalogues de démonstration antérieurs à
  /// l'introduction du champ. Les artistes réels déclarent toujours le champ.
  bool _belongsToArtist(Track track) {
    final String? filter = _filterArtistId;
    if (filter == null || filter.isEmpty) {
      return true;
    }
    final String? owner = track.artistId;
    return owner == null || owner == filter;
  }

  @override
  Future<List<Track>> fetchTracks() async {
    final String raw = await _readAsset();
    final Object? decoded = _decodeJson(raw);
    if (decoded is! List) {
      throw CatalogException(
        'Catalogue invalide : une liste de pistes était attendue dans '
        '« $_assetPath ».',
      );
    }

    // Le catalogue est partagé : on ne conserve que les pistes de l'artiste
    // courant, pour ne pas proposer les titres d'un autre artiste.
    final List<Track> tracks = <Track>[
      for (final Object? entry in decoded) _parseEntry(entry),
    ];
    return <Track>[
      for (final Track track in tracks)
        if (_belongsToArtist(track)) track,
    ];
  }

  AssetBundle get _effectiveBundle => _bundle ?? rootBundle;

  Future<String> _readAsset() async {
    try {
      return await _effectiveBundle.loadString(_assetPath);
    } on Object catch (error) {
      throw CatalogException(
        'Impossible de lire le catalogue « $_assetPath ».',
        cause: error,
      );
    }
  }

  Object? _decodeJson(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException catch (error) {
      throw CatalogException(
        'Le catalogue « $_assetPath » n\'est pas un JSON valide.',
        cause: error,
      );
    }
  }

  Track _parseEntry(Object? entry) {
    if (entry is! Map<String, dynamic>) {
      throw CatalogException(
        'Entrée de catalogue invalide dans « $_assetPath » : un objet était '
        'attendu.',
      );
    }
    return Track.fromJson(entry);
  }
}
