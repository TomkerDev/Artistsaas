import 'package:artistsaas/core/utils/byte_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ByteFormatter', () {
    test('affiche les octets bruts en dessous d\'un kilooctet', () {
      expect(ByteFormatter.format(0), '0 o');
      expect(ByteFormatter.format(512), '512 o');
    });

    test('affiche les kilooctets avec une décimale', () {
      expect(ByteFormatter.format(1024), '1.0 Ko');
      expect(ByteFormatter.format(1536), '1.5 Ko');
    });

    test('affiche les mégaoctets avec une décimale', () {
      expect(ByteFormatter.format(1024 * 1024), '1.0 Mo');
      expect(ByteFormatter.format(3584 * 1024), '3.5 Mo');
    });

    test('affiche les gigaoctets avec une décimale', () {
      expect(ByteFormatter.format(1024 * 1024 * 1024), '1.0 Go');
    });
  });
}
