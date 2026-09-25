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
  Future<void> createTicket({
    required String userId,
    required String eventId,
    required String ticketType,
    required String qrCodeData,
  }) => _firestore.collection('tickets').add(<String, Object?>{
    'user_id': userId,
    'event_id': eventId,
    'ticket_type': ticketType,
    'qr_code_data': qrCodeData,
    'status': 'pending',
    'created_at': FieldValue.serverTimestamp(),
  });
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
}
