import 'package:artistsaas/core/errors/firestore_error_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Erreur telle que Firestore la remonte quand un index manque.
  final Exception missingIndex = Exception(
    '[cloud_firestore/failed-precondition] The query requires an index. '
    'You can create this index here: '
    'https://console.firebase.google.com/project/novaa/firestore/indexes',
  );

  group('isMissingFirestoreIndex', () {
    test('reconnaît la precondition d\'index manquant', () {
      expect(isMissingFirestoreIndex(missingIndex), isTrue);
    });

    test('reconnaît l\'index même enveloppé dans une exception métier', () {
      // C'est le cas du catalogue : la source de données emballe l'erreur
      // Firestore dans une `CatalogException`, cause comprise dans le texte.
      expect(
        isMissingFirestoreIndex(
          Exception('Impossible de récupérer les nouveautés (cause : $missingIndex)'),
        ),
        isTrue,
      );
    });

    test('ignore une panne classique', () {
      expect(
        isMissingFirestoreIndex(Exception('Firestore injoignable')),
        isFalse,
      );
    });

    test('tolère une erreur nulle', () {
      expect(isMissingFirestoreIndex(null), isFalse);
    });
  });

  group('firestoreErrorMessage', () {
    test('prend le dessus sur le repli quand un index manque', () {
      expect(
        firestoreErrorMessage(missingIndex, fallback: 'Billetterie indisponible.'),
        missingFirestoreIndexMessage,
      );
    });

    test('laisse l\'appelant formuler une panne classique', () {
      expect(
        firestoreErrorMessage(
          Exception('Firestore injoignable'),
          fallback: 'Billetterie indisponible.',
        ),
        'Billetterie indisponible.',
      );
    });
  });

  group('firestoreErrorDetail', () {
    test('ne laisse pas fuir la trace brute d\'un index manquant', () {
      expect(firestoreErrorDetail(missingIndex), isEmpty);
    });

    test('conserve la trace d\'une panne classique', () {
      expect(
        firestoreErrorDetail(Exception('Firestore injoignable')),
        contains('Firestore injoignable'),
      );
    });

    test('borne une trace trop longue', () {
      final String detail = firestoreErrorDetail(
        Exception('x' * 400),
        maxLength: 50,
      );

      expect(detail.length, 51);
      expect(detail, endsWith('…'));
    });

    test('décrit une erreur absente', () {
      expect(firestoreErrorDetail(null), 'Erreur inconnue.');
    });
  });
}