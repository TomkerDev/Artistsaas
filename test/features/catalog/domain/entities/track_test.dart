import 'package:artistsaas/core/errors/app_exception.dart';
import 'package:artistsaas/features/catalog/domain/entities/track.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> minimalJson() => <String, dynamic>{
    'id': 'single-001',
    'title': 'Premier titre',
    'artist': 'Nom de scène',
    'duration_ms': 213000,
    'audio_asset': 'assets/audio/single-001.mp3',
  };

  Map<String, dynamic> completeJson() => <String, dynamic>{
    ...minimalJson(),
    'album': 'EP 2026',
    'track_number': 2,
    'release_year': 2026,
    'cover_asset': 'assets/images/covers/single-001.jpg',
    'audio_url': 'https://exemple.test/single-001.mp3',
    'is_downloadable': false,
    'is_new': true,
    'is_downloaded': true,
  };

  group('Track.fromJson', () {
    test('applique les valeurs par défaut des champs facultatifs', () {
      final Track track = Track.fromJson(minimalJson());

      expect(track.id, 'single-001');
      expect(track.title, 'Premier titre');
      expect(track.artistName, 'Nom de scène');
      expect(track.duration, const Duration(milliseconds: 213000));
      expect(track.audioAssetPath, 'assets/audio/single-001.mp3');
      expect(track.album, isNull);
      expect(track.trackNumber, isNull);
      expect(track.releaseYear, isNull);
      expect(track.coverAsset, isNull);
      expect(track.audioUrl, isNull);
      expect(track.isDownloadable, isTrue);
      expect(track.isNew, isFalse);
      expect(track.isDownloaded, isFalse);
      expect(track.hasRemoteSource, isFalse);
    });

    test('lit tous les champs facultatifs', () {
      final Track track = Track.fromJson(completeJson());

      expect(track.album, 'EP 2026');
      expect(track.trackNumber, 2);
      expect(track.releaseYear, 2026);
      expect(track.coverAsset, 'assets/images/covers/single-001.jpg');
      expect(track.audioUrl, Uri.parse('https://exemple.test/single-001.mp3'));
      expect(track.isDownloadable, isFalse);
      expect(track.isNew, isTrue);
      expect(track.isDownloaded, isTrue);
      expect(track.hasRemoteSource, isTrue);
    });

    test('accepte un nombre écrit en notation décimale', () {
      final Map<String, dynamic> json = minimalJson()
        ..['duration_ms'] = 213000.0;

      expect(
        Track.fromJson(json).duration,
        const Duration(milliseconds: 213000),
      );
    });

    test('supprime les espaces superflus et vide les textes blancs', () {
      final Map<String, dynamic> json = minimalJson()
        ..['title'] = '  Titre espacé  '
        ..['album'] = '   ';

      final Track track = Track.fromJson(json);
      expect(track.title, 'Titre espacé');
      expect(track.album, isNull);
    });

    test('échoue quand un champ obligatoire est absent', () {
      for (final String key in <String>[
        'id',
        'title',
        'artist',
        'duration_ms',
        'audio_asset',
      ]) {
        final Map<String, dynamic> json = minimalJson()..remove(key);
        expect(
          () => Track.fromJson(json),
          throwsA(isA<CatalogException>()),
          reason: 'la clé « $key » doit être obligatoire',
        );
      }
    });

    test('échoue sur une durée nulle ou négative', () {
      for (final num duration in <num>[0, -1]) {
        final Map<String, dynamic> json = minimalJson()
          ..['duration_ms'] = duration;
        expect(
          () => Track.fromJson(json),
          throwsA(isA<CatalogException>()),
          reason: 'duration_ms = $duration doit être refusé',
        );
      }
    });

    test('échoue sur un texte obligatoire vide', () {
      final Map<String, dynamic> json = minimalJson()..['title'] = '   ';

      expect(() => Track.fromJson(json), throwsA(isA<CatalogException>()));
    });

    test('échoue sur un type inattendu', () {
      final List<Map<String, dynamic>> invalides = <Map<String, dynamic>>[
        minimalJson()..['title'] = 42,
        minimalJson()..['duration_ms'] = '3:33',
        minimalJson()..['track_number'] = 'deux',
        minimalJson()..['is_downloadable'] = 'oui',
        minimalJson()..['is_new'] = 'oui',
        minimalJson()..['is_downloaded'] = 'non',
      ];

      for (final Map<String, dynamic> json in invalides) {
        expect(() => Track.fromJson(json), throwsA(isA<CatalogException>()));
      }
    });

    test('échoue sur une URL relative', () {
      final Map<String, dynamic> json = minimalJson()
        ..['audio_url'] = '/audio/single-001.mp3';

      expect(() => Track.fromJson(json), throwsA(isA<CatalogException>()));
    });
  });

  group('Track.toJson', () {
    test("restitue exactement la piste d'origine", () {
      final Track original = Track.fromJson(completeJson());

      expect(Track.fromJson(original.toJson()), original);
    });

    test('omet les clés facultatives non renseignées', () {
      final Map<String, Object?> json = Track.fromJson(minimalJson()).toJson();

      expect(json.containsKey('album'), isFalse);
      expect(json.containsKey('audio_url'), isFalse);
      expect(json['duration_ms'], 213000);
      expect(json['is_downloadable'], isTrue);
      expect(json['is_new'], isFalse);
      expect(json['is_downloaded'], isFalse);
    });
  });

  group('égalité', () {
    test('deux pistes issues des mêmes données sont égales', () {
      final Track first = Track.fromJson(completeJson());
      final Track second = Track.fromJson(completeJson());

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('un seul champ différent suffit à les distinguer', () {
      final Track reference = Track.fromJson(minimalJson());
      final Track autreTitre = Track.fromJson(
        minimalJson()..['title'] = 'Autre titre',
      );

      expect(reference == autreTitre, isFalse);
    });
  });
}
