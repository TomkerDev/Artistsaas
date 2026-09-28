import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/constants/artist_config.dart';
import 'admin_routes.dart';
import 'admin_upload_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Row(
          children: <Widget>[
            NavigationRail(
              selectedIndex: _index,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (int value) =>
                  setState(() => _index = value),
              destinations: const <NavigationRailDestination>[
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music),
                  label: Text('Catalogue & Upload'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront),
                  label: Text('Boutique & Shows'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Profil Artiste'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Paramètres'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: <Widget>[
                  const _DashboardView(),
                  const AdminUploadPage(),
                  const StoreAdminPage(),
                  const _ProfileView(),
                  const _SettingsView(),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Tableau de bord : statistiques de catalogue et d'écoute par artiste.
///
/// Les compteurs sont lus en direct depuis Firestore. Un champ de lecture
/// absent n'est pas une erreur : la carte affiche « — » plutôt que « 0 ».
class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  /// Artiste filtré ; `null` = tous les artistes.
  String? _artistId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: <Widget>[
          if (FirebaseAuth.instance.currentUser != null)
            IconButton(
              tooltip: 'Déconnexion',
              icon: const Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut(),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                for (final AdminArtistOption option in adminArtistOptions)
                  ChoiceChip(
                    label: Text(option.name),
                    selected: _artistId == option.id,
                    onSelected: (bool selected) => setState(
                      () => _artistId = selected ? option.id : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(child: _DashboardStats(artistId: _artistId)),
          ],
        ),
      ),
    );
  }
}

/// Agrégats de catalogue et d'écoute pour le filtre artiste choisi.
class _DashboardStats extends StatelessWidget {
  const _DashboardStats({required this.artistId});

  /// Filtre appliqué ; `null` agrège tous les artistes.
  final String? artistId;

  /// Flux Firestore correspondant au filtre.
  ///
  /// Sans filtre, la collection est lue telle quelle ; avec un filtre, la
  /// requête reste sur le seul champ `artistId` (index simple), afin de ne pas
  /// dépendre d'un index composite.
  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    final CollectionReference<Map<String, dynamic>> tracks =
        FirebaseFirestore.instance.collection('tracks');
    if (artistId == null) {
      return tracks.snapshots();
    }
    return tracks.where('artistId', isEqualTo: artistId).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('Statistiques indisponibles.'));
        }

        final _Stats stats = _Stats.from(snapshot.data!.docs, artistId);

        return ListView(
          children: <Widget>[
            _StatTile(
              icon: Icons.library_music,
              title: 'Morceaux publiés',
              value: '${stats.tracks}',
            ),
            _StatTile(
              icon: Icons.album,
              title: 'Albums & Singles',
              value: '${stats.albums}',
            ),
            _StatTile(
              icon: Icons.record_voice_over,
              title: 'Écoutes cumulées',
              value: stats.plays == null ? '—' : '${stats.plays}',
            ),
            _StatTile(
              icon: Icons.audio_file,
              title: 'Fichiers audio',
              value: '${stats.files}',
            ),
          ],
        );
      },
    );
  }
}

/// Agrégats de catalogue et d'écoute, calculés côté client.
final class _Stats {
  const _Stats({
    required this.tracks,
    required this.albums,
    required this.files,
    required this.plays,
  });

  /// Nombre de morceaux publiés.
  final int tracks;

  /// Nombre d'albums/singles distincts.
  final int albums;

  /// Nombre de documents porteurs d'une URL audio.
  final int files;

  /// Total des écoutes ; `null` si aucun champ de comptage n'est renseigné.
  final int? plays;

  factory _Stats.from(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String? artistId,
  ) {
    final Set<String> albums = <String>{};
    int tracks = 0;
    int files = 0;
    int plays = 0;
    bool playsKnown = false;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final Map<String, dynamic> data = doc.data();

      // Sans filtre, les documents reçus sont déjà ceux de tous les artistes.
      if (artistId != null && data['artistId'] != artistId) {
        continue;
      }
      tracks++;

      final String? album = data['album'] as String?;
      albums.add(
        album != null && album.trim().isNotEmpty ? album.trim() : 'Single',
      );

      // `audioUrl` (schéma courant) et `audio_url` (documents historiques).
      final Object? audioUrl = data['audioUrl'] ?? data['audio_url'];
      if (audioUrl is String && audioUrl.isNotEmpty) {
        files++;
      }

      final Object? count = data['plays'] ?? data['play_count'];
      if (count is num) {
        plays += count.toInt();
        playsKnown = true;
      }
    }

    return _Stats(
      tracks: tracks,
      albums: albums.length,
      files: files,
      plays: playsKnown ? plays : null,
    );
  }
}

/// Ligne de statistique du tableau de bord.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        trailing: Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Édition de la fiche artiste (biographie, label, distinction).
///
/// L'artiste par défaut est celui du registre, mais l'administrateur peut en
/// choisir un autre : la fiche est écrite dans `artist_profiles/{artistId}`,
/// ce qui permet de renseigner Jethsonat comme Dilson sans changer de code.
class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  /// Artistes publiés, repris du registre central.
  late final List<AdminArtistOption> _artists = adminArtistOptions;

  late String _artistId = _artists.first.id;
  final TextEditingController _bio = TextEditingController();
  final TextEditingController _distinction = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFromRegistry();
  }

  /// Pré-remplit les champs depuis le registre central des artistes, afin que
  /// la fiche éditable soit amorcée avec la biographie officielle.
  void _loadFromRegistry() {
    final ArtistProfile? profile = artistProfileFor(_artistId);
    _bio.text = profile?.biography ?? '';
    _distinction.text = profile?.distinction ?? '';
  }

  @override
  void dispose() {
    _bio.dispose();
    _distinction.dispose();
    super.dispose();
  }

  void _onArtistChanged(String? artistId) {
    if (artistId == null || artistId == _artistId) {
      return;
    }
    setState(() {
      _artistId = artistId;
      _loadFromRegistry();
    });
  }

  Future<void> _save() async {
    final ArtistProfile? profile = artistProfileFor(_artistId);
    await FirebaseFirestore.instance
        .collection('artist_profiles')
        .doc(_artistId)
        .set(<String, Object?>{
      'artistId': _artistId,
      'name': profile?.stageName ?? adminArtistName(_artistId),
      'label': profile?.label ?? 'Tete Roh Studio',
      'biography': _bio.text.trim(),
      'distinction': _distinction.text.trim(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profil enregistré.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Profil Artiste')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            DropdownButtonFormField<String>(
              initialValue: _artistId,
              decoration: const InputDecoration(labelText: 'Artiste'),
              items: <DropdownMenuItem<String>>[
                for (final AdminArtistOption option in _artists)
                  DropdownMenuItem<String>(
                    value: option.id,
                    child: Text('${option.name} — ${option.label}'),
                  ),
              ],
              onChanged: _onArtistChanged,
            ),
            const SizedBox(height: 20),
            const Text(
              'Biographie',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bio,
              maxLines: 8,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text(
              'Distinction / Nomination',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _distinction,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                helperText:
                    'Ex. : nomination officielle au Festival SICA 2026, Cotonou.',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: const Text('Enregistrer le profil'),
            ),
          ],
        ),
      );
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Paramètres')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            const ListTile(
              leading: Icon(Icons.shield_outlined),
              title: Text('Rôles utilisateurs'),
              subtitle: Text(
                'Gérez les rôles artist et agency_admin dans Firestore.',
              ),
              trailing: Icon(Icons.chevron_right),
            ),
            const ListTile(
              leading: Icon(Icons.cloud_outlined),
              title: Text('Configuration Firestore / Supabase'),
              subtitle: Text(
                'Les paramètres sont fournis au build via dart-define.',
              ),
              trailing: Icon(Icons.chevron_right),
            ),
          ],
        ),
      );
}

class AdminStorePageOnly extends StatelessWidget {
  const AdminStorePageOnly({super.key});
  @override
  Widget build(BuildContext context) => const StoreAdminPage();
}

class StoreAdminPage extends StatelessWidget {
  const StoreAdminPage({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Boutique & Show'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'Événements'),
              Tab(text: 'Articles'),
              Tab(text: 'Billets'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[_EventForm(), _MerchForm(), _TicketList()],
        ),
      ),
    );
  }
}

class _EventForm extends StatefulWidget {
  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _date = TextEditingController();
  final _location = TextEditingController();
  final _std = TextEditingController();
  final _vip = TextEditingController();
  final _money = TextEditingController();
  final _seats = TextEditingController();
  @override
  void dispose() {
    for (final c in [_title, _date, _location, _std, _vip, _money, _seats]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await FirebaseFirestore.instance.collection('events').add(<String, Object?>{
      'title': _title.text.trim(),
      'date': _date.text.trim(),
      'location': _location.text.trim(),
      'price_std': double.parse(_std.text),
      'price_vip': double.parse(_vip.text),
      'mobile_money_number': _money.text.trim(),
      'total_seats': int.parse(_seats.text),
      'created_at': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Événement enregistré.')));
      for (final c in [_title, _date, _location, _std, _vip, _money, _seats]) {
        c.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Titre'),
            ),
            TextFormField(
              controller: _date,
              decoration: const InputDecoration(labelText: 'Date'),
            ),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Lieu'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _std,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Prix standard'),
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _vip,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Prix VIP'),
                  ),
                ),
              ],
            ),
            TextFormField(
              controller: _money,
              decoration:
                  const InputDecoration(labelText: 'Numéro Mobile Money'),
            ),
            TextFormField(
              controller: _seats,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nombre de places'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: const Text('Enregistrer l’événement'),
            ),
          ],
        ),
      );
}

class _MerchForm extends StatefulWidget {
  @override
  State<_MerchForm> createState() => _MerchFormState();
}

class _MerchFormState extends State<_MerchForm> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _image = TextEditingController();
  final _sizes = TextEditingController(text: 'S,M,L,XL');
  final _whatsapp = TextEditingController();
  @override
  void dispose() {
    for (final c in [_name, _price, _image, _sizes, _whatsapp]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    await FirebaseFirestore.instance.collection('merch').add(<String, Object?>{
      'name': _name.text.trim(),
      'price_fcfa': double.parse(_price.text),
      'image_url': _image.text.trim(),
      'sizes': _sizes.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'whatsapp_contact': _whatsapp.text.trim(),
      'created_at': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Article enregistré.')));
      for (final c in [_name, _price, _image, _sizes, _whatsapp]) {
        c.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nom'),
          ),
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Prix FCFA'),
          ),
          TextField(
            controller: _image,
            decoration: const InputDecoration(labelText: 'URL image'),
          ),
          TextField(
            controller: _sizes,
            decoration: const InputDecoration(
              labelText: 'Tailles séparées par des virgules',
            ),
          ),
          TextField(
            controller: _whatsapp,
            decoration: const InputDecoration(labelText: 'Contact WhatsApp'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: const Text('Enregistrer l’article'),
          ),
        ],
      );
}

class _TicketList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tickets')
          .orderBy('status')
          .snapshots(),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (BuildContext context, int index) {
            final QueryDocumentSnapshot<DocumentSnapshot> doc = snapshot
                .data!.docs[index] as QueryDocumentSnapshot<DocumentSnapshot>;
            final Map<String, dynamic> data =
                doc.data() as Map<String, dynamic>;
            final bool confirmed = data['status'] == 'confirmed';
            return ListTile(
              title: Text(data['event_id'] as String? ?? ''),
              subtitle: Text('${data['ticket_type']} · ${data['status']}'),
              trailing: confirmed
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : IconButton(
                      icon: const Icon(Icons.verified),
                      tooltip: 'Valider le paiement',
                      onPressed: () => doc.reference.update(<String, Object?>{
                        'status': 'confirmed',
                      }),
                    ),
            );
          },
        );
      },
    );
  }
}
