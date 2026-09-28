import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:artistsaas/features/catalog/data/datasources/local_catalog_data_source.dart';
import 'package:artistsaas/features/catalog/domain/entities/track.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrôle du contenu réellement livré dans le bundle.
///
/// Ces tests attrapent ce qu'aucun autre ne verrait : une faute de frappe dans un
/// chemin `audio_asset`, une durée déclarée qui ne correspond pas au fichier, ou
/// un identifiant dupliqué (qui écraserait une entrée du stockage local).
void main() {
  const String catalogPath = LocalCatalogDataSource.defaultAssetPath;

  final List<Track> tracks = <Track>[];

  setUpAll(() {
    final Object? decoded = jsonDecode(File(catalogPath).readAsStringSync());

    expect(
      decoded,
      isA<List<Object?>>(),
      reason: 'le catalogue doit être une liste de pistes',
    );

    for (final Object? entry in decoded! as List<Object?>) {
      tracks.add(Track.fromJson(entry! as Map<String, dynamic>));
    }
  });

  test('le catalogue livré contient au moins une piste', () {
    expect(tracks, isNotEmpty);
  });

  test('les identifiants de piste sont uniques', () {
    final Set<String> identifiers =
        tracks.map((Track track) => track.id).toSet();

    expect(identifiers, hasLength(tracks.length));
  });

  test('les pistes sont numérotées dans l\'ordre, album par album', () {
    // Le catalogue est partagé : chaque album (ou single) redémarre à 1.
    // L'ordre est donc vérifié album par album, et non sur la liste entière.
    final Map<String, List<int>> byAlbum = <String, List<int>>{};
    for (final Track track in tracks) {
      final String album = (track.album == null || track.album!.isEmpty)
          ? 'Single'
          : track.album!;
      byAlbum.putIfAbsent(album, () => <int>[]).add(track.trackNumber ?? 0);
    }

    for (final MapEntry<String, List<int>> entry in byAlbum.entries) {
      expect(
        entry.value,
        <int>[for (int i = 1; i <= entry.value.length; i++) i],
        reason: 'numérotation continue dans l\'album « ${entry.key} »',
      );
    }
  });

  test('chaque piste référence un fichier audio présent', () {
    for (final Track track in tracks) {
      expect(
        File(track.audioAssetPath).existsSync(),
        isTrue,
        reason:
            '${track.id} référence un fichier absent : ${track.audioAssetPath}',
      );
    }
  });

  test('chaque piste référence une pochette présente', () {
    for (final Track track in tracks) {
      final String? cover = track.coverAsset;
      if (cover == null) {
        continue;
      }
      expect(
        File(cover).existsSync(),
        isTrue,
        reason: '${track.id} référence une pochette absente : $cover',
      );
    }
  });

  test('les MP3 hors-ligne sont des fichiers audio valides', () {
    // La durée d'un MP3 ne peut pas être relue sans décodeur : contrairement au
    // WAV, son en-tête ne porte pas d'horodatage, et le marqueur `Info` écrit
    // par ffmpeg se situe dans la région ID3v2 — l'analyser en Dart serait
    // fragile. Le contrôle vérifie donc l'intégrité du fichier ; l'exactitude
    // des durées est vérifiée à la génération par `ffprobe`
    // (cf. tool/generate_demo_audio.dart).
    for (final Track track in tracks.where(
      (Track track) => track.audioAssetPath.endsWith('.mp3'),
    )) {
      final File file = File(track.audioAssetPath);
      expect(file.existsSync(), isTrue, reason: track.audioAssetPath);
      expect(file.lengthSync(), greaterThan(1024), reason: track.id);
      expect(
        _hasMpegMagicNumber(file.readAsBytesSync()),
        isTrue,
        reason: '${track.id} n\'est pas un MP3 valide',
      );
      expect(track.duration, greaterThan(Duration.zero));
    }
  });

  test('les cinq titres hors-ligne de Jethsonat sont déclarés', () {
    final List<Track> jethsonat =
        tracks.where((Track track) => track.artistId == 'jethsonat').toList();

    expect(
      jethsonat,
      hasLength(5),
      reason: 'le catalogue doit livrer 5 titres hors-ligne à Jethsonat',
    );
    for (final Track track in jethsonat) {
      expect(track.label, 'Tete Roh Studio');
      expect(track.audioAssetPath, isNotEmpty);
      expect(track.hasRemoteSource, isFalse, reason: 'titre hors-ligne');
    }
  });

  test('la durée déclarée correspond à celle du fichier audio', () async {
    // Le contrôle ne s'applique qu'aux WAV PCM, dont l'en-tête est lisible
    // sans décodeur. Les autres formats (m4a, mp3) sont simplement ignorés :
    // le panneau d'administration saisit la durée à la publication.
    for (final Track track in tracks.where(
      (Track track) => track.audioAssetPath.endsWith('.wav'),
    )) {
      expect(
        track.duration,
        await _wavDuration(File(track.audioAssetPath)),
        reason: 'durée déclarée incorrecte pour ${track.id}',
      );
    }
  });
}

/// `true` si [bytes] commence par un début de fichier MPEG audio.
///
/// Deux formes sont admises : un tag ID3 (`ID3`), ou un en-tête de trame,
/// dont les 11 premiers bits sont toujours à 1 (`0xFF` suivi d'un octet dont
/// les trois bits hauts valent `0b111`).
bool _hasMpegMagicNumber(Uint8List bytes) {
  if (bytes.length < 4) {
    return false;
  }
  final String tag = String.fromCharCodes(bytes.sublist(0, 3));
  if (tag == 'ID3') {
    return true;
  }
  return bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0;
}

/// Lit la durée d'un WAV PCM non compressé depuis son en-tête.
Future<Duration> _wavDuration(File file) async {
  final Uint8List bytes = await file.readAsBytes();
  final ByteData view = ByteData.sublistView(bytes);

  final int channels = view.getUint16(22, Endian.little);
  final int sampleRate = view.getUint32(24, Endian.little);
  final int bitsPerSample = view.getUint16(34, Endian.little);
  final int dataBytes = view.getUint32(40, Endian.little);
  final int bytesPerSecond = sampleRate * channels * (bitsPerSample ~/ 8);

  return Duration(milliseconds: (dataBytes * 1000 / bytesPerSecond).round());
}
