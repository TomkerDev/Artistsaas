import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/config/app_config.dart';
import '../../../core/constants/artist_config.dart';
import '../../../core/errors/firestore_error_message.dart';
import '../data/store_repository.dart';
import '../domain/store_models.dart';
import 'store_providers.dart';

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
///
/// L'écran observe deux flux Firestore via Riverpod (billetterie et
/// merchandise) au lieu de listes codées en dur : le contenu publié depuis le
/// panneau d'administration apparaît ici sans réédition de l'application.
/// Chaque section affiche un état de chargement, une erreur exploitable et un
/// état vide explicite — une panne réseau ne doit pas ressembler à un
/// catalogue vide.
class StoreShowScreen extends ConsumerStatefulWidget {
  const StoreShowScreen({super.key});

  @override
  ConsumerState<StoreShowScreen> createState() => _StoreShowScreenState();
}

class _StoreShowScreenState extends ConsumerState<StoreShowScreen> {
  int _section = 0;
  String? _selectedProductId;
  String? _selectedSize;
  String? _selectedColor;
  String? _ticketCode;
  String? _ticketEventTitle;

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

  /// Billetterie : concerts à venir de l'artiste courant.
  Widget _ticketing() {
    final AsyncValue<List<ShowEvent>> events = ref.watch(
      upcomingEventsProvider,
    );

    return events.when(
      loading: () => const _StoreSkeleton(grid: false),
      error: (Object error, StackTrace stack) => _ErrorView(
        message: firestoreErrorMessage(
          error,
          fallback: 'Billetterie indisponible.',
        ),
        detail: firestoreErrorDetail(error),
        onRetry: () => ref.invalidate(upcomingEventsProvider),
      ),
      data: (List<ShowEvent> list) {
        if (list.isEmpty) {
          return const _EmptyView(
            icon: Icons.event_busy,
            title: 'Aucun concert annoncé',
            message: 'Les prochaines dates apparaîtront ici.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            _sectionHeader(
              'Événements à venir',
              'Réservez votre place pour les prochains shows.',
            ),
            const SizedBox(height: 12),
            for (final ShowEvent event in list) _eventCardFor(event),
            if (_ticketCode != null) _ticketCard(),
          ],
        );
      },
    );
  }

  /// Fiche d'un concert, avec la billetterie Mobile Money.
  Widget _eventCardFor(ShowEvent event) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                event.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _eventLine(Icons.calendar_today_outlined, event.displayDate),
              if (event.location.isNotEmpty)
                _eventLine(Icons.location_on_outlined, event.location),
              _eventLine(
                Icons.payments_outlined,
                'Standard ${event.formatPrice(event.priceStd)}'
                '${event.priceVip > 0 ? ' · VIP ${event.formatPrice(event.priceVip)}' : ''}',
              ),
              if (event.totalSeats > 0) ...<Widget>[
                const SizedBox(height: 8),
                _seatsGauge(event),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: event.isSoldOut ? null : () => _startPayment(event),
                icon: const Icon(Icons.phone_android),
                label: Text(
                  event.isSoldOut ? 'Complet' : 'Acheter mon Billet',
                ),
              ),
            ],
          ),
        ),
      );

  /// Barre de remplissage des places, avec le nombre restant.
  Widget _seatsGauge(ShowEvent event) {
    final ThemeData theme = Theme.of(context);
    final int remaining = event.remainingSeats;
    final double ratio = event.totalSeats == 0
        ? 0
        : (event.seatsSold / event.totalSeats).clamp(0.0, 1.0);
    final bool tight = remaining > 0 && remaining <= 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LinearProgressIndicator(value: ratio),
        const SizedBox(height: 4),
        Text(
          remaining == 0
              ? 'Billetterie complète'
              : '$remaining place${remaining > 1 ? 's' : ''} restante'
                    '${remaining > 1 ? 's' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: tight
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

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

  /// Ouvre l'application Mobile Money, puis propose de valider le reçu.
  ///
  /// Le billet n'est créé qu'après confirmation du client : on n'émet pas de
  /// réservation pour un paiement non effectué.
  Future<void> _startPayment(ShowEvent event) async {
    final String merchant = event.mobileMoneyNumber;
    if (merchant.isEmpty) {
      _toast('Aucun numéro Mobile Money n\'est configuré pour ce concert.');
      return;
    }

    final Uri uri = Uri(
      scheme: 'sms',
      path: merchant,
      query:
          'body=${Uri.encodeComponent('Paiement billet ${event.title} — ${event.formatPrice(event.priceStd)}')}',
    );
    if (!await launchUrl(uri)) {
      _toast('Impossible d\'ouvrir Mobile Money. Vérifiez votre téléphone.');
      return;
    }
    if (!mounted) {
      return;
    }

    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Reçu Mobile Money'),
            content: Text(
              'Après avoir envoyé votre paiement au marchand $merchant, '
              'validez le reçu pour recevoir votre billet.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Plus tard'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Valider mon reçu'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }
    await _issueTicket(event);
  }

  /// Crée le billet en base et affiche son QR code.
  ///
  /// Le document naît en `pending` : l'administrateur le confirmera après
  /// réception du paiement. L'incrément des places vendues est déclenché ici
  /// pour que la jauge reste juste.
  Future<void> _issueTicket(ShowEvent event) async {
    try {
      final StoreRepository repository = ref.read(storeRepositoryProvider);
      final String ticketId = await repository.createTicket(
        userId: currentStoreUserId,
        eventId: event.id,
        ticketType: 'standard',
      );
      await repository.incrementSeatsSold(event.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _ticketCode = ticketId;
        _ticketEventTitle = event.title;
      });
    } on Object catch (error) {
      _toast('Réservation impossible : $error');
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

  Widget _ticketCard() => Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              const Text(
                'Billet en attente de validation',
                style: TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Présentez ce QR code au guichet après confirmation du '
                'paiement par l\'organisation.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(_ticketEventTitle ?? ''),
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

  /// Catalogue merchandise de l'artiste courant.
  Widget _merchandise() {
    final AsyncValue<List<MerchProduct>> products = ref.watch(merchProvider);

    return products.when(
      loading: () => const _StoreSkeleton(grid: true),
      error: (Object error, StackTrace stack) => _ErrorView(
        message: firestoreErrorMessage(
          error,
          fallback: 'Boutique indisponible.',
        ),
        detail: firestoreErrorDetail(error),
        onRetry: () => ref.invalidate(merchProvider),
      ),
      data: (List<MerchProduct> list) {
        if (list.isEmpty) {
          return const _EmptyView(
            icon: Icons.shopping_bag_outlined,
            title: 'Boutique en préparation',
            message: 'Les articles officiels arriveront prochainement.',
          );
        }
        final MerchProduct? selected = _selectedProduct(list);
        return ListView(
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
              itemCount: list.length,
              itemBuilder: (BuildContext context, int index) =>
                  _productCard(list[index]),
            ),
            if (selected != null) _orderSummary(selected),
          ],
        );
      },
    );
  }

  /// Article sélectionné, ou `null` s'il n'est plus dans la liste.
  ///
  /// Le contenu est filtré côté serveur : un article supprimé du panneau doit
  /// faire disparaître le récapitulatif, pas laisser une commande orpheline.
  MerchProduct? _selectedProduct(List<MerchProduct> products) {
    final String? id = _selectedProductId;
    if (id == null) {
      return null;
    }
    for (final MerchProduct product in products) {
      if (product.id == id) {
        return product;
      }
    }
    return null;
  }

  /// Vignette d'un article : image distante si disponible, icône sinon.
  Widget _productCard(MerchProduct product) {
    final bool selected = _selectedProductId == product.id;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: selected
          ? RoundedRectangleBorder(
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: InkWell(
        onTap: () => setState(() {
          _selectedProductId = product.id;
          // Tailles et couleurs par défaut, si l'article en propose.
          _selectedSize = product.sizes.isNotEmpty ? product.sizes.first : null;
          _selectedColor ??= 'Noir';
        }),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: product.hasImage
                    ? Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        // Repli sur l'icône si l'URL casse : la vignette ne
                        // doit pas laisser un trou dans la grille.
                        errorBuilder:
                            (
                              BuildContext context,
                              Object error,
                              StackTrace? stack,
                            ) => _productFallback(),
                      )
                    : _productFallback(),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(product.formattedPrice),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Visuel de repli pour un article sans image.
  Widget _productFallback() => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.checkroom, size: 72),
      );

  /// Récapitulatif et options de l'article sélectionné.
  Widget _orderSummary(MerchProduct product) => Card(
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
              Text('${product.name} · ${product.formattedPrice}'),
              // Les tailles ne sont proposées que si l'article en a : un
              // article unique (goodies) n'a pas de taille à choisir.
              if (product.sizes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSize,
                  decoration: const InputDecoration(labelText: 'Taille'),
                  items: <DropdownMenuItem<String>>[
                    for (final String size in product.sizes)
                      DropdownMenuItem<String>(
                        value: size,
                        child: Text(size),
                      ),
                  ],
                  onChanged: (String? value) =>
                      setState(() => _selectedSize = value),
                ),
              ],
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
                onPressed: () => _orderViaWhatsApp(product),
                icon: const Icon(Icons.chat),
                label: const Text('Commander via WhatsApp'),
              ),
            ],
          ),
        ),
      );

  /// Ouvre WhatsApp avec le récapitulatif de commande pré-rempli.
  Future<void> _orderViaWhatsApp(MerchProduct product) async {
    // Le contact vient de la fiche article ; sans lui la commande ne peut pas
    // aboutir : mieux vaut le dire que d'ouvrir une conversation vide.
    final String contact = product.whatsappContact;
    if (contact.isEmpty) {
      _toast('Aucun contact WhatsApp n\'est configuré pour cet article.');
      return;
    }

    final String message = Uri.encodeComponent(
      'Bonjour, je souhaite commander : ${product.name}, '
      'prix ${product.formattedPrice}'
      '${_selectedSize != null ? ', taille $_selectedSize' : ''}'
      '${_selectedColor != null ? ', couleur $_selectedColor' : ''}.',
    );
    final Uri uri = Uri.parse('https://wa.me/$contact?text=$message');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      _toast('WhatsApp n\'est pas disponible sur cet appareil.');
    }
  }
}

/// Écran vide explicite : distingue « rien à afficher » d'une panne.
class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Erreur de chargement, avec une action de relance.
///
/// Sans elle, un échec réseau est indiscernable d'un catalogue vide — et
/// l'utilisateur n'a aucun moyen de savoir qu'il peut réessayer.
class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_off,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            // Le détail technique est facultatif : un index Firestore en cours
            // de création n'a rien de lisible à afficher sous son message
            // d'attente.
            if (detail.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Squelette de chargement de la boutique.
///
/// Trois cartes grises figées (billetterie) ou quatre vignettes (merchandise)
/// annoncent la mise en page avant l'arrivée des données. Un indicateur
/// tournant laissait, lui, un écran vide pour toute la durée de l'attente
/// réseau — sans rien indiquer du contenu attendu.
class _StoreSkeleton extends StatelessWidget {
  const _StoreSkeleton({required this.grid});

  /// `true` pour la grille merchandise, `false` pour la liste des concerts.
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final Color block = Theme.of(context).colorScheme.surfaceContainerHighest;
    if (grid) {
      return GridView.count(
        key: merchSkeletonKey,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: .78,
        children: <Widget>[
          for (int i = 0; i < 4; i++) _SkeletonBlock(color: block),
        ],
      );
    }
    return ListView(
      key: skeletonKey,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SkeletonBlock(color: block, height: 20),
                const SizedBox(height: 10),
                _SkeletonBlock(color: block, height: 14),
                const SizedBox(height: 8),
                _SkeletonBlock(color: block, height: 14, widthFactor: .6),
              ],
            ),
          ),
      ],
    );
  }
}

/// Rectangle uni du squelette, arrondi comme les cartes qu'il préfigure.
class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.color,
    this.height = 16,
    this.widthFactor = 1,
  });

  final Color color;
  final double height;

  /// Fraction de la largeur occupée : une ligne secondaire plus courte dessine
  /// une hiérarchie lisible.
  final double widthFactor;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
}

/// Clé du squelette de la billetterie, également utilisée par les tests.
const Key skeletonKey = ValueKey<String>('store-skeleton');

/// Clé du squelette de la grille merchandise, également utilisée par les tests.
const Key merchSkeletonKey = ValueKey<String>('store-skeleton-merch');
