import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/config/app_config.dart';
import '../../../core/constants/artist_config.dart';

class AboutArtistScreen extends StatelessWidget {
  const AboutArtistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Identité, biographie et liens proviennent du registre central des
    // artistes : l'écran n'a plus de contenu figé par artiste.
    final ArtistProfile artist = AppConfig.artist;
    final ArtistSocials socials = artist.socials;

    return Scaffold(
      appBar: AppBar(title: const Text('À Propos / Biographie')),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
          final String version = snapshot.data == null
              ? 'Version $appVersion - Build 1'
              : 'Version ${snapshot.data!.version} '
                  '- Build ${snapshot.data!.buildNumber}';
          return ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              _ArtistAvatar(coverAsset: artist.coverAsset),
              const SizedBox(height: 20),
              Text(
                artist.stageName,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              // Nom civil et label partenaire : l'identité complète de l'artiste.
              Text(
                artist.legalName,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                artist.productionCredit,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (artist.universe.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  artist.universe,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall,
                ),
              ],
              const SizedBox(height: 16),
              Text(
                artist.biography,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              if (artist.distinction != null) ...<Widget>[
                const SizedBox(height: 20),
                _DistinctionCard(distinction: artist.distinction!),
              ],
              const SizedBox(height: 28),
              Text(
                'Réseaux sociaux',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (socials.facebook != null)
                _SocialLink(
                  label: 'Facebook',
                  icon: Icons.facebook,
                  url: socials.facebook!,
                ),
              if (socials.youtube != null)
                _SocialLink(
                  label: 'YouTube',
                  icon: Icons.play_circle_outline,
                  url: socials.youtube!,
                ),
              if (socials.instagram != null)
                _SocialLink(
                  label: 'Instagram',
                  icon: Icons.camera_alt_outlined,
                  url: socials.instagram!,
                ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  version,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Numéro de version de l'application, affiché lorsque `package_info_plus`
/// n'a pas encore répondu.
const String appVersion = '1.0.0';

/// Avatar de l'artiste : pochette officielle, avec repli sur une icône.
class _ArtistAvatar extends StatelessWidget {
  const _ArtistAvatar({required this.coverAsset});

  final String coverAsset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipOval(
        child: Image.asset(
          coverAsset,
          width: 116,
          height: 116,
          fit: BoxFit.cover,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stack) =>
                  const CircleAvatar(
            radius: 58,
            child: Icon(Icons.person, size: 58),
          ),
        ),
      ),
    );
  }
}

/// Encart mettant en avant la distinction officielle de l'artiste.
class _DistinctionCard extends StatelessWidget {
  const _DistinctionCard({required this.distinction});

  final String distinction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.workspace_premium, color: colors.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              distinction,
              style: TextStyle(color: colors.onPrimaryContainer, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialLink extends StatelessWidget {
  const _SocialLink({
    required this.label,
    required this.icon,
    required this.url,
  });
  final String label;
  final IconData icon;

  /// Lien officiel, déjà validé comme URL absolue par le registre.
  final Uri url;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle:
            Text(url.toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.open_in_new),
        onTap: () async {
          if (!await launchUrl(url, mode: LaunchMode.externalApplication) &&
              context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Lien indisponible.')));
          }
        },
      );
}

/// Boutique et événements de l'artiste.
class StoreShowScreen extends StatefulWidget {
  const StoreShowScreen({super.key});

  @override
  State<StoreShowScreen> createState() => _StoreShowScreenState();
}

class _StoreShowScreenState extends State<StoreShowScreen> {
  int _section = 0;
  int? _selectedEvent;
  int? _selectedProduct;
  String? _selectedSize;
  String? _selectedColor;
  String? _ticketCode;

  static const List<_ShowEvent> _events = <_ShowEvent>[
    _ShowEvent(
      'Nuit Novaa — Live',
      'Samedi 18 juillet 2026',
      'Palais des Sports, Brazzaville',
      '5 000 FCFA',
      '+242 06 000 00 00',
    ),
    _ShowEvent(
      'Show de fin d’année',
      'Vendredi 12 décembre 2026',
      'Stade Municipal, Brazzaville',
      '10 000 FCFA',
      '+242 06 000 00 00',
    ),
  ];

  static const List<_Product> _products = <_Product>[
    _Product(
      'T-shirt Novaa',
      'Le modèle officiel de la tournée',
      '8 000 FCFA',
      Icons.checkroom,
    ),
    _Product(
      'Casquette Novaa',
      'Casquette brodée, édition limitée',
      '5 000 FCFA',
      Icons.sports_baseball,
    ),
    _Product(
      'Goodies Show',
      'Tourne-page et stickers exclusifs',
      '3 000 FCFA',
      Icons.card_giftcard,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boutique & Show'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<int>(
              segments: const <ButtonSegment<int>>[
                ButtonSegment<int>(
                  value: 0,
                  label: Text('Billetterie'),
                  icon: Icon(Icons.confirmation_num_outlined),
                ),
                ButtonSegment<int>(
                  value: 1,
                  label: Text('Merchandise'),
                  icon: Icon(Icons.shopping_bag_outlined),
                ),
              ],
              selected: <int>{_section},
              onSelectionChanged: (Set<int> value) =>
                  setState(() => _section = value.first),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _section,
        children: <Widget>[_ticketing(), _merchandise()],
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(subtitle),
        ],
      );

  Widget _ticketing() => StreamBuilder<QuerySnapshot>(
        stream: Firebase.apps.isEmpty
            ? const Stream<QuerySnapshot>.empty()
            : FirebaseFirestore.instance
                .collection('events')
                .orderBy('date')
                .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          final List<_ShowEvent> remote =
              (snapshot.data?.docs ?? const <QueryDocumentSnapshot<dynamic>>[])
                  .map(
            (QueryDocumentSnapshot<dynamic> doc) {
              final Map<String, dynamic> data =
                  doc.data() as Map<String, dynamic>;
              return _ShowEvent(
                data['title'] as String? ?? 'Événement',
                data['date']?.toString() ?? '',
                data['location'] as String? ?? '',
                '${data['price_std'] ?? 0} FCFA',
                data['mobile_money_number'] as String? ?? '',
              );
            },
          ).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: <Widget>[
              _sectionHeader(
                'Événements à venir',
                'Réservez votre place pour les prochains shows.',
              ),
              const SizedBox(height: 12),
              for (final _ShowEvent event in <_ShowEvent>[
                ...remote,
                ..._events
              ])
                _eventCardFor(event),
              if (_ticketCode != null) _ticketCard(),
            ],
          );
        },
      );

  Widget _eventCardFor(_ShowEvent event) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(event.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _eventLine(Icons.calendar_today_outlined, event.date),
              _eventLine(Icons.location_on_outlined, event.place),
              _eventLine(Icons.payments_outlined, event.price),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _startPayment(event),
                  icon: const Icon(Icons.phone_android),
                  label: const Text('Acheter mon Billet'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _eventLine(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );

  Future<void> _startPayment(_ShowEvent event) async {
    final Uri uri = Uri(
      scheme: 'sms',
      path: event.merchant,
      query:
          'body=${Uri.encodeComponent('Paiement billet ${event.title} — ${event.price}')}',
    );
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible d’ouvrir Mobile Money. Vérifiez votre téléphone.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Reçu Mobile Money'),
        content: Text(
          'Après avoir envoyé votre paiement au marchand ${event.merchant}, validez le reçu pour recevoir votre billet.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _selectedEvent = _events.indexOf(event);
                _ticketCode = 'NOVAA-${DateTime.now().millisecondsSinceEpoch}';
              });
            },
            child: const Text('Valider mon reçu'),
          ),
        ],
      ),
    );
  }

  Widget _ticketCard() => Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              const Text(
                'Billet validé',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_events[_selectedEvent ?? 0].title),
              const SizedBox(height: 12),
              QrImageView(
                data: _ticketCode!,
                size: 190,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                _ticketCode!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );

  Widget _merchandise() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          _sectionHeader(
            'Merchandise officielle',
            'Choisis ton article et confirme tes préférences.',
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: .78,
            ),
            itemCount: _products.length,
            itemBuilder: (BuildContext context, int index) =>
                _productCard(index),
          ),
          if (_selectedProduct != null) _orderSummary(),
        ],
      );

  Widget _productCard(int index) {
    final _Product product = _products[index];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() {
          _selectedProduct = index;
          _selectedSize ??= 'M';
          _selectedColor ??= 'Noir';
        }),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(product.icon, size: 72),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(product.price),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderSummary() {
    final _Product product = _products[_selectedProduct!];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Votre sélection',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('${product.name} · ${product.price}'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedSize,
              decoration: const InputDecoration(labelText: 'Taille'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'S', child: Text('S')),
                DropdownMenuItem(value: 'M', child: Text('M')),
                DropdownMenuItem(value: 'L', child: Text('L')),
                DropdownMenuItem(value: 'XL', child: Text('XL')),
              ],
              onChanged: (String? value) =>
                  setState(() => _selectedSize = value),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedColor,
              decoration: const InputDecoration(labelText: 'Couleur'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'Noir', child: Text('Noir')),
                DropdownMenuItem(value: 'Blanc', child: Text('Blanc')),
                DropdownMenuItem(value: 'Rouge', child: Text('Rouge')),
              ],
              onChanged: (String? value) =>
                  setState(() => _selectedColor = value),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _orderViaWhatsApp,
              icon: const Icon(Icons.chat),
              label: const Text('Commander via WhatsApp'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _orderViaWhatsApp() async {
    final _Product product = _products[_selectedProduct!];
    final String message = Uri.encodeComponent(
      'Bonjour, je souhaite commander : ${product.name}, taille $_selectedSize, couleur $_selectedColor, prix ${product.price}.',
    );
    final Uri uri = Uri.parse('https://wa.me/242000000000?text=$message');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp n’est pas disponible sur cet appareil.'),
        ),
      );
    }
  }
}

class _ShowEvent {
  const _ShowEvent(
    this.title,
    this.date,
    this.place,
    this.price,
    this.merchant,
  );
  final String title;
  final String date;
  final String place;
  final String price;
  final String merchant;
}

class _Product {
  const _Product(this.name, this.description, this.price, this.icon);
  final String name;
  final String description;
  final String price;
  final IconData icon;
}
