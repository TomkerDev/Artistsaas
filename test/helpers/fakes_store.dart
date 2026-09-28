import 'package:artistsaas/features/store/data/store_repository.dart';
import 'package:artistsaas/features/store/domain/store_models.dart';

/// Dépôt de boutique piloté par le test.
///
/// Permet de contrôler le contenu et les pannes du flux sans toucher à
/// Firestore : c'est ce qui a permis de supprimer les listes codées en dur de
/// l'écran, les tests vérifient désormais ce que le backend fournirait
/// réellement.
final class FakeStoreRepository implements StoreRepository {
  FakeStoreRepository({List<ShowEvent>? events, List<MerchProduct>? merch})
    : events = events ?? <ShowEvent>[],
      merch = merch ?? <MerchProduct>[];

  final List<ShowEvent> events;
  final List<MerchProduct> merch;

  /// Erreur levée par les flux, pour tester le rendu d'un échec réseau.
  Object? failure;

  /// Nombre de réservations demandées.
  int ticketCount = 0;

  @override
  Stream<List<ShowEvent>> watchEvents({String? artistId}) async* {
    if (failure != null) {
      throw failure!;
    }
    yield events;
  }

  @override
  Stream<List<MerchProduct>> watchMerch({String? artistId}) async* {
    if (failure != null) {
      throw failure!;
    }
    yield merch;
  }

  @override
  Future<String> createTicket({
    required String userId,
    required String eventId,
    required String ticketType,
  }) async {
    ticketCount++;
    return 'ticket-$eventId';
  }

  @override
  Future<void> incrementSeatsSold(String eventId) async {}

  @override
  Future<void> confirmTicket(String id) async {}

  @override
  Stream<List<StoreTicket>> watchTickets({String? eventId}) =>
      const Stream<List<StoreTicket>>.empty();
}
