import 'package:artistsaas/core/constants/artist_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrôle du registre central des artistes.
///
/// Ce registre est la source de vérité partagée par l'application mobile et le
/// panneau d'administration : une régression ici se verrait dans les deux
/// applications à la fois.
void main() {
  group('registre des artistes', () {
    test('Jethsonat est déclaré sous le label Tete Roh Studio', () {
      final ArtistProfile? profile = artistProfileFor('jethsonat');

      expect(profile, isNotNull);
      expect(profile!.stageName, 'Jethsonat');
      expect(profile.legalName, 'Jethro Badjim Berdi');
      expect(profile.label, 'Tete Roh Studio');
      expect(profile.productionCredit,
          'Produced & Distributed by Tete Roh Studio');
    });

    test('Jethsonat porte son univers et sa nomination SICA 2026', () {
      final ArtistProfile profile = artistProfileFor('jethsonat')!;

      expect(profile.universe, 'Sec Sec 🌾🔥');
      expect(profile.distinction, contains('SICA 2026'));
      expect(profile.distinction, contains('Cotonou'));
      expect(profile.distinction, contains('Meilleure Musique Afro-Ethnique'));
    });

    test('Jethsonat expose ses réseaux sociaux officiels', () {
      final ArtistSocials socials = artistProfileFor('jethsonat')!.socials;

      expect(
        socials.facebook,
        Uri.parse('https://www.facebook.com/share/1Ct5rxA4b8'),
      );
      expect(
        socials.youtube,
        Uri.parse('https://www.youtube.com/@jethsonatofficiel4256'),
      );
    });

    test('la pochette de header est déclarée', () {
      expect(
        artistProfileFor('jethsonat')!.coverAsset,
        'assets/covers/jethsonat_cover.png',
      );
    });

    test('un identifiant inconnu retombe sur une fiche de repli', () {
      expect(artistProfileFor('inconnu'), isNull);
      expect(resolveArtistProfile('inconnu').stageName, isNotEmpty);
    });
  });
}
