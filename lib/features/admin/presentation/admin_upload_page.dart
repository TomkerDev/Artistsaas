import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/byte_formatter.dart';
import '../domain/services/track_publisher.dart';
import 'admin_login_page.dart';
import 'admin_providers.dart';

/// Option du menu déroulant des artistes cibles.
final class AdminArtistOption {
  const AdminArtistOption({required this.id, required this.name});

  /// Identifiant de l'artiste (`artist_1`, `artist_2`, …), utilisé comme
  /// préfixe Storage et comme champ `artistId` du document Firestore.
  final String id;

  /// Nom de scène affiché dans le menu et écrit dans le champ `artist`.
  final String name;
}

/// Panneau de publication des nouveautés multi-artistes.
///
/// Déroulé d'une publication :
/// 1. l'administrateur choisit l'artiste cible (`artist_1` … `artist_10`),
///    saisit les méta-données et sélectionne le MP3 compressé (+ pochette) ;
/// 2. [TrackPublisher] téléverse l'audio dans
///    `artists/<artistId>/audio/<trackId>.mp3`, la pochette dans
///    `artists/<artistId>/covers/`, puis crée le document Firestore `tracks`
///    avec `is_new: true` ;
/// 3. la progression (0 → 100) est affichée en direct.
///
/// L'écran n'est accessible qu'après la connexion de [AdminLoginPage] : une
/// session qui expire renvoie automatiquement à celle-ci.
class AdminUploadPage extends ConsumerStatefulWidget {
  const AdminUploadPage({super.key});

  @override
  ConsumerState<AdminUploadPage> createState() => _AdminUploadPageState();
}

class _AdminUploadPageState extends ConsumerState<AdminUploadPage> {
  static const List<AdminArtistOption> _artists = <AdminArtistOption>[
    AdminArtistOption(id: 'artist_1', name: 'Artist 1'),
    AdminArtistOption(id: 'artist_2', name: 'Artist 2'),
    AdminArtistOption(id: 'artist_3', name: 'Artist 3'),
    AdminArtistOption(id: 'artist_4', name: 'Artist 4'),
    AdminArtistOption(id: 'artist_5', name: 'Artist 5'),
    AdminArtistOption(id: 'artist_6', name: 'Artist 6'),
    AdminArtistOption(id: 'artist_7', name: 'Artist 7'),
    AdminArtistOption(id: 'artist_8', name: 'Artist 8'),
    AdminArtistOption(id: 'artist_9', name: 'Artist 9'),
    AdminArtistOption(id: 'artist_10', name: 'Artist 10'),
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _trackId = TextEditingController();
  final TextEditingController _album = TextEditingController();
  final TextEditingController _trackNumber = TextEditingController();
  final TextEditingController _year = TextEditingController();

  String _artistId = 'artist_1';
  PlatformFile? _audioFile;
  PlatformFile? _coverFile;

  bool _publishing = false;
  bool _exiting = false;
  int _progress = 0;
  String? _errorMessage;

  @override
  void dispose() {
    _title.dispose();
    _trackId.dispose();
    _album.dispose();
    _trackNumber.dispose();
    _year.dispose();
    super.dispose();
  }

  /// Nom de scène de l'artiste sélectionné, tel qu'affiché dans l'application.
  String get _artistName =>
      _artists.firstWhere((AdminArtistOption a) => a.id == _artistId).name;

  /// Sélectionne un MP3 compressé (filtre `file_picker`, données en mémoire).
  Future<void> _pickAudio() async {
    final PlatformFile? file = await ref
        .read(adminFilePickerProvider)
        .pickAudio();
    if (file == null || !mounted) {
      return;
    }
    setState(() => _audioFile = file);
    // Identifiant proposé à partir du nom de fichier tant qu'aucun n'est saisi.
    if (_trackId.text.trim().isEmpty) {
      final String suggested = _slugify(
        file.name.replaceFirst(RegExp(r'\.mp3$', caseSensitive: false), ''),
      );
      if (suggested.isNotEmpty) {
        _trackId.text = suggested;
      }
    }
  }

  /// Sélectionne une pochette (image, données en mémoire).
  Future<void> _pickCover() async {
    final PlatformFile? file = await ref
        .read(adminFilePickerProvider)
        .pickCover();
    if (file == null || !mounted) {
      return;
    }
    setState(() => _coverFile = file);
  }

  /// Normalise un texte en identifiant de document (`slug` ASCII).
  static String _slugify(String input) {
    final String lowered = input.toLowerCase().trim();
    final StringBuffer buffer = StringBuffer();
    for (final int code in lowered.codeUnits) {
      final String char = String.fromCharCode(code);
      if (RegExp(r'[a-z0-9]').hasMatch(char)) {
        buffer.write(char);
      } else if (char == ' ' || char == '-' || char == '_') {
        buffer.write('-');
      }
      // Les accents et la ponctuation sont ignorés : l'identifiant reste un
      // slug ASCII exploitable comme nom de fichier et comme id Firestore.
    }
    return buffer
        .toString()
        .replaceAll(RegExp('-+'), '-')
        .replaceFirst(RegExp('^-'), '');
  }

  /// Publie la nouveauté : Storage puis Firestore, avec progression en direct.
  Future<void> _publish() async {
    final FormState? form = _formKey.currentState;
    if (form == null || _publishing) {
      return;
    }
    if (_audioFile == null || _audioFile!.bytes == null) {
      setState(() => _errorMessage = 'Sélectionnez le fichier MP3 à verser.');
      return;
    }
    if (!form.validate()) {
      return;
    }
    final PlatformFile audio = _audioFile!;
    final PlatformFile? cover = _coverFile;

    setState(() {
      _publishing = true;
      _progress = 0;
      _errorMessage = null;
    });
    try {
      final Stream<int> events = ref
          .read(trackPublisherProvider)
          .publish(
            TrackUploadRequest(
              artistId: _artistId,
              artistName: _artistName,
              trackId: _trackId.text.trim(),
              title: _title.text.trim(),
              audioFileName: audio.name,
              audioBytes: audio.bytes!,
              album: _album.text.trim().isEmpty ? null : _album.text.trim(),
              trackNumber: int.tryParse(_trackNumber.text.trim()),
              releaseYear: int.tryParse(_year.text.trim()),
              coverFileName: cover?.name,
              coverBytes: cover?.bytes,
            ),
          );
      final String publishedTitle = _title.text.trim();
      await for (final int percent in events) {
        if (!mounted) {
          return;
        }
        setState(() => _progress = percent);
      }
      if (!mounted) {
        return;
      }
      _resetAfterSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('« $publishedTitle » publiée pour $_artistName.')),
      );
    } on AdminException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } on Object {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Publication impossible : vérifiez votre connexion et les '
              'règles Firebase (Auth, Storage, Firestore).';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _publishing = false);
      }
    }
  }

  /// Réinitialise le formulaire après un succès : l'artiste reste sélectionné
  /// pour enchaîner plusieurs titres du même artiste.
  void _resetAfterSuccess() {
    _title.clear();
    _trackId.clear();
    _album.clear();
    _trackNumber.clear();
    _year.clear();
    setState(() {
      _audioFile = null;
      _coverFile = null;
      _progress = 0;
    });
  }

  /// Retour à l'écran de connexion dès que la session n'est plus active.
  void _handleSession() {
    ref.listen<AsyncValue<User?>>(adminSessionProvider, (
      AsyncValue<User?>? previous,
      AsyncValue<User?> next,
    ) {
      if (_exiting || !next.hasValue || next.value != null) {
        return;
      }
      _exiting = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminLoginPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    _handleSession();
    final ThemeData theme = Theme.of(context);
    final bool busy = _publishing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Publier une nouveauté'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: busy
                ? null
                : () async {
                    await ref.read(adminAuthServiceProvider).signOut();
                  },
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: busy,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    DropdownButtonFormField<String>(
                      initialValue: _artistId,
                      decoration: const InputDecoration(
                        labelText: 'Artiste cible',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: <DropdownMenuItem<String>>[
                        for (final AdminArtistOption artist in _artists)
                          DropdownMenuItem<String>(
                            value: artist.id,
                            child: Text('${artist.name} (${artist.id})'),
                          ),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() => _artistId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Titre du morceau',
                        prefixIcon: Icon(Icons.music_note_outlined),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (String? value) =>
                          (value?.trim().isEmpty ?? true)
                          ? 'Saisissez le titre du morceau.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _trackId,
                      decoration: const InputDecoration(
                        labelText: 'Identifiant de la piste',
                        helperText:
                            'Slug unique, base du nom de fichier et du document '
                            '(ex. summer-remix).',
                        prefixIcon: Icon(Icons.tag),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (String? value) {
                        final String text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return 'Saisissez un identifiant.';
                        }
                        if (!RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(text)) {
                          return 'Lettres minuscules, chiffres, tirets uniquement.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _album,
                            decoration: const InputDecoration(
                              labelText: 'Album (facultatif)',
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _trackNumber,
                            decoration: const InputDecoration(
                              labelText: 'N° de piste',
                            ),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            validator: _optionalPositiveInt,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _year,
                            decoration: const InputDecoration(
                              labelText: 'Année',
                            ),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            validator: _optionalYear,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _FilePickers(
                      audioFile: _audioFile,
                      coverFile: _coverFile,
                      onPickAudio: _pickAudio,
                      onPickCover: _pickCover,
                      onClearAudio: () => setState(() => _audioFile = null),
                      onClearCover: () => setState(() => _coverFile = null),
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null) ...<Widget>[
                      _ErrorBanner(message: _errorMessage!),
                      const SizedBox(height: 16),
                    ],
                    if (busy) ...<Widget>[
                      Row(
                        children: <Widget>[
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              value: _progress > 0 ? _progress / 100 : null,
                              strokeWidth: 2.5,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Téléversement… $_progress %',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: _progress / 100),
                      const SizedBox(height: 16),
                    ],
                    FilledButton.icon(
                      onPressed: busy ? null : _publish,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Publier la nouveauté'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Le MP3 part vers artists/$_artistId/audio/, la pochette '
                      'vers artists/$_artistId/covers/, et le document est '
                      'créé dans la collection « tracks » avec is_new: true.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Validation d'un nombre entier strictement positif, champ facultatif.
  static String? _optionalPositiveInt(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final int? number = int.tryParse(text);
    if (number == null || number <= 0) {
      return 'Nombre invalide.';
    }
    return null;
  }

  /// Validation d'une année à quatre chiffres, champ facultatif.
  static String? _optionalYear(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    if (int.tryParse(text) == null || text.length != 4) {
      return 'Ex. 2026.';
    }
    return null;
  }
}

/// Zone de sélection des fichiers : MP3 (obligatoire) et pochette (facultative).
class _FilePickers extends StatelessWidget {
  const _FilePickers({
    required this.audioFile,
    required this.coverFile,
    required this.onPickAudio,
    required this.onPickCover,
    required this.onClearAudio,
    required this.onClearCover,
  });

  final PlatformFile? audioFile;
  final PlatformFile? coverFile;
  final VoidCallback onPickAudio;
  final VoidCallback onPickCover;
  final VoidCallback onClearAudio;
  final VoidCallback onClearCover;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _FileTile(
          icon: Icons.audio_file_outlined,
          label: 'MP3 compressé',
          file: audioFile,
          mandatory: true,
          onPick: onPickAudio,
          onClear: onClearAudio,
        ),
        const SizedBox(height: 12),
        _FileTile(
          icon: Icons.image_outlined,
          label: 'Pochette',
          file: coverFile,
          mandatory: false,
          onPick: onPickCover,
          onClear: onClearCover,
        ),
      ],
    );
  }
}

/// Ligne « fichier choisi » : bouton de sélection, libellé et retrait.
class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.icon,
    required this.label,
    required this.file,
    required this.mandatory,
    required this.onPick,
    required this.onClear,
  });

  final IconData icon;
  final String label;
  final PlatformFile? file;
  final bool mandatory;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final PlatformFile? selected = file;
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: Icon(icon),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                selected == null
                    ? '$label — aucun fichier sélectionné'
                    : '$label — ${selected.name} '
                        '(${ByteFormatter.format(selected.size)})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              side: BorderSide(
                color: mandatory && selected == null
                    ? colors.error
                    : colors.outline,
              ),
            ),
          ),
        ),
        if (selected != null) ...<Widget>[
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Retirer',
            icon: const Icon(Icons.close),
            onPressed: onClear,
          ),
        ],
      ],
    );
  }
}

/// Bandeau d'erreur compact, aligné sur celui de l'écran de connexion.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
