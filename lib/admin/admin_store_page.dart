import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/constants/artist_config.dart';
import '../core/errors/firestore_error_message.dart';
import '../features/store/data/store_admin_service.dart';
import '../features/store/data/store_repository.dart';
import '../features/store/domain/store_models.dart';
import 'admin_dashboard_page.dart';
import 'admin_edit_dialogs.dart';
import 'admin_identity.dart';
import 'admin_routes.dart';
import 'admin_settings_page.dart';
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
                  AdminDashboard(
                    onNavigate: (int value) => setState(() => _index = value),
                  ),
                  const AdminUploadPage(),
                  const StoreAdminPage(),
                  const _ProfileView(),
                  const SettingsScreen(),
                ],
              ),
            ),
          ],
        ),
      );
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

  /// `true` pendant l'écriture du profil Firestore.
  bool _saving = false;

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
    if (_bio.text.trim().isEmpty) {
      _toast('La biographie est obligatoire.');
      return;
    }
    setState(() => _saving = true);
    try {
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
        _toast('Profil enregistré.');
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        _toast('Enregistrement refusé : ${error.message}');
      }
    } catch (error) {
      if (mounted) {
        _toast('Échec de l\'enregistrement : $error');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// Message court affiché dans un [SnackBar] (no-op si démonté).
  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer le profil'),
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

  /// Identité du compte connecté, pour connaître l'artiste de publication.
  final ValueNotifier<AdminIdentity?> _identity = adminIdentityNotifier;

  bool _saving = false;

  /// Flux des concerts publiés pour l'artiste courant.
  ///
  /// `null` tant que l'identité n'est pas résolue : sans artiste connu, la
  /// requête `where('artistId', isEqualTo: null)` listerait les documents sans
  /// artiste — à éviter.
  Stream<List<ShowEvent>>? _eventsStream() {
    final String? artistId = _artistId;
    if (artistId == null) {
      return null;
    }
    return StoreRepository().watchEvents(artistId: artistId);
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _date,
      _location,
      _std,
      _vip,
      _money,
      _seats,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Artiste de publication, ou `null` si aucun n'est résolu.
  ///
  /// Un compte d'artiste est verrouillé sur son `assignedArtistId` ; un compte
  /// d'agence suit l'artiste choisi dans la barre latérale, que le panneau
  /// publie via [shellArtistIdNotifier].
  String? get _artistId {
    final AdminIdentity? identity = _identity.value;
    if (identity == null || !identity.isResolved) {
      return null;
    }
    if (!identity.isAgencyAdmin) {
      return identity.assignedArtistId;
    }
    return shellArtistIdNotifier.value;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    final String? artistId = _artistId;
    if (artistId == null) {
      _toast('Choisissez un artiste avant de publier.');
      return;
    }

    setState(() => _saving = true);
    try {
      await StoreAdminService(FirebaseFirestore.instance).createEvent(
        artistId: artistId,
        title: _title.text,
        // La date est saisie au format ISO ; `date_label` conserve la
        // formulation retenue pour l'affichage.
        date: DateTime.parse(_date.text.trim()),
        dateLabel: _date.text.trim(),
        location: _location.text,
        priceStd: double.parse(_std.text.trim()),
        priceVip: double.parse(_vip.text.trim()),
        mobileMoneyNumber: _money.text,
        totalSeats: int.parse(_seats.text.trim()),
      );
      if (!mounted) {
        return;
      }
      _toast('Événement enregistré.');
      for (final c in [
        _title,
        _date,
        _location,
        _std,
        _vip,
        _money,
        _seats,
      ]) {
        c.clear();
      }
    } on FormatException {
      _toast('Date ou nombre invalide (format de date attendu : 2026-07-18).');
    } on StateError catch (error) {
      _toast(error.message);
    } on FirebaseException catch (error) {
      _toast('Publication refusée : ${error.message}');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            ValueListenableBuilder<AdminIdentity?>(
              valueListenable: _identity,
              builder: (BuildContext context, AdminIdentity? identity, _) =>
                  _ArtistBanner(artistId: _artistId),
            ),
            const SizedBox(height: 12),
            _PublishedList<ShowEvent>(
              title: 'Concerts publiés',
              emptyMessage:
                  'Aucun concert publié pour cet artiste. Les événements '
                  'apparaîtront dans l\'application mobile.',
              stream: _eventsStream(),
              describe: (ShowEvent event) =>
                  '${event.title} · ${event.displayDate}',
              onDelete: (ShowEvent event) =>
                  StoreAdminService(FirebaseFirestore.instance).deleteEvent(
                    event.id,
                  ),
              onEdit: _editEvent,
            ),
            const Divider(height: 32),
            const Text(
              'Nouveau concert',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Titre'),
              validator: _required,
            ),
            TextFormField(
              controller: _date,
              decoration: const InputDecoration(
                labelText: 'Date',
                helperText: 'Format ISO : 2026-07-18',
              ),
              validator: _dateValidator,
            ),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Lieu'),
              validator: _required,
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _std,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Prix standard'),
                    validator: _positiveNumber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _vip,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Prix VIP'),
                    validator: _positiveNumber,
                  ),
                ),
              ],
            ),
            TextFormField(
              controller: _money,
              decoration:
                  const InputDecoration(labelText: 'Numéro Mobile Money'),
              validator: _required,
            ),
            TextFormField(
              controller: _seats,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nombre de places'),
              validator: _positiveNumber,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer l’événement'),
            ),
          ],
        ),
      );

  /// Ouvre le dialogue d'édition puis applique la mise à jour Firestore.
  ///
  /// Le `StreamBuilder` de la liste publiée se rafraîchit tout seul : le
  /// concert modifié réapparaît immédiatement, sans rechargement manuel.
  Future<void> _editEvent(ShowEvent event) async {
    final EventEditResult? result = await showDialog<EventEditResult>(
      context: context,
      builder: (BuildContext dialogContext) => EventEditDialog(event: event),
    );
    if (result == null || !mounted) {
      return;
    }
    try {
      await StoreAdminService(
        FirebaseFirestore.instance,
      ).applyEventEdit(result);
      _toast('Concert mis à jour.');
    } on StateError catch (error) {
      _toast(error.message);
    } on FirebaseException catch (error) {
      _toast('Mise à jour refusée : ${error.message}');
    }
  }

  static String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Champ obligatoire' : null;

  static String? _positiveNumber(String? value) {
    final double? parsed = double.tryParse((value ?? '').trim());
    if (parsed == null || parsed <= 0) {
      return 'Nombre positif attendu';
    }
    return null;
  }

  static String? _dateValidator(String? value) {
    final String raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return 'Champ obligatoire';
    }
    if (DateTime.tryParse(raw) == null) {
      return 'Format attendu : 2026-07-18';
    }
    return null;
  }
}

/// Liste des documents déjà publiés, avec suppression.
///
/// Sans elle, le panneau ne permettrait que de publier : impossible de vérifier ce
/// qui est en ligne, ni de retirer un concert terminé. Les onglets
/// « Événements » et « Articles » affichent donc l'état réel des collections
/// au-dessus du formulaire de création.
///
/// Un [stream] `null` (artiste non résolu) n'affiche rien plutôt qu'une liste
/// potentiellement faussée.
class _PublishedList<T> extends StatelessWidget {
  const _PublishedList({
    required this.title,
    required this.emptyMessage,
    required this.stream,
    required this.describe,
    required this.onDelete,
    this.onEdit,
  });

  final String title;
  final String emptyMessage;
  final Stream<List<T>>? stream;
  final String Function(T item) describe;
  final Future<void> Function(T item) onDelete;

  /// Ouvre le formulaire d'édition pré-rempli pour [item].
  ///
  /// Optionnel : sans callback, seule la suppression reste disponible.
  final Future<void> Function(T item)? onEdit;

  @override
  Widget build(BuildContext context) {
    final Stream<List<T>>? source = stream;
    if (source == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<T>>(
          stream: source,
          builder: (BuildContext context, AsyncSnapshot<List<T>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              );
            }
            if (snapshot.hasError) {
              return Text(
                'Liste indisponible : ${snapshot.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              );
            }
            final List<T> items = snapshot.data ?? <T>[];
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  emptyMessage,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            return Column(
              children: <Widget>[
                for (final T item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(describe(item)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (onEdit != null)
                          IconButton(
                            tooltip: 'Modifier',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => onEdit!(item),
                          ),
                        IconButton(
                          tooltip: 'Supprimer',
                          icon: const Icon(Icons.delete_outline),
                          color: Theme.of(context).colorScheme.error,
                          onPressed: () => _confirmDelete(context, item),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Demande confirmation avant suppression.
  ///
  /// La suppression est définitive et le document disparaît aussitôt de
  /// l'application mobile : une confirmation évite la perte accidentelle.
  Future<void> _confirmDelete(BuildContext context, T item) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Supprimer ?'),
            content: Text('« ${describe(item)} » sera définitivement '
                'retiré de l\'application mobile.'),
            actions: <Widget>[
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
        ) ??
        false;

    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await onDelete(item);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Document supprimé.')));
    } on FirebaseException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suppression refusée : ${error.message}')),
      );
    }
  }
}

/// Bandeau indiquant l'artiste auquel la publication sera rattachée.
///
/// Le `artistId` conditionne la visibilité côté mobile : afficher l'artiste
/// évite qu'un événement ou un article soit publié « dans le vide », donc
/// invisible pour tous.
class _ArtistBanner extends StatelessWidget {
  const _ArtistBanner({required this.artistId});

  final String? artistId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool pending = artistId == null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pending
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            pending ? Icons.error_outline : Icons.album_outlined,
            color: pending
                ? theme.colorScheme.onErrorContainer
                : theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pending
                  ? 'Aucun artiste sélectionné'
                  : 'Publié pour : ${adminArtistName(artistId!)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: pending
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MerchForm extends StatefulWidget {
  @override
  State<_MerchForm> createState() => _MerchFormState();
}

class _MerchFormState extends State<_MerchForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _image = TextEditingController();
  final _sizes = TextEditingController(text: 'S,M,L,XL');
  final _whatsapp = TextEditingController();

  final ValueNotifier<AdminIdentity?> _identity = adminIdentityNotifier;

  bool _saving = false;

  /// Flux des articles publiés pour l'artiste courant.
  ///
  /// Voir [_EventFormState._eventsStream] pour le cas `null`.
  Stream<List<MerchProduct>>? _merchStream() {
    final String? artistId = _artistId;
    if (artistId == null) {
      return null;
    }
    return StoreRepository().watchMerch(artistId: artistId);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _price,
      _image,
      _sizes,
      _whatsapp,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Artiste de publication ; voir [_EventFormState._artistId].
  String? get _artistId {
    final AdminIdentity? identity = _identity.value;
    if (identity == null || !identity.isResolved) {
      return null;
    }
    if (!identity.isAgencyAdmin) {
      return identity.assignedArtistId;
    }
    return shellArtistIdNotifier.value;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    final String? artistId = _artistId;
    if (artistId == null) {
      _toast('Choisissez un artiste avant de publier.');
      return;
    }

    setState(() => _saving = true);
    try {
      await StoreAdminService(FirebaseFirestore.instance).createMerch(
        artistId: artistId,
        name: _name.text,
        description: _description.text,
        priceFcfa: double.parse(_price.text.trim()),
        imageUrl: _image.text,
        whatsappContact: _whatsapp.text,
        sizes: _sizes.text.split(','),
      );
      if (!mounted) {
        return;
      }
      _toast('Article enregistré.');
      for (final c in [
        _name,
        _description,
        _price,
        _image,
        _whatsapp,
      ]) {
        c.clear();
      }
    } on FormatException {
      _toast('Prix invalide : un nombre était attendu.');
    } on StateError catch (error) {
      _toast(error.message);
    } on FirebaseException catch (error) {
      _toast('Publication refusée : ${error.message}');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            ValueListenableBuilder<AdminIdentity?>(
              valueListenable: _identity,
              builder: (BuildContext context, AdminIdentity? identity, _) =>
                  _ArtistBanner(artistId: _artistId),
            ),
            const SizedBox(height: 12),
            _PublishedList<MerchProduct>(
              title: 'Articles publiés',
              emptyMessage:
                  'Aucun article publié pour cet artiste. Le catalogue de la '
                  'boutique reste vide côté mobile.',
              stream: _merchStream(),
              describe: (MerchProduct product) =>
                  '${product.name} · ${product.formattedPrice}',
              onDelete: (MerchProduct product) =>
                  StoreAdminService(FirebaseFirestore.instance).deleteMerch(
                    product.id,
                  ),
              onEdit: _editMerch,
            ),
            const Divider(height: 32),
            const Text(
              'Nouvel article',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nom'),
              validator: _required,
            ),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Description',
                helperText: 'Facultatif',
              ),
            ),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Prix FCFA'),
              validator: _positiveNumber,
            ),
            TextFormField(
              controller: _image,
              decoration: const InputDecoration(
                labelText: 'URL image',
                helperText: 'Facultatif — une icône est utilisée sinon',
              ),
              validator: _optionalUrl,
            ),
            TextFormField(
              controller: _sizes,
              decoration: const InputDecoration(
                labelText: 'Tailles séparées par des virgules',
              ),
            ),
            TextFormField(
              controller: _whatsapp,
              decoration: const InputDecoration(labelText: 'Contact WhatsApp'),
              validator: _required,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer l’article'),
            ),
          ],
        ),
      );

  /// Ouvre le dialogue d'édition puis applique la mise à jour Firestore.
  ///
  /// Voir [_EventFormState._editEvent] : la liste se rafraîchit via son flux.
  Future<void> _editMerch(MerchProduct product) async {
    final MerchEditResult? result = await showDialog<MerchEditResult>(
      context: context,
      builder: (BuildContext dialogContext) =>
          MerchEditDialog(product: product),
    );
    if (result == null || !mounted) {
      return;
    }
    try {
      await StoreAdminService(
        FirebaseFirestore.instance,
      ).applyMerchEdit(result);
      _toast('Article mis à jour.');
    } on StateError catch (error) {
      _toast(error.message);
    } on FirebaseException catch (error) {
      _toast('Mise à jour refusée : ${error.message}');
    }
  }

  static String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Champ obligatoire' : null;

  static String? _positiveNumber(String? value) {
    final double? parsed = double.tryParse((value ?? '').trim());
    if (parsed == null || parsed <= 0) {
      return 'Prix positif attendu';
    }
    return null;
  }

  /// URL facultative : vide si l'article n'a pas d'image.
  static String? _optionalUrl(String? value) {
    final String raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    return RegExp(r'^https?://').hasMatch(raw)
        ? null
        : 'URL invalide (http:// ou https://)';
  }
}

class _TicketList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('tickets')
          .orderBy('status')
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.hasError) {
          return Center(
            child: _FirestoreStreamError(error: snapshot.error),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<StoreTicket> tickets = <StoreTicket>[
          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
              in snapshot.data!.docs)
            StoreTicket.fromFirestore(doc),
        ];
        return ListView.builder(
          itemCount: tickets.length,
          itemBuilder: (BuildContext context, int index) {
            final StoreTicket ticket = tickets[index];
            return ListTile(
              title: Text(ticket.eventId),
              subtitle: Text('${ticket.ticketType} · ${ticket.status}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Modifier',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editTicket(context, ticket),
                  ),
                  if (!ticket.isConfirmed)
                    IconButton(
                      tooltip: 'Valider le paiement',
                      icon: const Icon(Icons.verified),
                      onPressed: () => _confirmTicket(context, ticket.id),
                    )
                  else
                    const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Confirme un billet (statut `confirmed`).
  Future<void> _confirmTicket(BuildContext context, String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(id)
          .update(<String, Object?>{'status': StoreTicket.statusConfirmed});
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Billet confirmé.')),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mise à jour refusée : ${error.message}')),
      );
    }
  }

  /// Ouvre le dialogue d'édition (type / statut) puis applique la mise à jour.
  Future<void> _editTicket(BuildContext context, StoreTicket ticket) async {
    final TicketEditResult? result = await showDialog<TicketEditResult>(
      context: context,
      builder: (BuildContext dialogContext) =>
          TicketEditDialog(ticket: ticket),
    );
    if (result == null || !context.mounted) {
      return;
    }
    try {
      await StoreAdminService(
        FirebaseFirestore.instance,
      ).applyTicketEdit(result);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Billet mis à jour.')),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mise à jour refusée : ${error.message}')),
      );
    }
  }
}

/// Message d'erreur lisible pour un flux Firestore en échec.
///
/// Un index composite encore en cours de création se manifeste par une
/// erreur `failed-precondition` (« The query requires an index ») :
/// l'interface ne doit pas rester figée sur un spinner, on explique donc
/// comment déployer `firestore.indexes.json`.
class _FirestoreStreamError extends StatelessWidget {
  const _FirestoreStreamError({required this.error});

  /// Erreur reçue par le `StreamBuilder`.
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final String raw = error?.toString() ?? 'Erreur inconnue.';
    // Détection mutualisée avec l'application mobile
    // (`core/errors/firestore_error_message.dart`). Seul le texte diffère : le
    // panneau est un outil de production, la consigne de déploiement y est donc
    // utile, là où l'application affiche une attente.
    final bool indexPending = isMissingFirestoreIndex(error);
    final String message = indexPending
        ? 'Index Firestore en cours de création. Déployez-les avec '
              '« firebase deploy --only firestore:indexes », puis rechargez '
              'cette page dans une minute.'
        : 'Données indisponibles : $raw';
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
