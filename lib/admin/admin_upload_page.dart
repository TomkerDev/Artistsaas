import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../services/supabase_storage_service.dart';

/// Panneau de publication multi-artistes (Flutter Web).
///
/// Stockage des médias : Supabase Storage (bucket `artist-media`).
/// Métadonnées : Cloud Firestore (collection `tracks`).
class AdminUploadPage extends ConsumerStatefulWidget {
  const AdminUploadPage({super.key});

  @override
  ConsumerState<AdminUploadPage> createState() => _AdminUploadPageState();
}

class _AdminUploadPageState extends ConsumerState<AdminUploadPage> {
  static const List<_ArtistOption> _allArtists = [
    _ArtistOption(id: 'dilson_le_mustang', name: 'Dilson Le Mustang'),
    _ArtistOption(id: 'jethsonat', name: 'Jethsonat'),
    _ArtistOption(id: 'artist_1', name: 'Artist 1'),
    _ArtistOption(id: 'artist_2', name: 'Artist 2'),
    _ArtistOption(id: 'artist_3', name: 'Artist 3'),
    _ArtistOption(id: 'artist_4', name: 'Artist 4'),
    _ArtistOption(id: 'artist_5', name: 'Artist 5'),
    _ArtistOption(id: 'artist_6', name: 'Artist 6'),
    _ArtistOption(id: 'artist_7', name: 'Artist 7'),
    _ArtistOption(id: 'artist_8', name: 'Artist 8'),
    _ArtistOption(id: 'artist_9', name: 'Artist 9'),
    _ArtistOption(id: 'artist_10', name: 'Artist 10'),
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _album = TextEditingController();
  final TextEditingController _durationMs = TextEditingController();

  late String _selectedArtistId;
  String? _userId;
  String? _userRole;
  String get _modeLabel => _userRole == 'agency_admin' ? 'Administrateur' : 'Artiste';

  Uint8List? _audioBytes;
  String? _audioFileName;
  Uint8List? _coverBytes;
  String? _coverFileName;

  bool _publishing = false;
  int _progress = 0;
  String? _errorMessage;

  final List<Map<String, dynamic>> _tracks = [];

  @override
  void initState() {
    super.initState();
    _selectedArtistId = _allArtists.first.id;
    _listenToTracks();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
        // Le rôle peut être stocké dans les custom claims ou dans Firestore
        // Pour simplifier, on utilise un rôle par défaut
        _userRole = 'artist';
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _album.dispose();
    _durationMs.dispose();
    super.dispose();
  }

  String get _artistName =>
      _allArtists.firstWhere((a) => a.id == _selectedArtistId).name;

  Future<void> _listenToTracks() async {
    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('tracks')
        .where('artistId', isEqualTo: _selectedArtistId)
        .orderBy('createdAt', descending: true)
        .get();
    setState(() {
      _tracks.clear();
      for (final doc in snapshot.docs) {
        _tracks.add(doc.data() as Map<String, dynamic>);
      }
    });
  }

  void _onArtistChanged(String newArtistId) {
    if (newArtistId == _selectedArtistId) return;
    setState(() => _selectedArtistId = newArtistId);
    _listenToTracks();
  }

  Future<void> _pickAudio() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final PlatformFile file = result.files.single;
    if (file.bytes == null) return;
    setState(() {
      _audioBytes = file.bytes;
      _audioFileName = file.name;
    });
  }

  Future<void> _pickCover() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final PlatformFile file = result.files.single;
    if (file.bytes == null) return;
    setState(() {
      _coverBytes = file.bytes;
      _coverFileName = file.name;
    });
  }

  Future<void> _clearAudio() async {
    setState(() {
      _audioBytes = null;
      _audioFileName = null;
    });
  }

  Future<void> _clearCover() async {
    setState(() {
      _coverBytes = null;
      _coverFileName = null;
    });
  }


  Future<void> _publish() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_audioBytes == null) {
      setState(() => _errorMessage = 'Sélectionnez un fichier MP3.');
      return;
    }
    setState(() {
      _publishing = true;
      _progress = 0;
      _errorMessage = null;
    });

    final String title = _title.text.trim();
    final String album = _album.text.trim();
    final String trackId = title.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]+'), '_') +
        '_' +
        DateTime.now().millisecondsSinceEpoch.toString();

    String audioPublicUrl = '';
    String? imagePublicUrl;

    try {
      // Étape A : MP3 sur Supabase Storage
      audioPublicUrl = await SupabaseStorageService.uploadMedia(
        artistId: _selectedArtistId,
        fileName: '$trackId.mp3',
        bytes: _audioBytes!,
      );
      if (mounted) setState(() => _progress = 40);

      // Étape B : pochette JPG sur Supabase Storage
      if (_coverBytes != null) {
        final String ext =
            _coverFileName?.split('.').last.toLowerCase() ?? 'jpg';
        imagePublicUrl = await SupabaseStorageService.uploadMedia(
          artistId: _selectedArtistId,
          fileName: '$trackId.$ext',
          bytes: _coverBytes!,
        );
      }

      // Étape C : document Firestore 'tracks'
      final String documentId = trackId;
      await FirebaseFirestore.instance.collection('tracks').add({
        'id': documentId,
        'artistId': _selectedArtistId,
        'artist': _artistName,
        'title': title,
        'album': album,
        'duration_ms': int.parse(_durationMs.text.trim()),
        'audio_url': audioPublicUrl,
        'cover_url': imagePublicUrl,
        'is_new': true,
        'is_downloadable': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) setState(() => _progress = 100);
      _clearForm();
      await _listenToTracks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Morceau publié avec succès.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage =
            'Erreur lors de la publication : $error');
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _clearForm() {
    _title.clear();
    _album.clear();
    _audioBytes = null;
    _audioFileName = null;
    _coverBytes = null;
    _coverFileName = null;
  }

  Future<void> _deleteTrack(String trackId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce morceau ?'),
        content: const Text(
          'Cette action supprimera le document Firestore. '
          'Les fichiers Supabase resteront dans le bucket.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('tracks')
          .where('artistId', isEqualTo: _selectedArtistId)
          .where('title', isEqualTo: trackId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return;
      await snapshot.docs.first.reference.delete();
      if (mounted) {
        await _listenToTracks();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Morceau supprimé.')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage =
            'Échec de la suppression : $error');
      }
    }
  }

  String _formatBytes(Uint8List bytes) {
    final int size = bytes.length;
    if (size < 1024) return '$size o';
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} Ko';
    }
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.primaryContainer,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _modeLabel,
                style: TextStyle(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'UID: $_userId',
              style: TextStyle(
                color: colors.onPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/admin/login');
              }
            },
            icon: const Icon(Icons.logout, color: Colors.white70),
            label: const Text('Déconnexion', style: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.surface,
              colors.surface.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildArtistSelector(colors),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader(
                            colors,
                            'Informations du morceau',
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _title,
                            decoration: InputDecoration(
                              labelText: 'Titre du morceau *',
                              prefixIcon: const Icon(Icons.music_note),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Le titre est obligatoire.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _album,
                            decoration: InputDecoration(
                              labelText: 'Album / Single *',
                              prefixIcon: const Icon(Icons.library_music),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'L\'album est obligatoire.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _durationMs,
                            decoration: InputDecoration(
                              labelText: 'Durée (ms) *',
                              prefixIcon: const Icon(Icons.timer_outlined),
                              hintText: 'Ex: 180000 pour 3 min',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'La durée est obligatoire.';
                              }
                              final ms = int.tryParse(value!);
                              if (ms == null || ms <= 0) {
                                return 'Durée invalide (en millisecondes).';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),
                          _buildSectionHeader(colors, 'Fichiers à téléverser'),
                          const SizedBox(height: 12),
                          _FileTile(
                            icon: Icons.audio_file_outlined,
                            label: 'MP3 compressé',
                            bytes: _audioBytes,
                            fileName: _audioFileName,
                            mandatory: true,
                            onPick: _pickAudio,
                            onClear: _clearAudio,
                            formatBytes: _formatBytes,
                          ),
                          const SizedBox(height: 12),
                          _FileTile(
                            icon: Icons.image_outlined,
                            label: 'Pochette (JPG)',
                            bytes: _coverBytes,
                            fileName: _coverFileName,
                            mandatory: false,
                            onPick: _pickCover,
                            onClear: _clearCover,
                            formatBytes: _formatBytes,
                          ),
                          const SizedBox(height: 24),
                          if (_errorMessage != null) ...[
                            _ErrorBanner(message: _errorMessage!),
                            const SizedBox(height: 12),
                          ],
                          FilledButton.icon(
                            onPressed: _publishing ? null : _publish,
                            icon: _publishing
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.cloud_upload),
                            label: Text(_publishing ? 'Publication\u2026' : 'Publier sur Supabase & Firestore'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_publishing) ...[
                            LinearProgressIndicator(
                              value: _progress / 100,
                              backgroundColor: colors.primaryContainer,
                              valueColor: AlwaysStoppedAnimation(colors.primary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Progression : $_progress%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const Divider(height: 32),
                          _buildSectionHeader(colors, 'Morceaux publiés'),
                          const SizedBox(height: 12),
                          _TrackList(
                            tracks: _tracks,
                            artistId: _selectedArtistId,
                            onDelete: _deleteTrack,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildArtistSelector(ColorScheme colors) {
    final bool isAgencyAdmin = _userRole == 'agency_admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Artiste cible :',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
          const SizedBox(width: 12),
          if (isAgencyAdmin)
            Expanded(
              child: _ArtistDropdown(
                artists: _allArtists,
                selectedId: _selectedArtistId,
                onChanged: _onArtistChanged,
                disabled: false,
              ),
            )
          else
            Expanded(
              child: _ArtistDropdown(
                artists: _allArtists,
                selectedId: _selectedArtistId,
                onChanged: (_) {},
                disabled: true,
              ),
            ),
          const SizedBox(width: 8),
          Icon(
            isAgencyAdmin ? Icons.admin_panel_settings : Icons.lock_outline,
            color: isAgencyAdmin ? colors.primary : colors.onSurfaceVariant,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ColorScheme colors, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _ArtistOption {
  const _ArtistOption({required this.id, required this.name});
  final String id;
  final String name;
}

class _ArtistDropdown extends StatelessWidget {
  const _ArtistDropdown({
    required this.artists,
    required this.selectedId,
    required this.onChanged,
    required this.disabled,
  });

  final List<_ArtistOption> artists;
  final String selectedId;
  final ValueChanged<String> onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: disabled
              ? colors.outline.withValues(alpha: 0.3)
              : colors.outline,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedId,
          isExpanded: true,
          disabledHint: Text(
            _selectedName,
            style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.5)),
          ),
          dropdownColor: colors.surface,
          icon: Icon(
            disabled ? Icons.lock_outline : Icons.arrow_drop_down,
            color: colors.onSurface,
          ),
          items: artists.map((a) {
            return DropdownMenuItem<String>(
              value: a.id,
              child: Row(
                children: [
                  if (a.id == selectedId)
                    Icon(Icons.check_circle,
                        size: 16, color: colors.primary)
                  else
                    Icon(Icons.circle_outlined,
                        size: 16, color: colors.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(a.name),
                ],
              ),
            );
          }).toList(),
          onChanged: disabled
              ? null
              : (value) {
                  if (value != null && value != selectedId) {
                    onChanged(value);
                  }
                },
        ),
      ),
    );
  }

  String get _selectedName =>
      artists.firstWhere((a) => a.id == selectedId).name;
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.icon,
    required this.label,
    this.bytes,
    this.fileName,
    this.mandatory = false,
    required this.onPick,
    required this.onClear,
    required this.formatBytes,
  });

  final IconData icon;
  final String label;
  final Uint8List? bytes;
  final String? fileName;
  final bool mandatory;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final String Function(Uint8List) formatBytes;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bool hasFile = bytes != null;
    return OutlinedButton.icon(
      onPressed: onPick,
      icon: Icon(icon),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          hasFile
              ? '$label \u2014 $fileName (${formatBytes(bytes!)})'
              : '$label \u2014 aucun fichier',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: BorderSide(
          color: mandatory && !hasFile ? colors.error : colors.outline,
          width: mandatory && !hasFile ? 2 : 1,
        ),
      ),
    );
  }
}

class _TrackList extends StatelessWidget {
  const _TrackList({
    required this.tracks,
    required this.artistId,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> tracks;
  final String artistId;
  final Future<void> Function(String) onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (tracks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.music_off_outlined,
              size: 40,
              color: colors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Aucun morceau publié pour cet artiste.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final String title = track['title'] as String? ?? 'Sans titre';
        final String? album = track['album'] as String?;
        final String? imageUrl = track['imageUrl'] as String?;
        final Timestamp? createdAt = track['createdAt'] as Timestamp?;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colors.outline.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(colors),
                  ),
                )
              else
                _buildPlaceholder(colors),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (album != null && album.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        album,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(createdAt.toDate()),
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color:
                                      colors.onSurfaceVariant.withValues(alpha: 0.6),
                                ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Supprimer',
                icon: const Icon(Icons.delete_outline),
                color: colors.error,
                onPressed: () => onDelete(title),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(ColorScheme colors) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.audio_file,
        color: colors.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

