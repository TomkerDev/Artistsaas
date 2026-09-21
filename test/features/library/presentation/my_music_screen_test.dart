import 'package:artistsaas/app/di/app_providers.dart';
import 'package:artistsaas/core/constants/app_strings.dart';
import 'package:artistsaas/features/library/presentation/my_music_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeDownloadRepository downloads;

  Future<void> pumpMyMusic(WidgetTester tester) async {
    downloads = FakeDownloadRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          downloadRepositoryProvider.overrideWithValue(downloads),
          musicRepositoryProvider.overrideWithValue(FakeMusicRepository()),
          audioPlayerServiceProvider.overrideWithValue(FakeAudioPlayerService()),
          playbackSourceResolverProvider.overrideWithValue(
            FakePlaybackSourceResolver(),
          ),
        ],
        child: const MaterialApp(home: MyMusicScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('affiche l\'état vide lorsqu\'aucun morceau n\'est téléchargé', (
    WidgetTester tester,
  ) async {
    await pumpMyMusic(tester);

    expect(find.text(AppStrings.myMusicEmptyMessage), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline), findsNothing);
  });

  testWidgets('affiche les morceaux téléchargés avec taille et date', (
    WidgetTester tester,
  ) async {
    await pumpMyMusic(tester);
    downloads.addDownloaded(
      buildTrack(id: 'a', title: 'Morceau hors connexion'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Morceau hors connexion'), findsOneWidget);
    // Le sous-titre regroupe artiste, taille et date : 1024 octets = 1,0 Ko.
    expect(find.textContaining('1.0 Ko'), findsOneWidget);
    expect(find.textContaining('01/01/2026'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('la suppression demande confirmation puis retire le morceau', (
    WidgetTester tester,
  ) async {
    await pumpMyMusic(tester);
    downloads.addDownloaded(buildTrack(id: 'a', title: 'À supprimer'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // Confirmation présente.
    expect(find.text(AppStrings.deleteConfirmTitle), findsOneWidget);

    await tester.tap(find.text(AppStrings.deleteAction));
    await tester.pumpAndSettle();

    expect(downloads.deleteCount, 1);
    expect(find.text(AppStrings.myMusicEmptyMessage), findsOneWidget);
  });

  testWidgets('annuler la suppression conserve le morceau', (
    WidgetTester tester,
  ) async {
    await pumpMyMusic(tester);
    downloads.addDownloaded(buildTrack(id: 'a', title: 'À conserver'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.cancelAction));
    await tester.pumpAndSettle();

    expect(downloads.deleteCount, 0);
    expect(find.text('À conserver'), findsOneWidget);
  });
}
