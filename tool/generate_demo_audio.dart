// Outil de développement : génère les fichiers audio de démonstration.
//
// Le catalogue de démonstration du MVP référence de courts fichiers WAV
// synthétiques : ils permettent de valider toute la chaîne technique
// (matérialisation locale, lecture, reprise, position) sans embarquer de contenu
// dont les droits ne sont pas maîtrisés. Ils seront remplacés par les vrais
// masters avant toute publication.
//
// Usage : dart run tool/generate_demo_audio.dart
//
// Contrainte à respecter : la durée déclarée dans assets/catalog/catalog.json
// (clé `duration_ms`) doit correspondre exactement à la durée du fichier généré,
// sans quoi la barre de progression du lecteur serait fausse. Les durées sont
// donc calculées ici, et non choisies à la main.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Fréquence d'échantillonnage : suffisante pour des notes synthétiques et
/// deux fois plus légère qu'un CD.
const int _sampleRate = 11025;

/// Durée d'une note du motif, en millisecondes.
const int _noteMilliseconds = 500;

/// Amplitude crête, volontairement basse pour rester confortable à l'écoute.
const double _amplitude = 0.32;

// Fréquences des notes utilisées (en hertz).
const double _a3 = 220.00;
const double _c4 = 261.63;
const double _d4 = 293.66;
const double _e4 = 329.63;
const double _f4 = 349.23;
const double _g4 = 392.00;
const double _a4 = 440.00;
const double _b4 = 493.88;
const double _c5 = 523.25;
const double _d5 = 587.33;
const double _e5 = 659.25;

const List<_Demo> _demos = <_Demo>[
  _Demo(
    fileName: 'demo-01.wav',
    motif: <double>[_c4, _e4, _g4, _c5, _g4, _e4],
    repetitions: 8,
  ),
  _Demo(
    fileName: 'demo-02.wav',
    motif: <double>[_a3, _c4, _e4, _a4, _e4, _c4],
    repetitions: 7,
  ),
  _Demo(
    fileName: 'demo-03.wav',
    motif: <double>[_d4, _f4, _a4, _d5, _a4, _f4],
    repetitions: 6,
  ),
  _Demo(
    fileName: 'demo-04.wav',
    motif: <double>[_g4, _b4, _d5, _b4],
    repetitions: 13,
  ),
  _Demo(
    fileName: 'demo-05.wav',
    motif: <double>[_e4, _g4, _b4, _e5, _b4, _g4],
    repetitions: 8,
  ),
  _Demo(
    fileName: 'demo-06.wav',
    motif: <double>[_f4, _a4, _c5, _a4],
    repetitions: 10,
  ),
];

void main() {
  final Directory directory = Directory('assets/audio');
  directory.createSync(recursive: true);

  for (final _Demo demo in _demos) {
    final Uint8List wav = _buildWav(demo);
    File('${directory.path}/${demo.fileName}').writeAsBytesSync(wav);
    stdout.writeln(
      '${demo.fileName} : ${_durationMs(demo)} ms, '
      '${(wav.length / 1024).round()} Ko',
    );
  }
}

/// Durée totale d'une piste, en millisecondes.
int _durationMs(_Demo demo) =>
    demo.motif.length * _noteMilliseconds * demo.repetitions;

Uint8List _buildWav(_Demo demo) {
  final int totalMs = _durationMs(demo);
  final int sampleCount = (_sampleRate * totalMs / 1000).round();
  final Int16List samples = Int16List(sampleCount);
  final int noteSamples = (_sampleRate * _noteMilliseconds / 1000).round();

  int cursor = 0;
  for (int repetition = 0; repetition < demo.repetitions; repetition++) {
    for (final double frequency in demo.motif) {
      for (
        int index = 0;
        index < noteSamples && cursor < sampleCount;
        index++
      ) {
        final double seconds = index / _sampleRate;
        final double wave = sin(2 * pi * frequency * seconds);
        samples[cursor] =
            (wave * _envelope(index, noteSamples) * _amplitude * 32767).round();
        cursor++;
      }
    }
  }

  return _encodeWav(samples);
}

/// Enveloppe d'attaque et de relâchement, pour éviter les clics entre notes.
double _envelope(int index, int length) {
  final int attack = (_sampleRate * 0.012).round();
  final int release = (_sampleRate * 0.09).round();

  double gain = 1;
  if (index < attack) {
    gain = index / attack;
  }
  final int remaining = length - index;
  if (remaining < release) {
    gain = min(gain, remaining / release);
  }
  return gain;
}

/// Encode les échantillons dans un conteneur WAV PCM 16 bits mono.
Uint8List _encodeWav(Int16List samples) {
  const int bytesPerSample = 2;
  final int dataBytes = samples.length * bytesPerSample;
  final Uint8List output = Uint8List(44 + dataBytes);
  final ByteData view = ByteData.view(output.buffer);

  _writeAscii(view, 0, 'RIFF');
  view.setUint32(4, 36 + dataBytes, Endian.little);
  _writeAscii(view, 8, 'WAVE');
  _writeAscii(view, 12, 'fmt ');
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, 1, Endian.little);
  view.setUint32(24, _sampleRate, Endian.little);
  view.setUint32(28, _sampleRate * bytesPerSample, Endian.little);
  view.setUint16(32, bytesPerSample, Endian.little);
  view.setUint16(34, 16, Endian.little);
  _writeAscii(view, 36, 'data');
  view.setUint32(40, dataBytes, Endian.little);

  for (int index = 0; index < samples.length; index++) {
    view.setInt16(44 + index * bytesPerSample, samples[index], Endian.little);
  }

  return output;
}

void _writeAscii(ByteData view, int offset, String value) {
  for (int index = 0; index < value.length; index++) {
    view.setUint8(offset + index, value.codeUnitAt(index));
  }
}

/// Description d'une piste de démonstration.
class _Demo {
  const _Demo({
    required this.fileName,
    required this.motif,
    required this.repetitions,
  });

  /// Nom du fichier écrit dans `assets/audio/`.
  final String fileName;

  /// Notes du motif, en hertz.
  final List<double> motif;

  /// Nombre de répétitions du motif.
  final int repetitions;
}
