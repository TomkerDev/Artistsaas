import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../services/supabase_storage_service.dart';
import 'admin_routes.dart';

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
  // La liste centralisée des 12 artistes provient de `admin_routes.dart`
  // (constante `allAdminArtists` / classe `AdminArtistOption`), évitant ainsi
  // la duplication entre le panneau d'upload et les flavors Android.

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _album = TextEditingController();
  final TextEditingController _durationMs = TextEditingController();

  late String _selectedArtistId;
  String? _userId;
  String? _userRole;
  String? _assignedArtistId;
  String get _modeLabel =>
      _userRole == 'agency_admin' ? 'Administrateur' : 'Artiste';

  Uint8List? _audioBytes;
  String? _audioFileName;
  Uint8List? _coverBytes;
  String? _coverFileName;

  bool _publishing = false;
  int _progress = 0;
  String? _errorMessage;

  /// `true` tant que le document Firestore `admin_users/{uid}` n'a pas
  /// été lu — évite l'affichage du Dropdown avant que le rôle ne soit connu.
  bool _loadingRole = true;

  Stream<QuerySnapshot<Map<String, dynamic>>> _tracksStream() {
    if (_loadingRole || FirebaseAuth.instance.currentUser == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    final bool allArtists =
        _userRole == 'agency_admin' && _assignedArtistId == 'all';
    final Query<Map<String, dynamic>> query = allArtists
        ? FirebaseFirestore.instance.collection('tracks')
        : FirebaseFirestore.instance.collection('tracks').where(
              'artistId',
              isEqualTo: _assignedArtistId != null && _userRole == 'artist'
                  ? _assignedArtistId
                  : _selectedArtistId,
            );
    return query.orderBy('createdAt', descending: true).snapshots();
  }

  @override
  void initState() {
    super.initState();
    _selectedArtistId = allAdminArtists.first.id;
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Non authentifié : rediriger vers la page de connexion.
      _loadingRole = false;
      if (mounted) {
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/admin/login', (route) => false);
          }
        });
      }
      return;
    }

    _userId = user.uid;

    try {
      final DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('admin_users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        _userRole = data['role'] as String? ?? 'artist';
        _assignedArtistId = data['assignedArtistId'] as String? ?? '';
      } else {
        // Aucun document admin : rôle par défaut limité à un artiste.
        _userRole = 'artist';
        _assignedArtistId = '';
      }
    } on FirebaseException {
      // En cas d'erreur, démarre en mode artiste restreint.
      _userRole = 'artist';
      _assignedArtistId = '';
    }

    // Artistes non-admins (sans accès 'all') : verrouiller le sélecteur
    // sur leur artiste assigné (ex: 'dilson_le_mustang').
    if (_userRole != 'agency_admin' &&
        _assignedArtistId != null &&
        _assignedArtistId != 'all') {
      _selectedArtistId = _assignedArtistId!;
    }

    if (mounted) {
      _loadingRole = false;
      setState(() {});
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
      allAdminArtists.firstWhere((a) => a.id == _selectedArtistId).name;

  void _onArtistChanged(String newArtistId) {
    if (newArtistId == _selectedArtistId) return;
    setState(() => _selectedArtistId = newArtistId);
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
    // Rejeter les fichiers audio qui ne sont pas des MP3 (redondant avec
    // allowedExtensions du picker, mais protection côté logique).
    final String audioExt = _audioFileName?.split('.').last.toLowerCase() ?? '';
    if (audioExt != 'mp3') {
      setState(
        () => _errorMessage = 'Format audio non supporté : '
            'uniquement les fichiers .mp3 sont acceptés.',
      );
      return;
    }
    setState(() {
      _publishing = true;
      _progress = 0;
      _errorMessage = null;
    });

    final String title = _title.text.trim();
    final String album =
        _album.text.trim().isEmpty ? 'Single' : _album.text.trim();
    final String trackId =
        '${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${DateTime.now().millisecondsSinceEpoch}';

    String audioPublicUrl = '';
    String? imagePublicUrl;

    // Valider la configuration Supabase avant le premier upload.
    try {
      SupabaseStorageService.ensureInitialized();
    } on StateError catch (initError) {
      if (mounted) {
        setState(() => _errorMessage = initError.message);
      }
      if (mounted) setState(() => _publishing = false);
      return;
    }

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Morceau publié avec succès.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      String message = error.toString();
      // Le message d'erreur Supabase Storage (StateError) contient déjà une
      // explication détaillée (causes possibles, code 403, …) grâce à
      // [SupabaseStorageService._wrapStorageError].
      if (mounted) {
        setState(() => _errorMessage = message);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade700,
          ),
        );
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
        title: const Text(AppStrings.deleteConfirmTitle),
        content: const Text(AppStrings.deleteFirestoreTrackMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.deleteAction),
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
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Morceau supprimé.')),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = 'Échec de la suppression : $error');
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
            onPressed: () => Navigator.of(context).pushNamed('/admin/store'),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Boutique & Show'),
          ),
          TextButton.icon(
            onPressed: () async {
              final NavigatorState navigator = Navigator.of(context);
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              await navigator.pushReplacementNamed('/admin/login');
            },
            icon: const Icon(Icons.logout, color: Colors.white70),
            label: const Text(
              'Déconnexion',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.surface, colors.surface.withValues(alpha: 0.03)],
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
                          _buildKpiSection(colors),
                          const SizedBox(height: 24),
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
                            label: Text(
                              _publishing
                                  ? 'Publication\u2026'
                                  : 'Publier sur Supabase & Firestore',
                            ),
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
                              valueColor: AlwaysStoppedAnimation(
                                colors.primary,
                              ),
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
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _tracksStream(),
                            builder: (
                              BuildContext context,
                              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                                  snapshot,
                            ) {
                              final List<Map<String, dynamic>> tracks =
                                  snapshot.data?.docs
                                          .map(
                                            (
                                              QueryDocumentSnapshot<
                                                      Map<String, dynamic>>
                                                  doc,
                                            ) =>
                                                doc.data(),
                                          )
                                          .toList(growable: false) ??
                                      const <Map<String, dynamic>>[];
                              return _TrackList(
                                tracks: tracks,
                                artistId: _selectedArtistId,
                                onDelete: _deleteTrack,
                              );
                            },
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

  /// Section KPI — affiche 4 cartes de statistiques en temps réel.
  ///
  /// Écoute la collection Firestore `tracks` via un [StreamBuilder] :
  /// - Si le rôle est `agency_admin` et `assignedArtistId == 'all'`,
  ///   la requête couvre tous les morceaux de tous les artistes.
  /// - Sinon, la requête est filtrée par `artistId == _selectedArtistId`.
  ///
  /// Pendant le chargement initial du rôle utilisateur ou du premier
  /// snapshot Firestore, un squelette de chargement est affiché.
  Widget _buildKpiSection(ColorScheme colors) {
    if (_loadingRole) {
      return _kpiLoadingSkeleton(colors);
    }

    final bool isFullAdmin =
        _userRole == 'agency_admin' && _assignedArtistId == 'all';

    final Query<Map<String, dynamic>> query = isFullAdmin
        ? FirebaseFirestore.instance.collection('tracks')
        : FirebaseFirestore.instance
            .collection('tracks')
            .where('artistId', isEqualTo: _selectedArtistId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _kpiLoadingSkeleton(colors);
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data!.docs;
        final _KpiData kpiData = _computeKpis(
          docs,
          isFullAdmin,
          _artistName,
        );

        return _KpiGrid(kpiData: kpiData, colors: colors);
      },
    );
  }

  /// Calcule les indicateurs clés à partir d'une liste de documents `tracks`.
  ///
  /// - [totalTracks] : nombre total de documents.
  /// - [totalAlbums] : nombre d'albums/singles distincts (les chaînes vides
  ///   sont comptées comme `'Single'`).
  /// - [totalArtists] : nombre d'artistes distincts, ou `-1` si l'utilisateur
  ///   n'est pas admin agence global (auquel cas la carte affiche le nom de
  ///   l'artiste au lieu d'un total).
  /// - [lastTrackTitle] / [lastTrackDate] : titre et date du morceau dont
  ///   le champ `createdAt` est le plus récent.
  _KpiData _computeKpis(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    bool isFullAdmin,
    String artistName,
  ) {
    final int totalTracks = docs.length;
    final Set<String> albums = <String>{};
    final Set<String> artistIds = <String>{};

    QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;
    DateTime? lastDate;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final Map<String, dynamic> data = doc.data();

      final String? album = data['album'] as String?;
      final String albumKey =
          album != null && album.trim().isNotEmpty ? album.trim() : 'Single';
      albums.add(albumKey);

      final String? artistId = data['artistId'] as String?;
      if (artistId != null && artistId.isNotEmpty) {
        artistIds.add(artistId);
      }

      final Object? createdAt = data['createdAt'];
      if (createdAt is Timestamp) {
        final DateTime date = createdAt.toDate();
        if (lastDate == null || date.isAfter(lastDate)) {
          lastDate = date;
          lastDoc = doc;
        }
      }
    }

    final String lastTrackTitle =
        lastDoc?.data()['title'] as String? ?? 'Aucun morceau';

    return _KpiData(
      totalTracks: totalTracks,
      totalAlbums: albums.length,
      totalArtists: isFullAdmin ? artistIds.length : -1,
      artistName: artistName,
      lastTrackTitle: lastTrackTitle,
      lastTrackDate: lastDate != null ? _formatDate(lastDate) : null,
    );
  }

  /// Squelette de chargement affiché pendant l'attente du premier snapshot
  /// Firestore ou pendant le chargement du rôle utilisateur.
  /// Affiche 4 conteneurs rectangles gris clair avec un indicateur
  /// circulaire centré, correspondant à la disposition des 4 cartes KPI.
  Widget _kpiLoadingSkeleton(ColorScheme colors) {
    return SizedBox(
      height: 120,
      child: Row(
        children: List<Widget>.generate(4, (int i) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(
                left: i > 0 ? 8 : 0,
                right: i < 3 ? 8 : 0,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final String day = dt.day.toString().padLeft(2, '0');
    final String month = dt.month.toString().padLeft(2, '0');
    final String year = dt.year.toString();
    return '$day/$month/$year';
  }

  Widget _buildArtistSelector(ColorScheme colors) {
    // Pendant le chargement du rôle utilisateur, on affiche un indicateur
    // de progression au lieu du Dropdown pour éviter tout clignotement.
    if (_loadingRole) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      );
    }

    // Le Dropdown est activé pour les admins ou les comptes avec accès
    // global ('all'), sinon il reste verrouillé sur l'artiste assigné.
    final bool canChooseArtist =
        _userRole == 'agency_admin' || _assignedArtistId == 'all';
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
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          if (canChooseArtist)
            Expanded(
              child: _ArtistDropdown(
                artists: allAdminArtists,
                selectedId: _selectedArtistId,
                onChanged: _onArtistChanged,
                disabled: false,
              ),
            )
          else
            Expanded(
              child: _ArtistDropdown(
                artists: allAdminArtists,
                selectedId: _selectedArtistId,
                onChanged: (_) {},
                disabled: true,
              ),
            ),
          const SizedBox(width: 8),
          Icon(
            canChooseArtist ? Icons.admin_panel_settings : Icons.lock_outline,
            color: canChooseArtist ? colors.primary : colors.onSurfaceVariant,
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

class _ArtistDropdown extends StatelessWidget {
  const _ArtistDropdown({
    required this.artists,
    required this.selectedId,
    required this.onChanged,
    required this.disabled,
  });

  final List<AdminArtistOption> artists;
  final String selectedId;
  final ValueChanged<String> onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color:
              disabled ? colors.outline.withValues(alpha: 0.3) : colors.outline,
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
            style: TextStyle(color: colors.onSurface.withValues(alpha: 0.5)),
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
                    Icon(Icons.check_circle, size: 16, color: colors.primary)
                  else
                    Icon(
                      Icons.circle_outlined,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
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
        final String? imageUrl = track['cover_url'] as String?;
        final Timestamp? createdAt = track['createdAt'] as Timestamp?;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outline.withValues(alpha: 0.15)),
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
                    errorBuilder: (BuildContext context, Object error,
                            StackTrace? stackTrace) =>
                        _buildPlaceholder(colors),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant
                                  .withValues(alpha: 0.6),
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== KPI WIDGETS =====

/// Données calculées pour la section KPI.
///
/// `totalArtists` vaut `-1` quand l'utilisateur n'est pas un admin agence
/// global — la carte affichera alors le [artistName] au lieu d'un total.
class _KpiData {
  const _KpiData({
    required this.totalTracks,
    required this.totalAlbums,
    required this.totalArtists,
    required this.artistName,
    required this.lastTrackTitle,
    this.lastTrackDate,
  });

  final int totalTracks;
  final int totalAlbums;
  final int totalArtists;
  final String artistName;
  final String lastTrackTitle;
  final String? lastTrackDate;
}

/// Paramètres d'affichage pour une carte KPI individuelle.
class _StatCardData {
  const _StatCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
}

/// Grille responsive de 4 cartes KPI.
///
/// Utilise [LayoutBuilder] + [Wrap] pour passer automatiquement d'une rangée
/// de 4 cartes (web/PC, largeur > 600 px) à une grille 2×2 (mobile).
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpiData, required this.colors});

  final _KpiData kpiData;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final List<_StatCardData> cards = <_StatCardData>[
      _StatCardData(
        title: 'Titres en ligne',
        value: kpiData.totalTracks.toString(),
        icon: Icons.music_note,
        color: const Color(0xFF8E44F0),
      ),
      _StatCardData(
        title: 'Albums & Singles',
        value: kpiData.totalAlbums.toString(),
        icon: Icons.album,
        color: const Color(0xFF3B82F6),
      ),
      _StatCardData(
        title: kpiData.totalArtists >= 0 ? 'Total Artistes' : 'Artiste',
        value: kpiData.totalArtists >= 0
            ? kpiData.totalArtists.toString()
            : kpiData.artistName,
        icon: Icons.mic,
        color: const Color(0xFF10B981),
      ),
      _StatCardData(
        title: 'Dernier Ajout',
        value: kpiData.lastTrackTitle,
        subtitle: kpiData.lastTrackDate,
        icon: Icons.history,
        color: colors.onSurfaceVariant.withValues(alpha: 0.7),
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth > 600;
        const double spacing = 12;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.asMap().entries.map((
            MapEntry<int, _StatCardData> entry,
          ) {
            final _StatCardData card = entry.value;
            final double cardWidth = isWide
                ? (constraints.maxWidth - 3 * spacing) / 4
                : (constraints.maxWidth - spacing) / 2;
            return SizedBox(
              width: cardWidth,
              child: _StatCard(
                title: card.title,
                value: card.value,
                subtitle: card.subtitle,
                icon: card.icon,
                color: card.color,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Carte visuelle d'un indicateur KPI.
///
/// Fond sombre ([ColorScheme.surface]), bordure fine ([ColorScheme.outline]),
/// ombre légère (`elevation: 2`). Contient une icône colorée, un titre court
/// et une valeur principale. Un [subtitle] optionnel peut compléter la valeur.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.surface,
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
