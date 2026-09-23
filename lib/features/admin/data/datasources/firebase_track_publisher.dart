import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../../core/errors/app_exception.dart';
import '../../domain/services/track_publisher.dart';

/// Publication d'une nouveauté dans Firebase : MP3 + pochette dans Cloud
/// Storage, méta-données dans Firestore.
///
/// Déroulé d'une publication :
/// 1. le MP3 est téléversé dans `artists/<artistId>/audio/<trackId>.mp3`, sa
///    progression occupe l'essentiel du flux (0 → 90) ;
/// 2. la pochette, si fournie, rejoint
///    `artists/<artistId>/covers/<trackId>.<ext>` (90 → 95) ;
/// 3. les URLs de téléchargement (jeton durable) sont résolues (→ 97) ;
/// 4. le document Firestore est créé dans la collection `tracks` avec
///    `is_new: true` et `artistId: <artistId>` (→ 100).
///
/// Si une étape échoue avant l'écriture Firestore, le document n'est jamais
/// créé : l'audio orphelin éventuel est remplacé lors de la prochaine
/// tentative, puisque le chemin de destination ne dépend que de `trackId`.
///
/// Les instances [FirebaseStorage] et [FirebaseFirestore] sont injectables :
/// les tests fournissent des doubles, la production utilise les singletons
/// après l'initialisation de Firebase dans `main()`.
class FirebaseTrackPublisher implements TrackPublisher {
  FirebaseTrackPublisher({FirebaseStorage? storage, FirebaseFirestore? firestore})
    : _storage = storage,
      _firestore = firestore;

  /// Collection Firestore dans laquelle l'application lit les nouveautés.
  /// Doit rester alignée avec `FirebaseCatalogDataSource.collection`.
  static const String tracksCollection = 'tracks';

  final FirebaseStorage? _storage;
  final FirebaseFirestore? _firestore;

  FirebaseStorage get _storageInstance => _storage ?? FirebaseStorage.instance;

  FirebaseFirestore get _firestoreInstance =>
      _firestore ?? FirebaseFirestore.instance;

  @override
  Stream<int> publish(TrackUploadRequest request) async* {
    yield 0;

    final Reference audioRef = _storageInstance.ref(
      'artists/${request.artistId}/audio/${request.trackId}.mp3',
    );
    final Reference? coverRef = request.coverFileName == null
        ? null
        : _storageInstance.ref(
            'artists/${request.artistId}/covers/'
            '${request.trackId}.${_extensionOf(request.coverFileName!)}',
          );

    // 1 → 3 : stockage des fichiers, puis résolution des URLs publiques.
    late final String audioUrl;
    String? coverUrl;
    try {
      int lastReported = 0;
      await for (final TaskSnapshot snapshot
          in audioRef.putData(
            request.audioBytes,
            SettableMetadata(contentType: 'audio/mpeg'),
          ).snapshotEvents) {
        // Le MP3 occupe la plage 1 → 90 du flux.
        final int mapped = 1 + _percentOf(snapshot) * 89 ~/ 100;
        if (mapped > lastReported) {
          lastReported = mapped;
          yield mapped;
        }
      }

      if (coverRef != null && request.coverBytes != null) {
        final String contentType = _contentTypeFor(
          _extensionOf(request.coverFileName!),
        );
        await for (final TaskSnapshot snapshot
            in coverRef.putData(
              request.coverBytes!,
              SettableMetadata(contentType: contentType),
            ).snapshotEvents) {
          // La pochette occupe la plage 90 → 95 du flux.
          final int mapped = 90 + _percentOf(snapshot) * 5 ~/ 100;
          if (mapped > lastReported) {
            lastReported = mapped;
            yield mapped;
          }
        }
        coverUrl = await coverRef.getDownloadURL();
      }
      audioUrl = await audioRef.getDownloadURL();
    } on AdminException {
      rethrow;
    } on FirebaseException catch (error) {
      throw AdminException(
        'Téléversement interrompu (${error.code}) : vérifiez les règles '
        'Storage du projet.',
        cause: error,
      );
    } on Object catch (error) {
      throw AdminException(
        'Téléversement interrompu : vérifiez votre connexion réseau.',
        cause: error,
      );
    }
    yield 97;
    await _writeDocument(request, audioUrl: audioUrl, coverUrl: coverUrl);
    yield 100;
  }

  /// Écrit le document Firestore de la nouveauté, une fois l'audio en ligne.
  Future<void> _writeDocument(
    TrackUploadRequest request, {
    required String audioUrl,
    required String? coverUrl,
  }) async {
    final Map<String, dynamic> document = buildTrackDocument(
      request,
      audioUrl: audioUrl,
      coverUrl: coverUrl,
    );
    try {
      await _firestoreInstance.collection(tracksCollection).add(document);
    } on FirebaseException catch (error) {
      throw AdminException(
        'Le MP3 est en ligne mais l\'écriture du document a échoué '
        '(${error.code}) : vérifiez les règles Firestore.',
        cause: error,
      );
    } on Object catch (error) {
      throw AdminException(
        'Le MP3 est en ligne mais l\'écriture du document a échoué.',
        cause: error,
      );
    }
  }

  /// Pourcentage d'avancement d'un instantané Storage (0 → 100).
  static int _percentOf(TaskSnapshot snapshot) {
    final int total = snapshot.totalBytes;
    if (total <= 0) {
      return 0;
    }
    return ((snapshot.bytesTransferred / total) * 100).round().clamp(0, 100);
  }

  /// Document Firestore d'une nouveauté.
  ///
  /// Convention de nommage : les clés sont en `snake_case`, alignées sur le
  /// JSON du catalogue embarqué lu par `Track.fromJson` ; le champ `artistId`
  /// (camelCase) est celui interrogé par `FirebaseCatalogDataSource`.
  ///
  /// Exposé pour les tests (aucune dépendance Firebase dans sa logique).
  @visibleForTesting
  Map<String, dynamic> buildTrackDocument(
    TrackUploadRequest request, {
    required String audioUrl,
    required String? coverUrl,
  }) {
    return <String, dynamic>{
      'id': request.trackId,
      'title': request.title,
      'artist': request.artistName,
      'artistId': request.artistId,
      'artist_id': request.artistId,
      'album': request.album,
      'track_number': request.trackNumber,
      'release_year': request.releaseYear,
      'audio_url': audioUrl,
      'audio_asset': null,
      'cover_asset': null,
      'cover_url': coverUrl,
      'is_new': true,
      'is_downloadable': true,
      'is_downloaded': false,
      'created_at': FieldValue.serverTimestamp(),
    };
  }

  /// Extension minuscule d'un nom de fichier, sans le point.
  static String _extensionOf(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) {
      return 'jpg';
    }
    return fileName.substring(dot + 1).toLowerCase();
  }

  /// Type MIME d'une image d'après son extension.
  static String _contentTypeFor(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }
}
