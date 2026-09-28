// Outil de développement : génère les fichiers audio de démonstration.
//
// Deux familles cohabitent dans `assets/audio/` :
//
// 1. les **démonstrations** du MVP (`demo-0X.wav`) : de courts fichiers WAV
//    synthétiques, qui valident la chaîne technique (matérialisation locale,
//    lecture, reprise, position) sans embarquer de contenu dont les droits ne
//    sont pas maîtrisés ;
// 2. les **hors-ligne de Jethsonat** (`jethsonat_0X.mp3`) : les cinq titres
//    livrés dans l'APK pour jouer sans réseau, sous signature Tete Roh Studio.
//    Ce sont des motifs synthétiques de remplacement — les vrais masters
//    doivent être déposés à la place (voir README, « Catalogue hors-ligne »).
//
// Usage : dart run tool/generate_demo_audio.dart
//
// Contrainte à respecter : la durée déclarée dans assets/catalog/catalog.json
// (clé `duration_ms`) doit correspondre exactement à la durée du fichier généré,
// sans quoi la barre de progression du lecteur serait fausse. Les durées sont
// donc calculées ici, et non choisies à la main.
//
// La conversion WAV → MP3 requiert `ffmpeg` sur le PATH. En son absence, le WAV
// est conservé et un avertissement est émis : le catalogue référence alors les
// fichiers `.wav`, et non `.mp3`.

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

  // Catalogue hors-ligne de Jethsonat (label Tete Roh Studio).
  _generateOfflineTracks(directory);
}

/// Génère les cinq titres livrés dans l'APK pour l'écoute sans réseau.
///
/// Chaque piste est d'abord rendue en WAV, puis convertie en MP3 via `ffmpeg` :
/// le format attendu pour un catalogue commercial, ~10x plus léger que le WAV à
/// qualité équivalente. Les durées imprimées ici sont celles à reporter dans
/// `assets/catalog/catalog.json` (`duration_ms`).
void _generateOfflineTracks(Directory directory) {
  for (final _OfflineTrack track in _offlineTracks) {
    final Uint8List wav = _buildOfflineWav(track);
    final File wavFile = File('${directory.path}/${track.baseName}.wav');
    wavFile.writeAsBytesSync(wav);

    final File? mp3 = _toMp3(wavFile, track.baseName);
    if (mp3 != null) {
      // Le WAV n'est plus référencé : on le supprime pour ne pas gonfler
      // inutilement le bundle (deux copies pour le même morceau).
      wavFile.deleteSync();
    }

    final File produced = mp3 ?? wavFile;
    final int expected = _offlineDurationMs(track);
    stdout.writeln(
      '${produced.path.split(Platform.pathSeparator).last} : '
      '$expected ms, ${(produced.lengthSync() / 1024).round()} Ko',
    );

    // La durée déclarée dans `catalog.json` doit correspondre à la durée réelle
    // du fichier, sinon la barre de progression du lecteur ment. `ffprobe` fait
    // autorité ici : un MP3 n'est pas vérifiable en Dart.
    if (mp3 != null) {
      final int? actual = _probeDurationMs(mp3);
      if (actual == null) {
        stderr.writeln(
          'ffprobe indisponible : durée de ${mp3.path} non vérifiée.',
        );
      } else if ((actual - expected).abs() > 60) {
        stderr.writeln(
          'ATTENTION : ${mp3.path} dure $actual ms alors que le catalogue '
          'annonce $expected ms.',
        );
      }
    }
  }
}

/// Durée réelle d'un fichier en millisecondes, lue par `ffprobe`.
///
/// Renvoie `null` si `ffprobe` est absent ou si sa sortie est illisible.
int? _probeDurationMs(File file) {
  final ProcessResult result = Process.runSync('ffprobe', <String>[
    '-v',
    'error',
    '-show_entries',
    'format=duration',
    '-of',
    'csv=p=0',
    file.path,
  ]);
  if (result.exitCode != 0) {
    return null;
  }
  final double? seconds = double.tryParse(
    (result.stdout as String).trim(),
  );
  return seconds == null ? null : (seconds * 1000).round();
}

/// Convertit [source] en MP3 à côté de lui. Renvoie `null` si `ffmpeg` est
/// indisponible, auquel cas le WAV est conservé.
File? _toMp3(File source, String baseName) {
  final ProcessResult probe = Process.runSync('ffmpeg', <String>['-version']);
  if (probe.exitCode != 0) {
    stderr.writeln(
      'ffmpeg est introuvable : « $baseName » reste en WAV. '
      'Installez ffmpeg pour produire les MP3.',
    );
    return null;
  }

  final File target = File('${source.parent.path}/$baseName.mp3');
  final ProcessResult result = Process.runSync('ffmpeg', <String>[
    '-y',
    '-loglevel', 'error',
    '-i', source.path,
    // 96 kbps mono : suffisant pour un morceau de distribution numérique et
    // cohérent avec l'estimation de taille documentée dans le README.
    '-b:a', '96k',
    '-ac', '1',
    target.path,
  ]);

  if (result.exitCode != 0) {
    stderr
        .writeln('Échec de la conversion MP3 de $baseName : ${result.stderr}');
    return null;
  }
  return target;
}

/// Durée d'un titre hors-ligne, en millisecondes.
int _offlineDurationMs(_OfflineTrack track) =>
    track.motif.length * _offlineNoteMilliseconds * track.repetitions;

/// Rend un titre hors-ligne en WAV PCM 16 bits mono.
///
/// Même principe que [_buildWav] : une onde sinusoïdale par note, avec
/// enveloppe d'attaque et de relâchement pour éviter les clics.
Uint8List _buildOfflineWav(_OfflineTrack track) {
  final int totalMs = _offlineDurationMs(track);
  final int sampleCount = (_offlineSampleRate * totalMs / 1000).round();
  final Int16List samples = Int16List(sampleCount);
  final int noteSamples =
      (_offlineSampleRate * _offlineNoteMilliseconds / 1000).round();

  int cursor = 0;
  for (int repetition = 0; repetition < track.repetitions; repetition++) {
    for (final double frequency in track.motif) {
      for (int index = 0;
          index < noteSamples && cursor < sampleCount;
          index++) {
        final double seconds = index / _offlineSampleRate;
        final double wave = sin(2 * pi * frequency * seconds);
        samples[cursor] = (wave *
                _envelope(
                  index,
                  noteSamples,
                  sampleRate: _offlineSampleRate,
                ) *
                _amplitude *
                32767)
            .round();
        cursor++;
      }
    }
  }

  return _encodeWav(samples, sampleRate: _offlineSampleRate);
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
      for (int index = 0;
          index < noteSamples && cursor < sampleCount;
          index++) {
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
///
/// [sampleRate] doit correspondre à la fréquence d'échantillonnage du signal
/// produit, sinon l'attaque et le relâchement sont calés sur une durée fausse.
double _envelope(int index, int length, {int sampleRate = _sampleRate}) {
  final int attack = (sampleRate * 0.012).round();
  final int release = (sampleRate * 0.09).round();

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
///
/// [sampleRate] doit correspondre à la fréquence réellement utilisée pour
/// produire [samples] : une valeur divergente dans l'en-tête fait lire le
/// fichier à une vitesse erronée, et donc une durée fausse.
Uint8List _encodeWav(Int16List samples, {int sampleRate = _sampleRate}) {
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
  view.setUint32(24, sampleRate, Endian.little);
  view.setUint32(28, sampleRate * bytesPerSample, Endian.little);
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

// ---------------------------------------------------------------------------
// Catalogue hors-ligne — Jethsonat (Tete Roh Studio)
// ---------------------------------------------------------------------------

/// Fréquence d'échantillonnage des titres hors-ligne.
const int _offlineSampleRate = 22050;

/// Durée d'une note des motifs hors-ligne, en millisecondes.
const int _offlineNoteMilliseconds = 500;

/// Les cinq titres livrés dans l'APK de Jethsonat.
///
/// Les motifs s'inspirent de l'univers « Sec Sec » et les répétitions fixent
/// des durées distinctes : la barre de progression diffère ainsi visuellement
/// d'un morceau à l'autre. Les titres doivent être remplacés par les vrais
/// masters — la durée déclarée dans `catalog.json` devra alors être mise à
/// jour pour rester alignée sur le fichier livré.
const List<_OfflineTrack> _offlineTracks = <_OfflineTrack>[
  _OfflineTrack(
    baseName: 'jethsonat_01',
    motif: <double>[220.00, 277.18, 329.63, 440.00, 329.63, 277.18],
    repetitions: 8,
  ),
  _OfflineTrack(
    baseName: 'jethsonat_02',
    motif: <double>[196.00, 246.94, 293.66, 392.00],
    repetitions: 10,
  ),
  _OfflineTrack(
    baseName: 'jethsonat_03',
    motif: <double>[261.63, 329.63, 392.00, 523.25, 392.00, 329.63],
    repetitions: 7,
  ),
  _OfflineTrack(
    baseName: 'jethsonat_04',
    motif: <double>[174.61, 220.00, 261.63, 349.23, 261.63, 220.00],
    repetitions: 9,
  ),
  _OfflineTrack(
    baseName: 'jethsonat_05',
    motif: <double>[293.66, 349.23, 440.00, 587.33, 440.00, 349.23, 293.66],
    repetitions: 6,
  ),
];

/// Description d'un titre hors-ligne.
class _OfflineTrack {
  const _OfflineTrack({
    required this.baseName,
    required this.motif,
    required this.repetitions,
  });

  /// Nom de base, sans extension : `jethsonat_01` → `jethsonat_01.mp3`.
  final String baseName;

  /// Notes du motif, en hertz.
  final List<double> motif;

  /// Nombre de répétitions du motif.
  final int repetitions;
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
