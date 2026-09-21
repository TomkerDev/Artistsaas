import 'package:artistsaas/app/artist_app.dart';
import 'package:artistsaas/app/di/app_providers.dart';
import 'package:artistsaas/core/constants/app_strings.dart';
import 'package:artistsaas/features/catalog/domain/entities/track.dart';
import 'package:artistsaas/features/catalog/presentation/home_screen.dart';
import 'package:artistsaas/features/catalog/presentation/widgets/track_list_tile.dart';
import 'package:artistsaas/features/library/presentation/my_music_screen.dart';
import 'package:artistsaas/features/player/presentation/player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  /// Monte l'application complète, comme le fait `main.dart`.
  ///
  /// Le dépôt de catalogue est remplacé par un faux : le test ne dépend donc ni
  /// du regroupement d'assets ni du contenu réel du catalogue.
  Future<void> pumpApp(WidgetTester tester, {List<Track>? tracks}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          musicRepositoryProvider.overrideWithValue(
            FakeMusicRepository(
              tracks: tracks ?? <Track>[buildTrack(title: 'Titre affiché')],
            ),
          ),
        ],
        child: const ArtistApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Indice de l'onglet affiché par la coquille.
  int selectedTab(WidgetTester tester) =>
      tester.widget<IndexedStack>(find.byType(IndexedStack)).index ?? 0;

  group('ArtistApp', () {
    testWidgets('expose les trois onglets du MVP', (WidgetTester tester) async {
      await pumpApp(tester);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      expect(find.text(AppStrings.tabHome), findsOneWidget);
      expect(find.text(AppStrings.tabPlayer), findsOneWidget);
      expect(find.text(AppStrings.tabMyMusic), findsOneWidget);
    });

    testWidgets('démarre sur l\'onglet Accueil et affiche le catalogue', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      expect(selectedTab(tester), 0);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text(AppStrings.homeTitle), findsOneWidget);
      expect(find.byType(TrackListTile), findsOneWidget);
      expect(find.text('Titre affiché'), findsOneWidget);
      // Seul le sous-arbre de l'onglet sélectionné est considéré comme affiché :
      // les écrans des autres onglets restent montés, mais hors écran.
      expect(find.byType(PlayerScreen), findsNothing);
      expect(find.byType(MyMusicScreen), findsNothing);
    });

    testWidgets('change d\'onglet et revient à l\'accueil', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      // Le tap se fait sur l'icône : « Ma musique » et « Lecteur » sont aussi des
      // titres d'écran, un tap sur le libellé serait ambigu pour le finder.
      await tester.tap(find.byIcon(Icons.library_music_outlined));
      await tester.pumpAndSettle();
      expect(selectedTab(tester), 2);
      expect(find.byType(MyMusicScreen), findsOneWidget);
      expect(find.text(AppStrings.myMusicPlaceholder), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      await tester.tap(find.byIcon(Icons.play_circle_outline));
      await tester.pumpAndSettle();
      expect(selectedTab(tester), 1);
      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(find.text(AppStrings.playerPlaceholder), findsOneWidget);
      expect(find.byType(MyMusicScreen), findsNothing);

      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      expect(selectedTab(tester), 0);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
