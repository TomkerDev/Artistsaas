import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../../app/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/datasources/catalog_data_source.dart';
import '../../domain/entities/track.dart';

/// Lit et décode le catalogue embarqué de l'artiste courant.
///
/// Le chemin du fichier est dérivé de [AppConfig] : chaque build distribue le
/// `catalog.json` de son artiste (`assets/artists/<dossier>/catalog.json`), la
/// même base de code servant les dix applications.
///
/// Le chemin comme le `AssetBundle` restent injectables : les tests fournissent
/// un bundle en mémoire au lieu de dépendre du regroupement d'assets produit par
/// la compilation, ce qui rend la lecture testable sans Flutter.
class LocalCatalogDataSource implements CatalogDataSource {
  const LocalCatalogDataSource({
    String assetPath = defaultAssetPath,
    AssetBundle? bundle,
  }) : _assetPath = assetPath,
       _bundle = bundle;

  /// Chemin du catalogue de l'artiste courant.
  static const String defaultAssetPath = AppConfig.catalogAssetPath;

  final String _assetPath;
  final AssetBundle? _bundle;

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

    return <Track>[for (final Object? entry in decoded) _parseEntry(entry)];
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
