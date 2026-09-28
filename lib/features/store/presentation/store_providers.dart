/// Injection de la boutique (billetterie & merchandise) dans l'interface.
///
/// L'écran ne connaît plus Firestore : il observe ces flux. Les tests
/// remplacent [storeRepositoryProvider] par un faux, ce qui les rend
/// indépendants du backend et supprime toute liste codée en dur dans
/// l'interface.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../data/store_repository.dart';
import '../domain/store_models.dart';

/// Dépôt de la boutique, partagé par les deux sections de l'écran.
final Provider<StoreRepository> storeRepositoryProvider =
    Provider<StoreRepository>((Ref ref) => StoreRepository());

/// Artiste dont la billetterie et la boutique sont affichées.
///
/// Fixé à la compilation (`--dart-define=ARTIST_ID=jethsonat`) : l'application
/// ne montre que les événements et articles de son propre artiste.
final Provider<String> storeArtistIdProvider = Provider<String>(
  (Ref ref) => AppConfig.artistId,
);

/// Flux des concerts à venir de l'artiste courant.
///
/// Les concerts passés sont filtrés côté client : Firestore ne propose pas de
/// « Maintenant », et un `orderBy` + `endAt` ajouterait un index de plus.
final StreamProvider<List<ShowEvent>> upcomingEventsProvider =
    StreamProvider<List<ShowEvent>>((Ref ref) {
  final StoreRepository repository = ref.watch(storeRepositoryProvider);
  final String artistId = ref.watch(storeArtistIdProvider);

  return repository.watchEvents(artistId: artistId).map(
    (List<ShowEvent> events) => <ShowEvent>[
      // Événements sans date conservés : masqués, ils disparaîtraient du
      // catalogue alors que l'organisateur n'a pas encore fixé la date.
      for (final ShowEvent event in events)
        if (event.isUpcoming) event,
    ],
  );
});

/// Flux du catalogue merchandise de l'artiste courant.
final StreamProvider<List<MerchProduct>> merchProvider =
    StreamProvider<List<MerchProduct>>((Ref ref) {
  final StoreRepository repository = ref.watch(storeRepositoryProvider);
  return repository.watchMerch(artistId: ref.watch(storeArtistIdProvider));
});

/// Réserve un billet pour [event] et renvoie son identifiant.
///
/// [ShowEvent.id] identifie le concert ; le billet naît en `pending` et sera
/// confirmé par l'administrateur après réception du paiement.
final FutureProviderFamily<String, ShowEvent> ticketReservationProvider =
    FutureProvider.family<String, ShowEvent>((Ref ref, ShowEvent event) {
      final StoreRepository repository = ref.watch(storeRepositoryProvider);
      return repository.createTicket(
        userId: currentStoreUserId,
        eventId: event.id,
        ticketType: 'standard',
      );
    });

/// Identifiant de l'acheteur utilisé pour les billets.
///
/// L'authentification du public n'est pas encore en place : un identifiant de
/// session suffit à regrouper les billets d'un même appareil. À remplacer par
/// `FirebaseAuth.instance.currentUser?.uid` dès que la connexion existe —
/// la valeur est déjà celle attendue par `user_id`.
const String currentStoreUserId = 'anonymous-device';
