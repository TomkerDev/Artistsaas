import 'package:artistsaas/core/utils/collections.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('itemsEqual', () {
    test('compare les listes élément par élément', () {
      expect(itemsEqual<int>(<int>[1, 2, 3], <int>[1, 2, 3]), isTrue);
      expect(itemsEqual<int>(<int>[1, 2, 3], <int>[1, 2, 4]), isFalse);
      expect(itemsEqual<int>(<int>[1, 2], <int>[1, 2, 3]), isFalse);
    });

    test('considère deux listes nulles ou deux listes vides comme égales', () {
      expect(itemsEqual<int>(null, null), isTrue);
      expect(itemsEqual<int>(<int>[], <int>[]), isTrue);
    });

    test('distingue une liste nulle d\'une liste vide', () {
      expect(itemsEqual<int>(null, <int>[]), isFalse);
      expect(itemsEqual<int>(<int>[], null), isFalse);
    });

    test('utilise l\'égalité des éléments et non leur identité', () {
      expect(
        itemsEqual<String>(<String>['a', 'b'], <String>['a', 'b']),
        isTrue,
      );
    });
  });
}
