import 'package:artistsaas/features/store/presentation/store_show_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('affiche la billetterie et les événements à venir', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: StoreShowScreen()));
    await tester.pump();

    expect(find.text('Billetterie'), findsOneWidget);
    expect(find.text('Nuit Novaa — Live'), findsOneWidget);
    expect(find.text('Samedi 18 juillet 2026'), findsOneWidget);
    expect(find.text('Acheter mon Billet'), findsNWidgets(2));
  });

  testWidgets('permet de choisir un article et ses options', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: StoreShowScreen()));
    await tester.tap(find.text('Merchandise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Casquette Novaa'));
    await tester.pumpAndSettle();

    expect(find.text('Votre sélection'), findsOneWidget);
    expect(find.text('Taille'), findsOneWidget);
    expect(find.text('Couleur'), findsOneWidget);
    expect(find.text('Commander via WhatsApp'), findsOneWidget);
  });
}
