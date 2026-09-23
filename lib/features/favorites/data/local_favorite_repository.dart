import 'package:sqflite/sqflite.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/entities/favorite.dart';
import '../domain/repositories/favorite_repository.dart';

/// Persistance des favoris dans une base `sqflite`.
///
/// La table `favorites` est créée si elle n'existe pas. L'ouverture de la base
/// est paresseuse pour permettre l'injection d'une base factice en test.
class LocalFavoriteRepository implements FavoriteRepository {
  LocalFavoriteRepository({Future<Database> Function()? openDatabase})
      : _openDatabase = openDatabase ?? _openDefaultDatabase;

  final Future<Database> Function() _openDatabase;
  Database? _database;

  static Future<Database> _openDefaultDatabase() async {
    final String databasesPath = await getDatabasesPath();
    return openDatabase(
      '$databasesPath/artistsaas.db',
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute(
          'CREATE TABLE IF NOT EXISTS favorites ('
          'track_id TEXT PRIMARY KEY, '
          'added_at TEXT NOT NULL)',
        );
      },
    );
  }

  Future<Database> _openDatabaseOnce() async {
    return _database ??= await _openDatabase();
  }

  @override
  Future<List<Favorite>> getFavorites() async {
    try {
      final Database db = await _openDatabaseOnce();
      final List<Map<String, Object?>> rows = await db.query(
        'favorites',
        orderBy: 'added_at ASC',
      );
      return rows
          .map((Map<String, Object?> row) => Favorite(
                trackId: row['track_id'] as String,
                addedAt: DateTime.parse(row['added_at'] as String),
              ))
          .toList();
    } on Object catch (error) {
      throw FavoriteException(
        'Impossible de lire les favoris.',
        cause: error,
      );
    }
  }

  @override
  Future<void> addFavorite(String trackId) async {
    try {
      final Database db = await _openDatabaseOnce();
      await db.insert(
        'favorites',
        <String, Object>{
          'track_id': trackId,
          'added_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } on Object catch (error) {
      throw FavoriteException(
        'Impossible d\'ajouter le favori.',
        cause: error,
      );
    }
  }

  @override
  Future<void> removeFavorite(String trackId) async {
    try {
      final Database db = await _openDatabaseOnce();
      await db.delete(
        'favorites',
        where: 'track_id = ?',
        whereArgs: <String>[trackId],
      );
    } on Object catch (error) {
      throw FavoriteException(
        'Impossible de retirer le favori.',
        cause: error,
      );
    }
  }

  @override
  Future<bool> isFavorite(String trackId) async {
    try {
      final Database db = await _openDatabaseOnce();
      final List<Map<String, Object?>> rows = await db.query(
        'favorites',
        where: 'track_id = ?',
        whereArgs: <String>[trackId],
      );
      return rows.isNotEmpty;
    } on Object catch (error) {
      throw FavoriteException(
        'Impossible de vérifier le favori.',
        cause: error,
      );
    }
  }

  /// Réinitialise la base (supprime tous les favoris).
  /// Utilisé pour les tests afin d'isoler chaque scénario.
  Future<void> reset() async {
    try {
      final Database db = await _openDatabaseOnce();
      await db.delete('favorites');
    } on Object {
      // En test, on accepte l'échec silencieux si la base n'existe pas.
    }
  }

  /// Ferme la base si elle est ouverte.
  Future<void> dispose() async {
    await _database?.close();
    _database = null;
  }
}

