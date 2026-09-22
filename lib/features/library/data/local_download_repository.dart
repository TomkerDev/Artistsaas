import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/errors/app_exception.dart';
import '../../catalog/domain/entities/track.dart';
import '../domain/entities/download_progress.dart';
import '../domain/entities/downloaded_track.dart';
import '../domain/repositories/download_repository.dart';

/// MatÃ©rialisation locale des morceaux : copie des assets dans le stockage
/// privÃ© de l'application et indexation dans une base `sqflite`.
///
/// - Les fichiers sont Ã©crits dans `<documents>/downloads/<id>.<ext>` ;
/// - La base ne conserve que l'index (piste sÃ©rialisÃ©e, chemin, taille, date) :
///   le fichier reste la source de vÃ©ritÃ© ;
/// - Les deux flux ([watchDownloadedTracks], [watchProgress]) sont des
///   `broadcast` : plusieurs Ã©crans peuvent les observer simultanÃ©ment ;
/// - L'ouverture de la base est paresseuse et injectable, ce qui permet de
///   tester le comportement sans `sqflite`.
class LocalDownloadRepository implements DownloadRepository {
  LocalDownloadRepository({Future<Database> Function()? openDatabase})
    : _openDatabase = openDatabase ?? _openDefaultDatabase;

  /// Ouvre (une seule fois) la base locale.
  final Future<Database> Function() _openDatabase;

  Database? _database;

  /// RÃ©pertoire des copies locales, rÃ©solu une seule fois.
  Directory? _downloadsDirectory;

  final StreamController<List<DownloadedTrack>> _tracksController =
      StreamController<List<DownloadedTrack>>.broadcast();

  final StreamController<Map<String, DownloadProgress>> _progressController =
      StreamController<Map<String, DownloadProgress>>.broadcast();

  /// Ã‰tats transitoires (en cours / Ã©chec) et Ã©tat `completed` par piste.
  final Map<String, DownloadProgress> _progress =
      <String, DownloadProgress>{};

  /// Identifiants en cours de matÃ©rialisation, pour Ã©viter les doublons.
  final Set<String> _running = <String>{};

  /// Ouvre la base par dÃ©faut dans le rÃ©pertoire standard `sqflite`.
  static Future<Database> _openDefaultDatabase() async {
    final String databasesPath = await getDatabasesPath();
    return openDatabase(
      '$databasesPath/artistsaas.db',
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute(
          'CREATE TABLE downloaded_tracks ('
          'id TEXT PRIMARY KEY, '
          'track_json TEXT NOT NULL, '
          'local_path TEXT NOT NULL, '
          'file_size INTEGER NOT NULL, '
          'downloaded_at INTEGER NOT NULL)',
        );
      },
    );
  }

  /// Base ouverte (et mÃ©morisÃ©e) Ã  la premiÃ¨re utilisation.
  Future<Database> _openDatabaseOnce() async {
    return _database ??= await _openDatabase();
  }

  /// RÃ©pertoire des copies locales, rÃ©solu et mÃ©morisÃ© une seule fois.
  Future<Directory> _resolveDirectoryOnce() async {
    return _downloadsDirectory ??= await _resolveDirectory();
  }

  static Future<Directory> _resolveDirectory() async {
    final Directory documents = await getApplicationDocumentsDirectory();
    final Directory downloads = Directory('${documents.path}/downloads');
    if (!await downloads.exists()) {
      await downloads.create(recursive: true);
    }
    return downloads;
  }

  @override
  Stream<List<DownloadedTrack>> watchDownloadedTracks() {
    _refreshTracks();
    return _tracksController.stream;
  }

  @override
  Stream<Map<String, DownloadProgress>> watchProgress() {
    _notifyProgress();
    return _progressController.stream;
  }

  @override
  Future<void> download(Track track) async {
    if (!track.isDownloadable) {
      throw DownloadException(
        'Le morceau Â« ${track.title} Â» n\'est pas tÃ©lÃ©chargeable.',
      );
    }
    if (_running.contains(track.id)) {
      return;
    }
    _running.add(track.id);
    _progress[track.id] = DownloadProgress(
      trackId: track.id,
      state: DownloadState.queued,
    );
    _notifyProgress();

    try {
      final Directory directory = await _resolveDirectoryOnce();
      final String extension = _extensionOf(track.audioAssetPath);
      final File target = File('${directory.path}/${track.id}.$extension');

      final ByteData data = await rootBundle.load(track.audioAssetPath);
      final int totalBytes = data.lengthInBytes;
      final Uint8List bytes = data.buffer.asUint8List();

      _progress[track.id] = DownloadProgress(
        trackId: track.id,
        state: DownloadState.downloading,
        receivedBytes: 0,
        totalBytes: totalBytes,
      );
      _notifyProgress();

      // La copie est dÃ©coupÃ©e pour publier une progression rÃ©elle Ã 
      // l'interface et laisser respirer la boucle d'Ã©vÃ©nements.
      final RandomAccessFile handle = await target.open(mode: FileMode.write);
      try {
        const int chunkSize = 64 * 1024;
        for (int offset = 0; offset < bytes.length; offset += chunkSize) {
          final int end =
              offset + chunkSize < bytes.length
                  ? offset + chunkSize
                  : bytes.length;
          await handle.writeFrom(bytes, offset, end);
          _progress[track.id] = DownloadProgress(
            trackId: track.id,
            state: DownloadState.downloading,
            receivedBytes: end,
            totalBytes: totalBytes,
          );
          _notifyProgress();
          await Future<void>.delayed(Duration.zero);
        }
      } finally {
        await handle.close();
      }

      final Database database = await _openDatabaseOnce();
      await database.insert(
        'downloaded_tracks',
        <String, Object?>{
          'id': track.id,
          'track_json': jsonEncode(track.toJson()),
          'local_path': target.path,
          'file_size': totalBytes,
          'downloaded_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _progress[track.id] = DownloadProgress(
        trackId: track.id,
        state: DownloadState.completed,
        receivedBytes: totalBytes,
        totalBytes: totalBytes,
      );
      await _refreshTracks();
    } on DownloadException {
      _markFailed(track.id, 'La copie locale a Ã©chouÃ©.');
      rethrow;
    } on Object catch (error) {
      _markFailed(track.id, 'La copie locale a Ã©chouÃ© : $error');
      throw DownloadException(
        'Impossible de matÃ©rialiser Â« ${track.title} Â».',
        cause: error,
      );
    } finally {
      _running.remove(track.id);
    }
  }

  @override
  Future<void> deleteDownload(String trackId) async {
    try {
      final Database database = await _openDatabaseOnce();
      final List<Map<String, Object?>> rows = await database.query(
        'downloaded_tracks',
        where: 'id = ?',
        whereArgs: <Object?>[trackId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final String? localPath = rows.first['local_path'] as String?;
        if (localPath != null) {
          final File file = File(localPath);
          if (await file.exists()) {
            await file.delete();
          }
        }
        await database.delete(
          'downloaded_tracks',
          where: 'id = ?',
          whereArgs: <Object?>[trackId],
        );
      }
      _progress.remove(trackId);
      await _refreshTracks();
    } on Object catch (error) {
      throw DownloadException(
        'La suppression de Â« $trackId Â» a Ã©chouÃ©.',
        cause: error,
      );
    }
  }

  @override
  Future<Set<String>> getDownloadedTrackIds() async {
    try {
      final Database database = await _openDatabaseOnce();
      final List<Map<String, Object?>> rows = await database.query(
        'downloaded_tracks',
        columns: <String>['id'],
      );
      return <String>{
        for (final Map<String, Object?> row in rows)
          if (row['id'] case final String id) id,
      };
    } on Object catch (error) {
      throw DownloadException(
        'La lecture de l\'index local a échoué.',
        cause: error,
      );
    }
  }

  @override
  Future<String?> getLocalPath(String trackId) async {
    try {
      final Database database = await _openDatabaseOnce();
      final List<Map<String, Object?>> rows = await database.query(
        'downloaded_tracks',
        columns: <String>['local_path'],
        where: 'id = ?',
        whereArgs: <Object?>[trackId],
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      final String? path = rows.first['local_path'] as String?;
      if (path == null) {
        return null;
      }
      // Un fichier supprimÃ© hors de l'application n'est plus une source
      // valide : l'index est alors nettoyÃ© implicitement.
      if (!await File(path).exists()) {
        await deleteDownload(trackId);
        return null;
      }
      return path;
    } on Object catch (error) {
      throw DownloadException(
        'La lecture de l\'index local a Ã©chouÃ©.',
        cause: error,
      );
    }
  }

  /// LibÃ¨re les ressources : contrÃ´leurs fermÃ©s, base fermÃ©e.
  Future<void> dispose() async {
    await _tracksController.close();
    await _progressController.close();
    await _database?.close();
    _database = null;
  }

  void _markFailed(String trackId, String message) {
    _progress[trackId] = DownloadProgress(
      trackId: trackId,
      state: DownloadState.failed,
      errorMessage: message,
    );
    _notifyProgress();
  }

  /// Relit l'index et republie la liste des morceaux disponibles.
  Future<void> _refreshTracks() async {
    final List<DownloadedTrack> tracks = <DownloadedTrack>[];
    try {
      final Database database = await _openDatabaseOnce();
      final List<Map<String, Object?>> rows = await database.query(
        'downloaded_tracks',
        orderBy: 'downloaded_at DESC',
      );
      for (final Map<String, Object?> row in rows) {
        final Object? rawTrack = row['track_json'];
        final Object? rawSize = row['file_size'];
        final Object? rawDate = row['downloaded_at'];
        final Object? rawPath = row['local_path'];
        if (rawTrack is! String ||
            rawSize is! int ||
            rawDate is! int ||
            rawPath is! String) {
          continue;
        }
        tracks.add(
          DownloadedTrack(
            track: Track.fromJson(
              jsonDecode(rawTrack) as Map<String, dynamic>,
            ),
            localPath: rawPath,
            fileSizeBytes: rawSize,
            downloadedAt: DateTime.fromMillisecondsSinceEpoch(rawDate),
          ),
        );
      }
    } on Object catch (error) {
      throw DownloadException(
        'La lecture de l\'index local a Ã©chouÃ©.',
        cause: error,
      );
    }
    if (!_tracksController.isClosed) {
      _tracksController.add(List<DownloadedTrack>.unmodifiable(tracks));
    }
    // Les morceaux terminÃ©s alimentent aussi la carte de progression.
    for (final DownloadedTrack track in tracks) {
      if (_progress[track.trackId]?.state != DownloadState.completed) {
        _progress[track.trackId] = DownloadProgress(
          trackId: track.trackId,
          state: DownloadState.completed,
          receivedBytes: track.fileSizeBytes,
          totalBytes: track.fileSizeBytes,
        );
      }
    }
    _notifyProgress();
  }

  void _notifyProgress() {
    if (_progressController.isClosed) {
      return;
    }
    _progressController.add(
      Map<String, DownloadProgress>.unmodifiable(_progress),
    );
  }

  /// Extension du fichier embarquÃ©, sans le prÃ©fixe d'asset.
  static String _extensionOf(String audioAsset) {
    final String fileName = audioAsset.split('/').last;
    final int dot = fileName.lastIndexOf('.');
    return dot < 0 ? 'audio' : fileName.substring(dot + 1);
  }
}
