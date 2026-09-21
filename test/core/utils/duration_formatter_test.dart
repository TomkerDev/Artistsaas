import 'package:artistsaas/core/utils/duration_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DurationFormatter.format', () {
    test('affiche 0:00 pour une durée nulle', () {
      expect(DurationFormatter.format(Duration.zero), '0:00');
    });

    test('affiche les secondes sur deux chiffres', () {
      expect(DurationFormatter.format(const Duration(seconds: 5)), '0:05');
      expect(DurationFormatter.format(const Duration(seconds: 45)), '0:45');
    });

    test('affiche les minutes sans les compléter', () {
      expect(
        DurationFormatter.format(const Duration(minutes: 3, seconds: 5)),
        '3:05',
      );
      expect(
        DurationFormatter.format(const Duration(minutes: 59, seconds: 59)),
        '59:59',
      );
    });

    test('passe au format horaire dès une heure', () {
      expect(DurationFormatter.format(const Duration(hours: 1)), '1:00:00');
      expect(
        DurationFormatter.format(
          const Duration(hours: 1, minutes: 2, seconds: 3),
        ),
        '1:02:03',
      );
    });

    test('tronque les millisecondes', () {
      expect(
        DurationFormatter.format(const Duration(seconds: 3, milliseconds: 999)),
        '0:03',
      );
    });

    test('traite une durée négative comme 0:00', () {
      expect(DurationFormatter.format(const Duration(seconds: -10)), '0:00');
    });
  });
}
