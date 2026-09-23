import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Service de téléversement de médias via Supabase Storage.
///
/// Initialisation paresseuse : le premier appel à [ensureInitialized]
/// configure le client Supabase à partir des variables d'environnement
/// `--dart-define=SUPABASE_URL` et `--dart-define=SUPABASE_ANON_KEY`.
///
/// En production, ces valeurs sont passées au build web :
/// ```sh
/// flutter build web --release \
///   --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
///
/// Le bucket public `artist-media` doit avoir les règles CORS et de
/// lecture publiques configurées dans la console Supabase.
class SupabaseStorageService {
  SupabaseStorageService._();

  static const String _bucketName = 'artist-media';

  /// Instance client paresseusement initialisée.
  static SupabaseClient? _client;

  /// URL du projet Supabase, lue depuis `--dart-define=SUPABASE_URL`.
  ///
  /// La valeur doit impérativement rester **constante** : `String.fromEnvironment`
  /// n'est remplacé par le compilateur que dans un contexte `const`. Appelé
  /// hors contexte const, il renvoie toujours la valeur par défaut (`''`), ce qui
  /// laisse le client Supabase non configuré dans le build publié.
  static const String _url = String.fromEnvironment('SUPABASE_URL');

  /// Clé publique lue depuis `--dart-define=SUPABASE_ANON_KEY`.
  static const String _publishableKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// URL du projet Supabase, ou `null` si absente du build.
  static String? get url => _url.isEmpty ? null : _url;

  /// Clé publique du projet Supabase, ou `null` si absente du build.
  static String? get publishableKey =>
      _publishableKey.isEmpty ? null : _publishableKey;

  /// Client Supabase, initialisé au premier besoin.
  static SupabaseClient get client {
    _client ??= _initClient();
    return _client!;
  }

  /// Initialise le client Supabase.
  ///
  /// Lève [StateError] si `SUPABASE_URL` ou `SUPABASE_ANON_KEY` sont
  /// absents — ce qui indique que les define de compilation sont manquants.
  static SupabaseClient _initClient() {
    final String? urlValue = url;
    final String? key = publishableKey;
    if (urlValue == null || urlValue.isEmpty) {
      throw StateError(
        'SUPABASE_URL est manquant. '
        'Run with --dart-define=SUPABASE_URL=https://your-project.supabase.co',
      );
    }
    if (key == null || key.isEmpty) {
      throw StateError(
        'SUPABASE_ANON_KEY est manquant. '
        'Run with --dart-define=SUPABASE_ANON_KEY=eyJ...',
      );
    }
    return SupabaseClient(urlValue, key);
  }

  /// S'assure que le client Supabase est initialisé (appelé implicitement
  /// par [client]).
  ///
  /// Peut être appelé explicitement au démarrage de l'écran d'upload si
  /// on souhaite valider la configuration avant tout téléversement.
  static void ensureInitialized() {
    client;
  }

  /// Téléverse un fichier dans le bucket public `artist-media`.
  ///
  /// Le fichier est stocké sous le chemin `$artistId/$fileName`.
  /// La méthode retourne l'URL publique directe du fichier une fois le
  /// téléversement terminé.
  ///
  /// Paramètres :
  /// - [artistId] : identifiant de l'artiste (`artist_1`, `dilson_le_mustang`, …).
  /// - [fileName] : nom de fichier tel qu'il apparaîtra dans le bucket.
  /// - [bytes]   : contenu binaire du fichier (Uint8List issu de `file_picker`).
  /// - [bucketName] : nom du bucket (par défaut `'artist-media'`).
  ///
  /// Lève une exception si le téléversement échoue (réseau, bucket introuvable,
  /// règles de stockage).
  static Future<String> uploadMedia({
    required String artistId,
    required String fileName,
    required Uint8List bytes,
    String bucketName = _bucketName,
  }) async {
    final String path = '$artistId/$fileName';
    await client.storage.from(bucketName).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/octet-stream',
            upsert: false,
          ),
        );
    return client.storage.from(bucketName).getPublicUrl(path);
  }
}
