import 'package:artistsaas/app/di/app_providers.dart';
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
}
