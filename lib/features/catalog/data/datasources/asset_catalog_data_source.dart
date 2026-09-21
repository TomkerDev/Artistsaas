import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/datasources/catalog_data_source.dart';
import '../../domain/entities/track.dart';

/// Lit le catalogue embarqué dans les assets de l'application.
///
/// Le `AssetBundle` est injectable : les tests fournissent un bundle en mémoire
/// au lieu de dépendre du regroupement d'assets produit par la compilation, ce
/// qui rend la lecture du catalogue testable sans Flutter.
class AssetCatalogDataSource implements CatalogDataSource {
  const AssetCatalogDataSource({
    String assetPath = defaultAssetPath,
    AssetBundle? bundle,
  }) : _assetPath = assetPath,
       _bundle = bundle;

  /// Emplacement du catalogue embarqué.
  static const String defaultAssetPath = 'assets/catalog/catalog.json';

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
