import 'package:cloud_firestore/cloud_firestore.dart';

/// Publication des événements et du merchandising depuis le panneau.
///
/// Point d'entrée unique des deux collections : c'est ici que sont posés le
/// `artistId` (indispensable, les écrans mobiles filtrent dessus) et la
/// validation. Les formulaires ne manipulent plus Firestore directement, ce
/// qui évite qu'un champ soit oublié dans l'un des deux écrans.
class StoreAdminService {
  const StoreAdminService(this._firestore);

  final FirebaseFirestore _firestore;

  /// Levée si un champ obligatoire manque ou est mal typé.
  ///
  /// Le message est destiné à être affiché tel quel dans l'admin.
  static const String validationMessage =
      'Vérifiez les champs signalés : titre, date, lieu, prix, '
      'numéro Mobile Money et nombre de places sont obligatoires.';

  /// Publier un événement.
  ///
  /// - [artistId] : artiste propriétaire, écrit dans le document.
  /// - [date] : date de la représentation, stockée en `Timestamp` afin de
  ///   pouvoir trier et filtrer les shows à venir ; le champ `date_label` garde
  ///   la formulation lisible (« Samedi 18 juillet 2026 »).
  Future<String> createEvent({
    required String artistId,
    required String title,
    required DateTime date,
    required String dateLabel,
    required String location,
    required double priceStd,
    required double priceVip,
    required String mobileMoneyNumber,
    required int totalSeats,
  }) async {
    _requireArtist(artistId);
    if (title.trim().isEmpty ||
        location.trim().isEmpty ||
        mobileMoneyNumber.trim().isEmpty) {
      throw StateError(validationMessage);
    }
    if (!date.isAfter(DateTime.now())) {
      throw StateError('La date du concert doit être dans le futur.');
    }
    if (priceStd <= 0 || priceVip <= 0) {
      throw StateError('Les prix standard et VIP doivent être positifs.');
    }
    if (totalSeats <= 0) {
      throw StateError('Le nombre de places doit être supérieur à zéro.');
    }

    final DocumentReference<Map<String, dynamic>> doc = await _firestore
        .collection('events')
        .add(<String, Object?>{
          'artistId': artistId,
          'title': title.trim(),
          'date': Timestamp.fromDate(date),
          'date_label': dateLabel.trim(),
          'location': location.trim(),
          'price_std': priceStd,
          'price_vip': priceVip,
          'mobile_money_number': mobileMoneyNumber.trim(),
          'total_seats': totalSeats,
          'seats_sold': 0,
          'created_at': FieldValue.serverTimestamp(),
        });
    return doc.id;
  }

  /// Publier un article de merchandising.
  ///
  /// [imageUrl] est facultative : l'application affiche une icône de repli
  /// quand elle est absente. Un prix nul est refusé — un article gratuit se
  /// gère via une commande directe, pas via un panier.
  Future<String> createMerch({
    required String artistId,
    required String name,
    required double priceFcfa,
    required String whatsappContact,
    String description = '',
    String imageUrl = '',
    List<String> sizes = const <String>[],
  }) async {
    _requireArtist(artistId);
    if (name.trim().isEmpty || whatsappContact.trim().isEmpty) {
      throw StateError(
        'Le nom de l\'article et le contact WhatsApp sont obligatoires.',
      );
    }
    if (priceFcfa <= 0) {
      throw StateError('Le prix doit être supérieur à zéro.');
    }
    if (imageUrl.trim().isNotEmpty &&
        !RegExp(r'^https?://').hasMatch(imageUrl.trim())) {
      throw StateError('L\'URL de l\'image doit commencer par http:// ou https://');
    }

    final DocumentReference<Map<String, dynamic>> doc = await _firestore
        .collection('merch')
        .add(<String, Object?>{
          'artistId': artistId,
          'name': name.trim(),
          'description': description.trim(),
          'price_fcfa': priceFcfa,
          'image_url': imageUrl.trim(),
          'sizes': <String>[
            for (final String size in sizes)
              if (size.trim().isNotEmpty) size.trim(),
          ],
          'whatsapp_contact': whatsappContact.trim(),
          'created_at': FieldValue.serverTimestamp(),
        });
    return doc.id;
  }

  /// Supprimer un événement.
  Future<void> deleteEvent(String id) =>
      _firestore.collection('events').doc(id).delete();

  /// Supprimer un article.
  Future<void> deleteMerch(String id) =>
      _firestore.collection('merch').doc(id).delete();

  /// `true` si [artistId] permet de publier.
  ///
  /// Le compte d'agence doit avoir choisi un artiste réel : publier avec
  /// l'identifiant vide rendrait le document invisible pour tout le monde.
  void _requireArtist(String artistId) {
    if (artistId.trim().isEmpty) {
      throw StateError(
        'Aucun artiste sélectionné : choisissez l\'artiste avant de publier.',
      );
    }
  }
}