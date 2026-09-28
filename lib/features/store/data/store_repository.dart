import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/store_models.dart';

class StoreRepository {
  StoreRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  Stream<List<ShowEvent>> watchEvents({String? artistId}) => _firestore
      .collection('events')
      .where('artistId', isEqualTo: artistId)
      .orderBy('date', descending: false)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(ShowEvent.fromFirestore).toList(growable: false),
      );
  Stream<List<MerchProduct>> watchMerch({String? artistId}) => _firestore
      .collection('merch')
      .where('artistId', isEqualTo: artistId)
      .orderBy('name')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(MerchProduct.fromFirestore)
            .toList(growable: false),
      );
  /// Réserve un billet et renvoie son identifiant.
  ///
  /// Le billet naît en `pending` : seul l'administrateur peut le confirmer
  /// (cf. `firestore.rules`).
  ///
  /// L'identifiant suffit à l'appelant : il ne consomme que le `.id` du
  /// document, et cela évite de faire transiter une référence Firestore dans
  /// toute la couche interface.
  Future<String> createTicket({
    required String userId,
    required String eventId,
    required String ticketType,
  }) async {
    final DocumentReference<Map<String, dynamic>> ticket = await _firestore
        .collection('tickets')
        .add(<String, Object?>{
          'user_id': userId,
          'event_id': eventId,
          'ticket_type': ticketType,
          'qr_code_data': _buildQrPayload(eventId, ticketType),
          'status': 'pending',
          'created_at': FieldValue.serverTimestamp(),
        });
    return ticket.id;
  }
  Stream<List<StoreTicket>> watchTickets({String? eventId}) => _firestore
      .collection('tickets')
      .where('event_id', isEqualTo: eventId)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(StoreTicket.fromFirestore)
            .toList(growable: false),
      );
  Future<void> confirmTicket(String id) => _firestore
      .collection('tickets')
      .doc(id)
      .update(<String, Object?>{'status': 'confirmed'});

  /// Incrémente le compteur de places vendues d'un événement.
  ///
  /// Appelé après une réservation pour garder la barre de remplissage
  /// cohérente. `increment` est atomique côté serveur : deux réservations
  /// simultanées ne s'écrasent pas.
  Future<void> incrementSeatsSold(String eventId) => _firestore
      .collection('events')
      .doc(eventId)
      .update(<String, Object?>{'seats_sold': FieldValue.increment(1)});

  /// Charge utile encodée dans le QR code du billet.
  ///
  /// Volontairement minimaliste : l'identifiant du billet n'étant pas connu
  /// avant l'écriture, le contenu dérive de l'événement et du type de place.
  String _buildQrPayload(String eventId, String ticketType) =>
      'TETEROH:$eventId:$ticketType';
}
