import 'package:cloud_firestore/cloud_firestore.dart';

class ShowEvent {
  const ShowEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.location,
    required this.priceStd,
    required this.priceVip,
    required this.mobileMoneyNumber,
    required this.totalSeats,
    this.createdAt,
  });
  factory ShowEvent.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return ShowEvent(
      id: doc.id,
      title: data['title'] as String? ?? '',
      date: _date(data['date']),
      location: data['location'] as String? ?? '',
      priceStd: _number(data['price_std']),
      priceVip: _number(data['price_vip']),
      mobileMoneyNumber: data['mobile_money_number'] as String? ?? '',
      totalSeats: _number(data['total_seats']).round(),
      createdAt: data['created_at'] as Timestamp?,
    );
  }
  final String id, title, date, location, mobileMoneyNumber;
  final double priceStd, priceVip;
  final int totalSeats;
  final Timestamp? createdAt;
  static String _date(Object? value) => value is Timestamp
      ? value.toDate().toIso8601String()
      : value?.toString() ?? '';
  static double _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

class MerchProduct {
  const MerchProduct({
    required this.id,
    required this.name,
    required this.priceFcfa,
    required this.imageUrl,
    required this.sizes,
    required this.whatsappContact,
  });
  factory MerchProduct.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return MerchProduct(
      id: doc.id,
      name: data['name'] as String? ?? '',
      priceFcfa:
          (data['price_fcfa'] as num?)?.toDouble() ??
          double.tryParse('${data['price_fcfa']}') ??
          0,
      imageUrl: data['image_url'] as String? ?? '',
      sizes: (data['sizes'] as List<dynamic>? ?? const [])
          .map((e) => '$e')
          .toList(growable: false),
      whatsappContact: data['whatsapp_contact'] as String? ?? '',
    );
  }
  final String id, name, imageUrl, whatsappContact;
  final double priceFcfa;
  final List<String> sizes;
}

class StoreTicket {
  const StoreTicket({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.ticketType,
    required this.qrCodeData,
    required this.status,
  });
  factory StoreTicket.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return StoreTicket(
      id: doc.id,
      userId: data['user_id'] as String? ?? '',
      eventId: data['event_id'] as String? ?? '',
      ticketType: data['ticket_type'] as String? ?? 'standard',
      qrCodeData: data['qr_code_data'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
    );
  }
  final String id, userId, eventId, ticketType, qrCodeData, status;
}
