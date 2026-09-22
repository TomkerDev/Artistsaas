// Outil de développement : génère les assets de marque « NOVAA ».
//
// L'identité visuelle étant fictive, tout est produit par ce script plutôt
// qu'acheté ou téléchargé : logo, icône de lancement et pochettes d'album.
// Les fichiers générés sont versionnés dans le dépôt ; le script ne sert donc
// qu'à les reproduire ou les faire évoluer.
//
// Usage : dart run tool/generate_brand_assets.dart
//
// Le logo est une « nova » : étoile à quatre branches blanche posée sur un
// dégradé violet → cyan. Les pochettes reprennent le même langage visuel avec
// une variation de géométrie par piste.
//
// Techniquement : PNG RGBA 8 bits, filtre 0 par ligne, compressé avec zlib
// (dart:io). Aucune dépendance externe.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

// Palette de la marque (identiques à lib/app/theme/app_colors.dart).
const int _violet = 0xFF6C3BF4;
const int _cyan = 0xFF00E5CC;
const int _night = 0xFF1A1024;

void main() {
  _writeImage('assets/brand/logo.png', 1024, _logoPaint(withRing: true));
  stdout.writeln('assets/brand/logo.png');

  _writeImage('assets/brand/icon.png', 1024, _logoPaint(withRing: false));
  stdout.writeln('assets/brand/icon.png');

  _writeImage(
    'android/app/src/main/res/drawable/brand_logo.png',
    512,
    _logoPaint(withRing: true),
  );
  stdout.writeln('android/app/src/main/res/drawable/brand_logo.png');

  for (int index = 0; index < 6; index++) {
    final String name = 'cover-${(index + 1).toString().padLeft(2, '0')}.png';
    _writeImage('assets/covers/$name', 512, _coverPaint(index));
    stdout.writeln('assets/covers/$name');
  }

  // Icônes de lancement par artiste, consommées par flutter_launcher_icons.yaml
  // (bloc `flavors`). Le motif reste la « nova », la teinte varie par artiste.
  for (int index = 0; index < _artistCount; index++) {
    final String path = 'assets/icons/artist_${index + 1}_icon.png';
    _writeImage(path, 1024, _artistIconPaint(index));
    stdout.writeln(path);
  }

  // Métadonnées embarquées par artiste : garantit l'existence (et le contenu)
  // des dossiers déclarés dans pubspec.yaml pour chaque flavor.
  for (int index = 0; index < _artistCount; index++) {
    final int number = index + 1;
    final String path = 'assets/artists/artist_$number/artist.json';
    final File file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(_artistManifest(number));
    stdout.writeln(path);
  }
}

/// Contenu JSON des métadonnées d'un artiste (numéro 1-based).
String _artistManifest(int number) {
  return '{\n'
      '  "id": "artist$number",\n'
      '  "name": "Artist $number",\n'
      '  "applicationId": "com.music.artist$number",\n'
      '  "icon": "assets/icons/artist_${number}_icon.png"\n'
      '}\n';
}

/// Nombre d'artistes exposés (aligné sur les flavors `artist1`..`artistN`).
const int _artistCount = 10;

// ---------------------------------------------------------------------------
// Motifs
// ---------------------------------------------------------------------------

/// Logo « nova » : disque en dégradé violet → cyan, étoile blanche à quatre
/// branches. `withRing` ajoute un liseré lumineux pour détacher le disque du
/// fond (utile sur splash, inutile sur l'icône au fond plein).
int Function(double, double) _logoPaint({required bool withRing}) {
  return (double x, double y) {
    final double dx = x - 0.5;
    final double dy = y - 0.5;
    final double distance = sqrt(dx * dx + dy * dy) * 2;
    final int base = _blend(_violet, _cyan, (x + y) / 2);
    if (distance > 0.46) {
      return _night;
    }
    if (withRing && distance > 0.42) {
      return _blend(base, 0xFFFFFFFF, (distance - 0.42) / 0.04 * 0.6);
    }
    return _star(dx, dy, base);
  };
}

/// Étoile blanche à quatre branches si le point est dedans, sinon [fallback].
int _star(double dx, double dy, int fallback) {
  final double power =
      pow(dx.abs() * 2, 4.0).toDouble() + pow(dy.abs() * 2, 4.0).toDouble();
  return power <= 0.55 ? 0xFFFFFFFF : fallback;
}

/// Icône de l'artiste [index] (0-based) : nova centrée sur un dégradé dont la
/// teinte est décalée pour différencier visuellement chaque artiste.
int Function(double, double) _artistIconPaint(int index) {
  final double hueShift = index / _artistCount;
  return (double x, double y) {
    final int base = _blend(_violet, _cyan, (x + y) / 2 + hueShift);
    final double dx = x - 0.5;
    final double dy = y - 0.5;
    final double distance = sqrt(dx * dx + dy * dy) * 2;
    if (distance > 0.46) {
      return _night;
    }
    return _star(dx, dy, base);
  };
}

/// Pochette numéro [index] : angle du dégradé tournant, forme centrale
/// différente par groupe de trois (nova, anneaux, diagonales).
int Function(double, double) _coverPaint(int index) {
  final double angle = index * pi / 6;
  final int shape = index % 3;
  return (double x, double y) {
    final double rotated =
        (x * cos(angle) + y * sin(angle) + 0.35).clamp(0.0, 1.2) / 1.2;
    final int base =
        _blend(_night, _blend(_violet, _cyan, index / 5), rotated);

    final double dx = x - 0.5;
    final double dy = y - 0.5;
    final double r = sqrt(dx * dx + dy * dy);

    switch (shape) {
      case 0:
        return _star(dx, dy, base);
      case 1:
        final double band = (r * 6) % 1;
        if (r < 0.42 && band < 0.35) {
          return _blend(base, 0xFFFFFFFF, 0.85);
        }
        return base;
      default:
        final double band = (((dx + dy) * 3.5) % 1 + 1) % 1;
        if (band < 0.18) {
          return _blend(base, 0xFFFFFFFF, 0.7);
        }
        return base;
    }
  };
}

// ---------------------------------------------------------------------------
// Primitives de dessin et d'encodage PNG.
// ---------------------------------------------------------------------------

/// Interpole deux couleurs selon `t` (0 → [from], 1 → [to]), alpha forcé à 255.
int _blend(int from, int to, double t) {
  final double clamped = t.clamp(0.0, 1.0);
  int channel(int color, int shift) => (color >> shift) & 0xFF;
  int mix(int shift) {
    final double value = channel(from, shift) +
        (channel(to, shift) - channel(from, shift)) * clamped;
    return value.round();
  }

  return (0xFF << 24) | (mix(16) << 16) | (mix(8) << 8) | mix(0);
}

/// Encode et écrit un PNG RGBA 8 bits : trame filtrée (filtre 0) compressée
/// avec zlib, chunks IHDR / IDAT / IEND avec CRC32.
void _writeImage(String path, int size, int Function(double, double) paint) {
  final BytesBuilder png = BytesBuilder();

  // Signature.
  png.add(<int>[137, 80, 78, 71, 13, 10, 26, 10]);

  // IHDR : largeur, hauteur, 8 bits, RGBA, pas d'entrelacement.
  final ByteData ihdr = ByteData(13)
    ..setUint32(0, size, Endian.big)
    ..setUint32(4, size, Endian.big)
    ..setUint8(8, 8)
    ..setUint8(9, 6)
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  png.add(_chunk('IHDR', ihdr.buffer.asUint8List()));

  // Trame filtrée : un octet 0 avant chaque ligne RGBA.
  final Uint8List raw = Uint8List(size * (size * 4 + 1));
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final int color = paint(x / (size - 1), y / (size - 1));
      final int offset = y * (size * 4 + 1) + 1 + x * 4;
      raw[offset] = (color >> 16) & 0xFF;
      raw[offset + 1] = (color >> 8) & 0xFF;
      raw[offset + 2] = color & 0xFF;
      raw[offset + 3] = 0xFF;
    }
  }
  png.add(_chunk('IDAT', ZLibEncoder(level: 9).convert(raw)));
  png.add(_chunk('IEND', Uint8List(0)));

  final File file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(png.takeBytes());
}

/// Construit un chunk PNG complet : longueur, type, données, CRC32.
Uint8List _chunk(String type, List<int> data) {
  // longueur (4) + type (4) + données + CRC (4).
  final Uint8List payload = Uint8List(8 + data.length + 4);
  final ByteData view = ByteData.view(payload.buffer);
  view.setUint32(0, data.length, Endian.big);
  for (int index = 0; index < 4; index++) {
    payload[4 + index] = type.codeUnitAt(index);
  }
    payload.setRange(8, 8 + data.length, data);
  // CRC couvre uniquement le *type* et les *données* (pas le champ longueur).
  final Uint8List crcSource = payload.sublist(4, 8 + data.length);

  view.setUint32(
    payload.length - 4,
    _crc32(crcSource),
    Endian.big,
  );
  return payload;
}

/// CRC32 (polygone 0xEDB88320, table non précalculée).
int _crc32(Uint8List data) {
  int crc = 0xFFFFFFFF;
  for (final int byte in data) {
    crc ^= byte;
    for (int bit = 0; bit < 8; bit++) {
      crc = (crc >> 1) ^ (0xEDB88320 & -(crc & 1));
    }
  }
  return ~crc;
}

