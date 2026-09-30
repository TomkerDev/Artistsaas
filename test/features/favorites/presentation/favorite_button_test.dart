import 'package:artistsaas/app/di/app_providers.dart';
import 'package:artistsaas/core/errors/app_exception.dart';
import 'package:artistsaas/features/favorites/domain/entities/favorite.dart';
import 'package:artistsaas/features/favorites/presentation/widgets/favorite_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

/// Monte le bouton Favori avec un dépôt en mémoire (pas de `sqflite`).
Future<FakeFavoriteRepository> pumpFavoriteButton(WidgetTester tester) async {
  final FakeFavoriteRepository repository = FakeFavoriteRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        favoriteRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        home: Scaffold(body: FavoriteButton(trackId: 'track-1')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets(
    'ajoute la piste aux favoris au premier appui (cœur + SnackBar)',
    (WidgetTester tester) async {
      final FakeFavoriteRepository repository =
          await pumpFavoriteButton(tester);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Bascule visuelle immédiate + confirmation à l'utilisateur.
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text('Ajouté aux favoris'), findsOneWidget);
      expect(
        repository.favorites.map((Favorite f) => f.trackId),
        contains('track-1'),
      );

      // Laisse le SnackBar se terminer avant la fin du test.
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'retire la piste des favoris au second appui',
    (WidgetTester tester) async {
      final FakeFavoriteRepository repository =
          await pumpFavoriteButton(tester);

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      // Laisse le premier SnackBar expirer complètement : le
      // ScaffoldMessenger met en file d'attente le second message tant que
      // le premier est encore affiché.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.text('Retiré des favoris'), findsOneWidget);
      expect(repository.favorites, isEmpty);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    "échec de persistance : message d'erreur et cœur inchangé",
    (WidgetTester tester) async {
      final FakeFavoriteRepository repository =
          await pumpFavoriteButton(tester);
      repository.failure = const FavoriteException('Stockage indisponible.');

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // L'état optimiste a été restauré : le cœur ne bascule pas.
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.text('Stockage indisponible.'), findsOneWidget);
      expect(repository.favorites, isEmpty);

      await tester.pumpAndSettle();
    },
  );
}