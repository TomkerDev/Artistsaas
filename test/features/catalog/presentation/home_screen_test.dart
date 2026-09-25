import 'dart:async';

import 'package:artistsaas/app/di/app_providers.dart';
import 'package:artistsaas/core/constants/app_strings.dart';
import 'package:artistsaas/core/errors/app_exception.dart';
import 'package:artistsaas/features/catalog/domain/entities/track.dart';
import 'package:artistsaas/features/catalog/domain/repositories/music_repository.dart';
import 'package:artistsaas/features/catalog/domain/repositories/track_repository.dart';
import 'package:artistsaas/features/catalog/presentation/home_screen.dart';
import 'package:artistsaas/features/catalog/presentation/widgets/track_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

/// Dépôt dont la lecture ne se termine jamais : indispensable pour observer
/// l'état de chargement de façon déterministe.
final class _PendingMusicRepository
    implements MusicRepository, TrackRepository {
  @override
  Future<List<Track>> getTracks() => Completer<List<Track>>().future;
}

void main() {
  FakeDownloadRepository? downloadRepository;
  FakeAudioPlayerService? audioPlayerService;

  List<Override> overrides(TrackRepository repository) => <Override>[
    musicRepositoryProvider.overrideWithValue(repository),
    downloadRepositoryProvider.overrideWithValue(
      downloadRepository ??= FakeDownloadRepository(),
    ),
    audioPlayerServiceProvider.overrideWithValue(
      audioPlayerService ??= FakeAudioPlayerService(),
    ),
    playbackSourceResolverProvider.overrideWithValue(
      FakePlaybackSourceResolver(),
    ),
  ];

  Future<void> pumpHome(WidgetTester tester, TrackRepository repository) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: overrides(repository),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
  }

  group('HomeScreen', () {
    testWidgets('affiche un indicateur pendant le chargement', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester, _PendingMusicRepository());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(TrackListTile), findsNothing);
    });

    testWidgets('affiche les pistes du catalogue', (WidgetTester tester) async {
      await pumpHome(
        tester,
        FakeMusicRepository(
          tracks: <Track>[
            buildTrack(
              id: 'a',
              title: 'Premier morceau',
              artistName: 'Artiste',
              album: 'Album 2026',
              duration: const Duration(seconds: 30),
            ),
            buildTrack(
              id: 'b',
              title: 'Second morceau',
              artistName: 'Artiste',
              album: null,
              duration: const Duration(minutes: 1, seconds: 5),
              isDownloadable: false,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TrackListTile), findsNWidgets(2));
      expect(find.text('Premier morceau'), findsOneWidget);
      expect(find.text('Artiste · Album 2026'), findsOneWidget);
      expect(find.text('Second morceau'), findsOneWidget);
      expect(find.text('Artiste'), findsOneWidget);
      // La durée laisse la place au bouton de téléchargement lorsque le
      // morceau est téléchargeable ; elle s'affiche sinon.
      expect(find.text('1:05'), findsOneWidget);
    });

    testWidgets('affiche une bannière responsive avant les titres', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpHome(
        tester,
        FakeMusicRepository(
          tracks: <Track>[buildTrack(title: 'Premier morceau')],
        ),
      );
      await tester.pump();

      final Finder hero = find.ancestor(
        of: find.text('Dilson Le Mustang'),
        matching: find.byType(ClipRRect),
      );
      expect(find.text('Compil Officielles'), findsOneWidget);
      expect(hero, findsWidgets);
      final Finder heroDecorations = find.descendant(
        of: hero.first,
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).gradient is LinearGradient,
        ),
      );
      expect(heroDecorations, findsOneWidget);
      expect(
        find.descendant(of: hero.first, matching: find.byType(Image)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('le bouton de téléchargement matérialise le morceau', (
      WidgetTester tester,
    ) async {
      await pumpHome(
        tester,
        FakeMusicRepository(
          tracks: <Track>[buildTrack(id: 'a', title: 'Morceau téléchargeable')],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.download_outlined));
      await tester.pumpAndSettle();

      expect(downloadRepository!.downloadCount, 1);
      expect(find.text(AppStrings.downloadCompletedMessage), findsOneWidget);
    });

    testWidgets('affiche un message lorsque le catalogue est vide', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester, FakeMusicRepository());
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.homeEmptyMessage), findsOneWidget);
      expect(find.byType(TrackListTile), findsNothing);
    });

    testWidgets('affiche l\'erreur et permet de réessayer', (
      WidgetTester tester,
    ) async {
      final FakeMusicRepository repository = FakeMusicRepository(
        failure: const CatalogException('Catalogue illisible'),
      );
      await pumpHome(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.homeErrorTitle), findsOneWidget);
      expect(find.text('Catalogue illisible'), findsOneWidget);
      expect(find.byType(TrackListTile), findsNothing);

      repository
        ..failure = null
        ..tracks = <Track>[buildTrack(title: 'Après réessai')];

      await tester.tap(find.text(AppStrings.retryAction));
      await tester.pumpAndSettle();

      expect(find.text('Après réessai'), findsOneWidget);
      expect(repository.callCount, 2);
    });
  });
}
