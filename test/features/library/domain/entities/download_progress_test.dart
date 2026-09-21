import 'package:artistsaas/features/library/domain/entities/download_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DownloadProgress', () {
    test('signale une matérialisation terminée', () {
      const DownloadProgress progress = DownloadProgress(
        trackId: 'single-001',
        state: DownloadState.completed,
        receivedBytes: 3500000,
        totalBytes: 3500000,
      );

      expect(progress.isCompleted, isTrue);
      expect(progress.isRunning, isFalse);
      expect(progress.hasFailed, isFalse);
      expect(progress.fraction, 1);
    });

    test('signale une copie en cours', () {
      const DownloadProgress progress = DownloadProgress(
        trackId: 'single-001',
        state: DownloadState.downloading,
        receivedBytes: 1,
        totalBytes: 2,
      );

      expect(progress.isRunning, isTrue);
      expect(progress.isCompleted, isFalse);
      expect(progress.fraction, 0.5);
    });

    test('signale un échec et conserve le message', () {
      const DownloadProgress progress = DownloadProgress(
        trackId: 'single-001',
        state: DownloadState.failed,
        errorMessage: 'Espace insuffisant sur le disque',
      );

      expect(progress.hasFailed, isTrue);
      expect(progress.errorMessage, 'Espace insuffisant sur le disque');
    });

    test('renvoie une progression nulle sans taille totale connue', () {
      const DownloadProgress sansTaille = DownloadProgress(
        trackId: 'single-001',
        state: DownloadState.downloading,
        receivedBytes: 1200,
      );
      const DownloadProgress tailleNulle = DownloadProgress(
        trackId: 'single-001',
        state: DownloadState.downloading,
        receivedBytes: 1200,
        totalBytes: 0,
      );

      expect(sansTaille.fraction, isNull);
      expect(tailleNulle.fraction, isNull);
    });

    test('borne la progression entre 0 et 1', () {
      const DownloadProgress depassement = DownloadProgress(
        trackId: 'single-001',
        state: DownloadState.downloading,
        receivedBytes: 150,
        totalBytes: 100,
      );

      expect(depassement.fraction, 1);
    });
  });
}
