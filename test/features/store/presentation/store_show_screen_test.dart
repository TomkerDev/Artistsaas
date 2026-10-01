import 'dart:async';

import 'package:artistsaas/features/store/domain/store_models.dart';
import 'package:artistsaas/features/store/presentation/store_providers.dart';
import 'package:artistsaas/features/store/presentation/store_show_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes_store.dart';

void main() {
  /// Monte l'écran avec un dépôt de boutique piloté par le test.
  Future<void> pumpStore(
    WidgetTester tester,
    FakeStoreRepository repository,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          storeRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: StoreShowScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Concert à venir, construit directement en mémoire.
  ShowEvent upcomingEvent({
    String id = 'evt-1',
    String title = 'Nuit Sec Sec',
  }) => ShowEvent(
    id: id,
    title: title,
    location: 'Palais des Sports',
    priceStd: 5000,
    priceVip: 10000,
    mobileMoneyNumber: '+2420600000000',
    totalSeats: 100,
    date: DateTime.now().add(const Duration(days: 30)),
    dateLabel: 'Samedi 18 juillet 2026',
  );

  group('StoreShowScreen — billetterie', () {
    testWidgets('affiche les concerts à venir du dépôt', (
      WidgetTester tester,
    ) async {
      await pumpStore(
        tester,
        FakeStoreRepository(events: <ShowEvent>[upcomingEvent()]),
      );

      expect(find.text('Billetterie'), findsOneWidget);
      expect(find.text('Nuit Sec Sec'), findsOneWidget);
      expect(find.text('Samedi 18 juillet 2026'), findsOneWidget);
      expect(find.text('Acheter mon Billet'), findsOneWidget);
    });

    testWidgets('masque les concerts déjà passés', (WidgetTester tester) async {
      await pumpStore(
        tester,
        FakeStoreRepository(
          events: <ShowEvent>[
            ShowEvent(
              id: 'old',
              title: 'Concert ancien',
              location: 'Stade',
              priceStd: 1000,
              priceVip: 0,
              mobileMoneyNumber: '+242',
              totalSeats: 10,
              date: DateTime.now().subtract(const Duration(days: 30)),
            ),
          ],
        ),
      );

      expect(find.text('Concert ancien'), findsNothing);
    });

    testWidgets('conserve les concerts dont la date est inconnue', (
      WidgetTester tester,
    ) async {
      await pumpStore(
        tester,
        FakeStoreRepository(
          events: <ShowEvent>[
            const ShowEvent(
              id: 'no-date',
              title: 'Concert à confirmer',
              location: 'Stade',
              priceStd: 1000,
              priceVip: 0,
              mobileMoneyNumber: '+242',
              totalSeats: 10,
            ),
          ],
        ),
      );

      expect(find.text('Concert à confirmer'), findsOneWidget);
      expect(find.text('Date à confirmer'), findsOneWidget);
    });

    testWidgets('affiche un état vide explicite', (WidgetTester tester) async {
      await pumpStore(tester, FakeStoreRepository());

      expect(find.text('Aucun concert annoncé'), findsOneWidget);
      expect(find.text('Acheter mon Billet'), findsNothing);
    });

    testWidgets('propose de réessayer sur erreur réseau', (
      WidgetTester tester,
    ) async {
      final FakeStoreRepository repository = FakeStoreRepository()
        ..failure = Exception('Firestore injoignable');

      await pumpStore(tester, repository);

      expect(find.text('Billetterie indisponible.'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('remplace l\'erreur brute d\'index par un message d\'attente', (
      WidgetTester tester,
    ) async {
      final FakeStoreRepository repository = FakeStoreRepository()
        ..failure = Exception(
          '[cloud_firestore/failed-precondition] The query requires an index.',
        );

      await pumpStore(tester, repository);

      expect(find.textContaining('index Firestore'), findsOneWidget);
      // La trace technique ne doit jamais fuiter vers l'utilisateur mobile.
      expect(find.textContaining('failed-precondition'), findsNothing);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('affiche un squelette tant que les données arrivent', (
      WidgetTester tester,
    ) async {
      final Completer<void> gate = Completer<void>();
      final FakeStoreRepository repository = FakeStoreRepository()
        ..loadGate = gate;

      await pumpStore(tester, repository);

      expect(find.byKey(skeletonKey), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // L'autre section charge en parallèle et annonce elle aussi la mise en
      // page attendue.
      await tester.tap(find.text('Merchandise'));
      await tester.pumpAndSettle();
      expect(find.byKey(merchSkeletonKey), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      // La section affichée laisse la place au contenu dès l'arrivée des
      // données : plus aucun squelette.
      expect(find.byKey(merchSkeletonKey), findsNothing);

      await tester.tap(find.text('Billetterie'));
      await tester.pumpAndSettle();

      expect(find.byKey(skeletonKey), findsNothing);
      expect(find.text('Aucun concert annoncé'), findsOneWidget);
    });

    testWidgets('désactive la billetterie quand il n\'y a plus de place', (
      WidgetTester tester,
    ) async {
      await pumpStore(
        tester,
        FakeStoreRepository(
          events: <ShowEvent>[
            ShowEvent(
              id: 'complet',
              title: 'Sold out',
              location: 'Stade',
              priceStd: 1000,
              priceVip: 0,
              mobileMoneyNumber: '+242',
              totalSeats: 50,
              seatsSold: 50,
              date: DateTime.now().add(const Duration(days: 10)),
            ),
          ],
        ),
      );

      expect(find.text('Complet'), findsOneWidget);
      expect(find.text('Billetterie complète'), findsOneWidget);
    });
  });

  group('StoreShowScreen — merchandise', () {
    testWidgets('affiche le catalogue et permet de commander', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpStore(
        tester,
        FakeStoreRepository(
          merch: <MerchProduct>[
            const MerchProduct(
              id: 'm1',
              name: 'Casquette Tete Roh',
              priceFcfa: 5000,
              whatsappContact: '2420600000000',
              sizes: <String>['S', 'M', 'L'],
            ),
          ],
        ),
      );

      await tester.tap(find.text('Merchandise'));
      await tester.pumpAndSettle();

      expect(find.text('Casquette Tete Roh'), findsOneWidget);
      expect(find.text('5000 FCFA'), findsOneWidget);

      await tester.tap(find.text('Casquette Tete Roh'));
      await tester.pumpAndSettle();

      expect(find.text('Votre sélection'), findsOneWidget);
      expect(find.text('Taille'), findsOneWidget);
      expect(find.text('Couleur'), findsOneWidget);
      expect(find.text('Commander via WhatsApp'), findsOneWidget);
    });

    testWidgets('affiche un état vide explicite', (WidgetTester tester) async {
      await pumpStore(tester, FakeStoreRepository());

      await tester.tap(find.text('Merchandise'));
      await tester.pumpAndSettle();

      expect(find.text('Boutique en préparation'), findsOneWidget);
    });

    testWidgets('propose de réessayer sur erreur réseau', (
      WidgetTester tester,
    ) async {
      final FakeStoreRepository repository = FakeStoreRepository()
        ..failure = Exception('Firestore injoignable');

      await pumpStore(tester, repository);

      await tester.tap(find.text('Merchandise'));
      await tester.pumpAndSettle();

      expect(find.text('Boutique indisponible.'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('n\'affiche aucun article codé en dur', (
      WidgetTester tester,
    ) async {
      // Régression : la boutique ne doit rien inventer quand le dépôt est vide.
      await pumpStore(tester, FakeStoreRepository());

      await tester.tap(find.text('Merchandise'));
      await tester.pumpAndSettle();

      expect(find.text('T-shirt Novaa'), findsNothing);
      expect(find.text('Casquette Novaa'), findsNothing);
    });
  });
}
