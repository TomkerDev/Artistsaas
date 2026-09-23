/// Routes et constantes partagées entre les écrans d'administration.
///
/// Ce fichier brise la dépendance cyclique entre [admin_login_page.dart]
/// et [admin_upload_page.dart] : aucun des deux n'importe l'autre, ils
/// dépendent tous deux de ce fichier.
///
/// Constantes d'identification des écrans.
class AdminScreenIds {
  AdminScreenIds._();

  static const String login = 'admin_login';
  static const String upload = 'admin_upload';
}

/// Options d'artistes pour le sélecteur de l'écran d'upload.
final class AdminArtistOption {
  const AdminArtistOption({required this.id, required this.name});
  final String id;
  final String name;
}

/// Liste complète des artistes disponibles dans le sélecteur.
const List<AdminArtistOption> allAdminArtists = <AdminArtistOption>[
  AdminArtistOption(id: 'dilson_le_mustang', name: 'Dilson Le Mustang'),
  AdminArtistOption(id: 'jethsonat', name: 'Jethsonat'),
  AdminArtistOption(id: 'artist_1', name: 'Artist 1'),
  AdminArtistOption(id: 'artist_2', name: 'Artist 2'),
  AdminArtistOption(id: 'artist_3', name: 'Artist 3'),
  AdminArtistOption(id: 'artist_4', name: 'Artist 4'),
  AdminArtistOption(id: 'artist_5', name: 'Artist 5'),
  AdminArtistOption(id: 'artist_6', name: 'Artist 6'),
  AdminArtistOption(id: 'artist_7', name: 'Artist 7'),
  AdminArtistOption(id: 'artist_8', name: 'Artist 8'),
  AdminArtistOption(id: 'artist_9', name: 'Artist 9'),
  AdminArtistOption(id: 'artist_10', name: 'Artist 10'),
];
