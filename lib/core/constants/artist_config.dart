/// Registre des artistes distributionnés et de leur label partenaire.
///
/// Ce fichier est la **source de vérité** de l'identité d'un artiste dans
/// l'application : nom de scène, label, biographie, pochette de header et
/// liens officiels. `AppConfig` (voir `lib/app/config/app_config.dart`) y résout
/// l'artiste courant à partir de l'identifiant passé au build, et le panneau
/// d'administration web s'en sert pour le sélecteur d'artiste.
///
/// Ajouter un artiste revient donc à ajouter une entrée ici : aucun écran,
/// aucun écran de lecture ni aucun test n'a besoin d'être modifié.
library;

/// Réseaux sociaux officiels d'un artiste.
final class ArtistSocials {
  const ArtistSocials({this.facebook, this.youtube, this.instagram});

  /// Page Facebook officielle (URL complète, ouvrable par `url_launcher`).
  final Uri? facebook;

  /// Chaîne YouTube officielle (URL complète).
  final Uri? youtube;

  /// Page Instagram officielle (URL complète).
  final Uri? instagram;
}

/// Fiche complète d'un artiste : identité, label et contenus associés.
final class ArtistProfile {
  const ArtistProfile({
    required this.id,
    required this.stageName,
    required this.legalName,
    required this.label,
    required this.universe,
    required this.biography,
    required this.coverAsset,
    this.socials = const ArtistSocials(),
    this.distinction,
  });

  /// Identifiant canonique, aligné sur le champ Firestore `artistId`
  /// (`jethsonat`, `dilson_le_mustang`, …) et sur les flavors Android.
  final String id;

  /// Nom de scène affiché dans l'application.
  final String stageName;

  /// Nom civil de l'artiste, affiché dans la section « À Propos ».
  final String legalName;

  /// Label partenaire, crédité sur le lecteur et les fiches de morceaux.
  final String label;

  /// Univers musical de l'artiste (slogan court).
  final String universe;

  /// Biographie officielle, affichée dans l'écran « À Propos ».
  final String biography;

  /// Distinction officielle (nomination, prix) — `null` si aucune.
  final String? distinction;

  /// Pochette officielle affichée en en-tête de l'accueil.
  final String coverAsset;

  /// Liens officiels de l'artiste.
  final ArtistSocials socials;

  /// Mention de crédit affichée sur le lecteur et les fiches de morceaux.
  String get productionCredit => 'Produced & Distributed by $label';
}

/// Artistes de la plateforme, indexés par [ArtistProfile.id].
///
/// `jethsonat` est distribué sous le label partenaire **Tete Roh Studio** ;
/// `dilson_le_mustang` est conservé pour la compatibilité des instances
/// existantes et des collections Firestore déjà publiées.
///
/// La collection n'est pas `const` : les liens sociaux sont des [Uri], et
/// [Uri.parse] n'est pas une expression constante.
final Map<String, ArtistProfile> artistProfiles = <String, ArtistProfile>{
  'jethsonat': ArtistProfile(
    id: 'jethsonat',
    stageName: 'Jethsonat',
    legalName: 'Jethro Badjim Berdi',
    label: 'Tete Roh Studio',
    universe: 'Sec Sec 🌾🔥',
    biography: 'Jethsonat, de son vrai nom Jethro Badjim Berdi, est un artiste '
        'chanteur-performeur d\u2019afro-fusion tchadienne. Il développe un '
        'univers Massa (« Sec Sec 🌾🔥 »), où les rythmes traditionnels du '
        'Tchad rencontrent des sonorités contemporaines. Sa scène mêle '
        'percussion live, chant et danse, et il se produit régulièrement '
        'aussi bien au Tchad qu\u2019à l\u2019international.',
    distinction:
        'Nommé officiellement au Festival SICA 2026 à Cotonou (Bénin), dans la '
        'catégorie « Meilleure Musique Afro-Ethnique ».',
    coverAsset: 'assets/covers/jethsonat_cover.png',
    socials: ArtistSocials(
      facebook: Uri.parse('https://www.facebook.com/share/1Ct5rxA4b8'),
      youtube: Uri.parse('https://www.youtube.com/@jethsonatofficiel4256'),
    ),
  ),
  'dilson_le_mustang': const ArtistProfile(
    id: 'dilson_le_mustang',
    stageName: 'Dilson Le Mustang',
    legalName: 'Dilson Le Mustang',
    label: 'Tete Roh Studio',
    universe: 'Afro contemporary',
    biography:
        'Dilson Le Mustang est un artiste de la nouvelle scène congolaise. '
        'Passionné de sonorités afro contemporaines, il transforme chaque '
        'morceau en une expérience singulière, entre héritage musical et '
        'sonorités modernes.',
    coverAsset: 'assets/covers/dilson_cover.png',
  ),
};

/// Fiche d'un artiste par son identifiant, `null` si l'identifiant est inconnu.
ArtistProfile? artistProfileFor(String id) => artistProfiles[id];

/// Fiche de repli : évite un écran vide si le build porte un identifiant
/// d'artiste non déclaré dans [artistProfiles] (artistes de démonstration).
const ArtistProfile _fallbackProfile = ArtistProfile(
  id: 'artist_1',
  stageName: 'Novaa',
  legalName: 'Novaa',
  label: 'Tete Roh Studio',
  universe: 'Afro fusion',
  biography:
      'Artiste de la scène afro-fusion, il mêle sonorités traditionnelles et '
      'productions contemporaines.',
  coverAsset: 'assets/covers/cover-01.png',
);

/// Fiche de l'artiste courant, avec repli sur [_fallbackProfile].
ArtistProfile resolveArtistProfile(String id) =>
    artistProfiles[id] ?? _fallbackProfile;
