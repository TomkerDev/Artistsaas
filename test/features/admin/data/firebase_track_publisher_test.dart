import 'dart:typed_data';

import 'package:artistsaas/features/admin/data/datasources/firebase_track_publisher.dart';
import 'package:artistsaas/features/admin/domain/services/track_publisher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrat du document Firestore publié par le panneau d'administration.
///
/// Le document doit rester lisible par `FirebaseCatalogDataSource._toTrack` →
/// `Track.fromJson` : mêmes clés `snake_case`, `is_new: true`, et un champ
/// `artistId` (interrogé par `fetchNewTracks`). La logique testée est pure :
/// elle ne touche ni Storage ni Firestore.
void main() {
  group('FirebaseTrackPublisher.buildTrackDocument', () {
    test('construit un document complet avec pochette', () {
      final TrackUploadRequest request = TrackUploadRequest(
        artistId: 'artist_2',
        artistName: 'Artist 2',
        trackId: 'summer-remix',
        title: 'Summer Remix',
        audioFileName: 'summer.mp3',
        audioBytes: Uint8List(0),
        album: 'Été 2026',
        trackNumber: 3,
        releaseYear: 2026,
        coverFileName: 'cover.png',
        coverBytes: Uint8List(0),
      );

      final Map<String, dynamic> document = FirebaseTrackPublisher()
          .buildTrackDocument(
            request,
            audioUrl: 'https://storage.example/summer.mp3',
            coverUrl: 'https://storage.example/cover.png',
          );

      expect(document['id'], 'summer-remix');
      expect(document['title'], 'Summer Remix');
      expect(document['artist'], 'Artist 2');
      expect(document['artistId'], 'artist_2');
      expect(document['artist_id'], 'artist_2');
      expect(document['album'], 'Été 2026');
      expect(document['track_number'], 3);
      expect(document['release_year'], 2026);
      expect(document['audio_url'], 'https://storage.example/summer.mp3');
      expect(document['cover_url'], 'https://storage.example/cover.png');
      expect(document['is_new'], isTrue);
      expect(document['is_downloadable'], isTrue);
      expect(document['created_at'], isA<FieldValue>());
    });
    test('sans pochette, les champs facultatifs restent nuls', () {
      final TrackUploadRequest request = TrackUploadRequest(
        artistId: 'artist_10',
        artistName: 'Artist 10',
        trackId: 'winter-demo',
        title: 'Winter Demo',
        audioFileName: 'winter.mp3',
        audioBytes: Uint8List(0),
      );

      final Map<String, dynamic> document = FirebaseTrackPublisher()
          .buildTrackDocument(request, audioUrl: 'https://s/x.mp3', coverUrl: null);

      expect(document['cover_url'], isNull);
      expect(document['album'], isNull);
      expect(document['track_number'], isNull);
      expect(document['release_year'], isNull);
      expect(document['is_new'], isTrue);
    });
  });
}

