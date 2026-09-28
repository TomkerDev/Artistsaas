import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Événement (concert) tel que stocké dans la collection `events`.
@immutable
class ShowEvent {
  const ShowEvent({
    required this.id,
    required this.title,
    required this.location,
    required this.priceStd,
    required this.priceVip,
    required this.mobileMoneyNumber,
    required this.totalSeats,
    this.date,
    this.dateLabel = '',
    this.seatsSold = 0,
    this.artistId,
    this.createdAt,
  });

  /// Construit un événement depuis un document Firestore.
  ///
  /// La désérialisation est tolérante : un champ absent ou mal typé prend une
  /// valeur par défaut plutôt que de faire échouer tout le catalogue. Un
  /// document corrompu ne doit pas rendre la billetterie inutilisable.
  factory ShowEvent.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    return ShowEvent(
      id: doc.id,
      title: _text(data['title'], fallback: 'Événement'),
      location: _text(data['location']),
      priceStd: _number(data['price_std']),
      priceVip: _number(data['price_vip']),
      mobileMoneyNumber: _text(data['mobile_money_number']),
      totalSeats: _number(data['total_seats']).round(),
      date: _date(data['date']),
      dateLabel: _text(data['date_label']),
      seatsSold: _number(data['seats_sold']).round(),
      artistId: _optionalText(data['artistId']),
      createdAt: data['created_at'] as Timestamp?,
    );
  }

  final String id;
  final String title;
  final String location;
  final double priceStd;
  final double priceVip;
  final String mobileMoneyNumber;
  final int totalSeats;

  /// Date de la représentation ; `null` si le document n'en porte pas.
  ///
  /// Un `date` absent place l'événement en fin de liste plutôt que de le
  /// faire disparaître : mieux vaut un concert sans date qu'un concert
  /// invisible.
  final DateTime? date;

  /// Formulation lisible choisie par l'organisateur (« Samedi 18 juillet »).
  final String dateLabel;

  /// Places déjà reservées, pour la barre de remplissage.
  final int seatsSold;

  /// Artiste propriétaire, utilisé pour le filtrage côté requête.
  final String? artistId;

  final Timestamp? createdAt;

  /// `true` si la date est connue et à venir.
  ///
  /// Les événements sans date restent affichables (billetterie de secours) :
  /// seul le tri et ce filtre s'appuient sur [date].
  bool get isUpcoming {
    final DateTime? when = date;
    return when == null || when.isAfter(DateTime.now());
  }

  /// Places restantes, jamais négatif.
  int get remainingSeats => (totalSeats - seatsSold).clamp(0, totalSeats);

  /// `true` quand la billetterie est épuisée.
  bool get isSoldOut => totalSeats > 0 && remainingSeats == 0;

  /// Libellé de date affichable, avec repli sur une valeur lisible par défaut.
  String get displayDate {
    if (dateLabel.isNotEmpty) {
      return dateLabel;
    }
    final DateTime? when = date;
    if (when == null) {
      return 'Date à confirmer';
    }
    return '${when.day.toString().padLeft(2, '0')}/'
        '${when.month.toString().padLeft(2, '0')}/${when.year}';
  }

  /// Prix formaté en francs CFA.
  String formatPrice(double price) => '${price.round()} FCFA';

  static String _text(Object? value, {String fallback = ''}) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;

  static String? _optionalText(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  /// Lit une date : `Timestamp`, chaîne ISO, ou `null` si illisible.
  static DateTime? _date(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String && value.trim().isNotEmpty) {
      // Tolérance pour les documents historiques, où `date` était une chaîne.
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  static double _number(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }
}

/// Article de merchandising tel que stocké dans la collection `merch`.
@immutable
class MerchProduct {
  const MerchProduct({
    required this.id,
    required this.name,
    required this.priceFcfa,
    required this.whatsappContact,
    this.description = '',
    this.imageUrl = '',
    this.sizes = const <String>[],
    this.artistId,
  });

  /// Construit un article depuis un document Firestore, de façon tolérante.
  factory MerchProduct.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    return MerchProduct(
      id: doc.id,
      name: MerchProduct._text(data['name'], fallback: 'Article'),
      description: MerchProduct._text(data['description']),
      priceFcfa: MerchProduct._number(data['price_fcfa']),
      imageUrl: MerchProduct._text(data['image_url']),
      sizes: <String>[
        for (final Object? size
            in (data['sizes'] as List<Object?>? ?? const <Object?>[]))
          if ('$size'.trim().isNotEmpty) '$size'.trim(),
      ],
      whatsappContact: MerchProduct._text(data['whatsapp_contact']),
      artistId: MerchProduct._optionalText(data['artistId']),
    );
  }

  final String id;
  final String name;
  final String description;
  final double priceFcfa;

  /// URL de l'image ; vide si l'article n'en a pas.
  final String imageUrl;
  final List<String> sizes;
  final String whatsappContact;

  /// Artiste propriétaire, utilisé pour le filtrage côté requête.
  final String? artistId;

  /// `true` si une image distante est disponible pour l'affichage.
  bool get hasImage => imageUrl.startsWith('http');

  /// Prix formaté en francs CFA.
  String get formattedPrice => '${priceFcfa.round()} FCFA';

  static String _text(Object? value, {String fallback = ''}) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;

  static String? _optionalText(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static double _number(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }
}

/// Billet réservé par un client, stocké dans la collection `tickets`.
@immutable
class StoreTicket {
  const StoreTicket({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.ticketType,
    required this.qrCodeData,
    required this.status,
    this.createdAt,
  });

  /// États possibles d'un billet.
  ///
  /// Le client ne peut créer qu'un billet `pending` : la confirmation est
  /// réservée à l'administrateur (cf. `firestore.rules`).
  static const String statusPending = 'pending';
  static const String statusConfirmed = 'confirmed';

  factory StoreTicket.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    return StoreTicket(
      id: doc.id,
      userId: _text(data['user_id']),
      eventId: _text(data['event_id']),
      ticketType: _text(data['ticket_type'], fallback: 'standard'),
      qrCodeData: _text(data['qr_code_data']),
      status: _text(data['status'], fallback: statusPending),
      createdAt: data['created_at'] as Timestamp?,
    );
  }

  final String id;
  final String userId;
  final String eventId;
  final String ticketType;
  final String qrCodeData;
  final String status;
  final Timestamp? createdAt;

  /// `true` une fois le billet validé par l'administrateur.
  bool get isConfirmed => status == statusConfirmed;

  static String _text(Object? value, {String fallback = ''}) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;
}
