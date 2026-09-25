import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
          onDestinationSelected: (int value) => setState(() => _index = value),
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
              _DashboardView(),
              AdminUploadPage(),
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

class _DashboardView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      'Dashboard\n\nLes statistiques Firestore sont disponibles dans Catalogue & Upload.',
      textAlign: TextAlign.center,
    ),
  );
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();
  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  final _bio = TextEditingController(
    text: 'Dilson Le Mustang, artiste de la nouvelle scène congolaise.',
  );
  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await FirebaseFirestore.instance
        .collection('artist_profiles')
        .doc('dilson_le_mustang')
        .set(<String, Object?>{
          'biography': _bio.text.trim(),
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
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
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
          FilledButton(
            onPressed: _save,
            child: const Text('Enregistrer le profil'),
          ),
        ],
      ),
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
        ListTile(
          leading: Icon(Icons.shield_outlined),
          title: Text('Rôles utilisateurs'),
          subtitle: Text(
            'Gérez les rôles artist et agency_admin dans Firestore.',
          ),
          trailing: Icon(Icons.chevron_right),
        ),
        ListTile(
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
                decoration: const InputDecoration(labelText: 'Prix standard'),
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
          decoration: const InputDecoration(labelText: 'Numéro Mobile Money'),
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
            final QueryDocumentSnapshot<DocumentSnapshot> doc =
                snapshot.data!.docs[index]
                    as QueryDocumentSnapshot<DocumentSnapshot>;
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
