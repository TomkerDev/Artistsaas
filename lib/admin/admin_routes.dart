/// Routes et constantes partagées entre les écrans d'administration.
///
/// Ce fichier brise la dépendance cyclique entre [admin_login_page.dart]
/// et [admin_upload_page.dart] : aucun des deux n'importe l'autre, ils
/// dépendent tous deux de ce fichier.
library;

import '../core/constants/artist_config.dart';

/// Constantes d'identification des écrans.
class AdminScreenIds {
  AdminScreenIds._();

  static const String login = 'admin_login';
  static const String upload = 'admin_upload';
  static const String store = 'admin_store';
}

/// Options d'artistes pour le sélecteur de l'écran d'upload.
final class AdminArtistOption {
  const AdminArtistOption({
    required this.id,
    required this.name,
    required this.label,
  });

  final String id;
  final String name;

  /// Label partenaire, écrit dans le champ `label` du document Firestore.
  final String label;
}

/// Artistes de démonstration encore non publiés : ils restent sélectionnables
/// pour ne pas casser les comptes de test existants.
const List<AdminArtistOption> _placeholderArtists = <AdminArtistOption>[
  AdminArtistOption(id: 'artist_1', name: 'Artist 1', label: 'Tete Roh Studio'),
  AdminArtistOption(id: 'artist_2', name: 'Artist 2', label: 'Tete Roh Studio'),
  AdminArtistOption(id: 'artist_3', name: 'Artist 3', label: 'Tete Roh Studio'),
  AdminArtistOption(id: 'artist_4', name: 'Artist 4', label: 'Tete Roh Studio'),
  AdminArtistOption(id: 'artist_5', name: 'Artist 5', label: 'Tete Roh Studio'),
  AdminArtistOption(id: 'artist_6', name: 'Artist 6', label: 'Tete Roh Studio'),
  AdminArtistOption(id: 'artist_7', name: 'Artist 7', label: 'Tete Roh Studio'),
  AdminArtistOption(id: 'artist_8', name: 'Artist 8', label: 'Tete Roh Studio'),
  AdminArtistOption(id: 'artist_9', name: 'Artist 9', label: 'Tete Roh Studio'),
  AdminArtistOption(
    id: 'artist_10',
    name: 'Artist 10',
    label: 'Tete Roh Studio',
  ),
];

/// Liste complète des artistes disponibles dans le sélecteur.
///
/// La source est le registre central (`artist_config.dart`) : le panneau ne
/// duplique plus la liste des artistes, et le libellé affiché vient du même
/// endroit que celui lu par l'application mobile. Les entrées de démonstration
/// complètent la liste.
List<AdminArtistOption> get adminArtistOptions => <AdminArtistOption>[
      for (final ArtistProfile profile in artistProfiles.values)
        AdminArtistOption(
          id: profile.id,
          name: profile.stageName,
          label: profile.label,
        ),
      ..._placeholderArtists,
    ];

/// Option correspondant à [artistId], `null` si l'artiste est inconnu.
AdminArtistOption? adminArtistFor(String artistId) {
  for (final AdminArtistOption option in adminArtistOptions) {
    if (option.id == artistId) {
      return option;
    }
  }
  return null;
}

/// Libellé lisible d'un artiste, avec repli sur l'identifiant brut.
String adminArtistName(String artistId) =>
    adminArtistFor(artistId)?.name ?? artistId;
