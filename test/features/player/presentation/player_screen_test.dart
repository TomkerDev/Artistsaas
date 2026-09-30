import 'package:artistsaas/app/di/app_providers.dart';
import 'package:artistsaas/app/shell/home_shell.dart';
import 'package:artistsaas/core/constants/app_strings.dart';
import 'package:artistsaas/features/catalog/domain/entities/track.dart';
import 'package:artistsaas/features/player/presentation/playback_controller.dart';
import 'package:artistsaas/features/player/presentation/player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

/// Monte l'écran Lecteur avec des doublures sur toutes les dépendances.
///
/// Renvoie le conteneur Riverpod pour piloter le contrôleur de lecture depuis
/// le test, exactement comme le ferait une action utilisateur.
Future<ProviderContainer> pumpPlayer(WidgetTester tester) async {
  final FakeAudioPlayerService service = FakeAudioPlayerService();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        audioPlayerServiceProvider.overrideWithValue(service),
        playbackSourceResolverProvider.overrideWithValue(
          FakePlaybackSourceResolver(),
        ),
        musicRepositoryProvider.overrideWithValue(FakeMusicRepository()),
        downloadRepositoryProvider.overrideWithValue(FakeDownloadRepository()),
        favoriteRepositoryProvider.overrideWithValue(FakeFavoriteRepository()),
      ],
      child: const MaterialApp(home: PlayerScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(PlayerScreen)),
  );
}

void main() {
  testWidgets('affiche l\'état vide lorsqu\'aucun morceau n\'est en lecture', (
    WidgetTester tester,
  ) async {
    await pumpPlayer(tester);

    expect(find.text(AppStrings.playerEmptyMessage), findsOneWidget);
  });

  testWidgets('affiche le morceau courant, la position et les contrôles', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpPlayer(tester);

    await container
        .read(playbackControllerProvider.notifier)
        .playCatalog(<Track>[buildTrack(id: 'a', title: 'Morceau en lecture')]);
    await tester.pumpAndSettle();

    expect(find.text('Morceau en lecture'), findsOneWidget);
    expect(find.text('Artiste de test'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous), findsOneWidget);
  });

  testWidgets('affiche l\'erreur de lecture avec bouton d\'acquittement', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpPlayer(tester);

    await container
        .read(playbackControllerProvider.notifier)
        .playCatalog(<Track>[buildTrack(id: 'a', title: 'Morceau en erreur')]);
    await tester.pumpAndSettle();

    // Publie une erreur comme le ferait le moteur audio réel.
    final FakeAudioPlayerService service =
        container.read(audioPlayerServiceProvider) as FakeAudioPlayerService;
    service.emit(
      container.read(playbackControllerProvider).copyWith(
            errorMessage: 'Source illisible',
          ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Source illisible'), findsOneWidget);
  });

  testWidgets(
    'le cœur du lecteur bascule les favoris et confirme par un SnackBar',
    (WidgetTester tester) async {
      final ProviderContainer container = await pumpPlayer(tester);

      await container
          .read(playbackControllerProvider.notifier)
          .playCatalog(<Track>[
        buildTrack(id: 'a', title: 'Morceau à aimer'),
      ]);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text('Ajouté aux favoris'), findsOneWidget);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'le bouton X referme l\'écran du lecteur vers l\'onglet d\'origine',
    (WidgetTester tester) async {
      await pumpPlayer(tester);
      // L'écran est un onglet de la coquille : simule une ouverture venue
      // d'un autre onglet (ici Boutique, index 3).
      selectedTabNotifier.value = 1;
      lastNonPlayerTab = 3;
      addTearDown(() {
        selectedTabNotifier.value = 0;
        lastNonPlayerTab = 0;
      });

      await tester.tap(find.byTooltip(AppStrings.playerCloseAction));
      await tester.pumpAndSettle();

      // La fermeture retourne à l'onglet d'origine (la lecture, elle, n'est
      // pas touchée : le mini-lecteur prend le relais sur les autres onglets).
      expect(selectedTabNotifier.value, 3);
    },
  );

  testWidgets(
    'l\'icône aléatoire reste active après les émissions du moteur',
    (WidgetTester tester) async {
      final ProviderContainer container = await pumpPlayer(tester);

      await container
          .read(playbackControllerProvider.notifier)
          .playCatalog(<Track>[buildTrack(id: 'a')]);
      await tester.pumpAndSettle();

      // Les contrôles sont sous la ligne de flottaison du `ScrollView` de
      // l'écran : on les fait défiler avant de les actionner.
      await tester.ensureVisible(find.byIcon(Icons.shuffle));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.shuffle));
      await tester.pumpAndSettle();

      // Un tick de position du moteur remplace l'état du contrôleur : le
      // mode aléatoire doit y survivre (sinon l'icône clignote puis revient
      // en blanc, comme si le bouton ne réagissait pas).
      final FakeAudioPlayerService service = container
          .read(audioPlayerServiceProvider) as FakeAudioPlayerService;
      service.emit(
        service.state.copyWith(position: const Duration(seconds: 2)),
      );
      await tester.pumpAndSettle();

      final Icon icon = tester.widget<Icon>(find.byIcon(Icons.shuffle));
      expect(icon.color, isNot(Colors.white));
      expect(
        container.read(playbackControllerProvider).shuffleEnabled,
        isTrue,
      );
    },
  );
}
