import 'dart:async';

import 'package:artistsaas/app/di/app_providers.dart';
import 'package:artistsaas/core/constants/app_strings.dart';
import 'package:artistsaas/core/errors/app_exception.dart';
import 'package:artistsaas/features/catalog/domain/entities/track.dart';
import 'package:artistsaas/features/catalog/domain/repositories/music_repository.dart';
import 'package:artistsaas/features/catalog/presentation/home_screen.dart';
import 'package:artistsaas/features/catalog/presentation/widgets/track_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

/// Dépôt dont la lecture ne se termine jamais : indispensable pour observer
/// l'état de chargement de façon déterministe.
final class _PendingMusicRepository implements MusicRepository {
  @override
  Future<List<Track>> getTracks() => Completer<List<Track>>().future;
}

void main() {
  Future<void> pumpHome(WidgetTester tester, MusicRepository repository) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          musicRepositoryProvider.overrideWithValue(repository),
        ],
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
              artist: 'Artiste',
              album: 'Album 2026',
              duration: const Duration(seconds: 30),
            ),
            buildTrack(
              id: 'b',
              title: 'Second morceau',
              artist: 'Artiste',
              album: null,
              duration: const Duration(minutes: 1, seconds: 5),
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
      expect(find.text('0:30'), findsOneWidget);
      expect(find.text('1:05'), findsOneWidget);
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
