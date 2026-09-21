import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:artistsaas/features/catalog/data/datasources/asset_catalog_data_source.dart';
import 'package:artistsaas/features/catalog/domain/entities/track.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrôle du contenu réellement livré dans le bundle.
///
/// Ces tests attrapent ce qu'aucun autre ne verrait : une faute de frappe dans un
/// chemin `audio_asset`, une durée déclarée qui ne correspond pas au fichier, ou
/// un identifiant dupliqué (qui écraserait une entrée du stockage local).
void main() {
  const String catalogPath = AssetCatalogDataSource.defaultAssetPath;

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
    final Set<String> identifiers = tracks
        .map((Track track) => track.id)
        .toSet();

    expect(identifiers, hasLength(tracks.length));
  });

  test('les pistes sont numérotées dans l\'ordre du catalogue', () {
    final List<int> numbers = tracks
        .where((Track track) => track.trackNumber != null)
        .map((Track track) => track.trackNumber!)
        .toList();

    expect(numbers, <int>[for (int i = 1; i <= numbers.length; i++) i]);
  });

  test('chaque piste référence un fichier audio présent', () {
    for (final Track track in tracks) {
      expect(
        File(track.audioAsset).existsSync(),
        isTrue,
        reason: '${track.id} référence un fichier absent : ${track.audioAsset}',
      );
    }
  });

  test('la durée déclarée correspond à celle du fichier audio', () async {
    for (final Track track in tracks) {
      expect(
        track.duration,
        await _wavDuration(File(track.audioAsset)),
        reason: 'durée déclarée incorrecte pour ${track.id}',
      );
    }
  });
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
