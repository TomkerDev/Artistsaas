import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Service de téléversement de médias via Supabase Storage.
///
/// Le client Supabase est initialisé une fois au démarrage de l'application
/// par `Supabase.initialize()` (dans `main_admin.dart`) à partir des variables
/// d'environnement `--dart-define=SUPABASE_URL` et `--dart-define=SUPABASE_ANON_KEY` :
/// ```sh
/// flutter build web --release \
///   --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
///
/// ⚠️ Les valeurs doivent être lues via `String.fromEnvironment` **dans un
/// contexte `const`**, sinon le compilateur ne les substitue pas et le service
/// démarre avec des chaînes vides (ce qui était la cause du 403 initial).
///
/// Le bucket public `artist-media` doit :
/// - avoir des **règles RLS** autorisant les uploads aux utilisateurs
///   authentifiés (ou public si le bucket est en lecture/écriture libre) ;
/// - avoir des **règles CORS** pour `PUT` et `POST` depuis `web.app`.
///
/// Si la connexion échoue malgré les defines corrects, un
/// `signInAnonymously()` est tenté automatiquement — le bucket `artist-media`
/// doit alors autoriser l'écriture aux `auth.role() == 'anonymous'`.
class SupabaseStorageService {
  SupabaseStorageService._();

  /// Nom du bucket public contenant les MP3 et pochettes.
  static const String _bucketName = 'artist-media';

  /// URL du projet Supabase, lue depuis `--dart-define=SUPABASE_URL`.
  ///
  /// La valeur doit impérativement rester **constante** : `String.fromEnvironment`
  /// n'est remplacé par le compilateur que dans un contexte `const`. Utiliser
  /// un getter non-const renvoie toujours la valeur par défaut (`''`).
  static const String _url = String.fromEnvironment('SUPABASE_URL');

  /// Clé publique lue depuis `--dart-define=SUPABASE_ANON_KEY`.
  static const String _publishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// URL du projet Supabase, ou `null` si absente du build.
  static String? get url => _url.isEmpty ? null : _url;

  /// Clé publique du projet Supabase, ou `null` si absente du build.
  static String? get publishableKey =>
      _publishableKey.isEmpty ? null : _publishableKey;

  /// Client Supabase partagé, initialisé via `Supabase.initialize()` dans
  /// `main_admin.dart`.
  ///
  /// On réutilise l'instance singleton de `Supabase.instance.client` plutôt
  /// qu'une créer manuellement : seul le singleton possède la session
  /// d'authentification (nécessaire pour les buckets avec RLS).
  static SupabaseClient get client => Supabase.instance.client;

  /// Vérifie que Supabase est correctement initialisé.
  ///
  /// Lève [StateError] si `SUPABASE_URL` ou `SUPABASE_ANON_KEY` sont absents
  /// ou vides — ce qui indique que les `--dart-define` de compilation manquent.
  static void ensureInitialized() {
    if (url == null) {
      throw StateError(
        'SUPABASE_URL est manquant. '
        'Compile with --dart-define=SUPABASE_URL=https://your-project.supabase.co',
      );
    }
    if (publishableKey == null) {
      throw StateError(
        'SUPABASE_ANON_KEY est manquant. '
        'Compile with --dart-define=SUPABASE_ANON_KEY=eyJ...',
      );
    }
  }

  /// S'assure qu'une session Supabase valide existe avant un upload.
  ///
  /// Si le client n'a pas de session (cas typique : l'utilisateur s'est
  /// authentifié via Firebase, pas Supabase), tente une **connexion
  /// anonyme**. Le bucket doit autoriser l'écriture aux utilisateurs
  /// anonymes (`auth.role() == 'anonymous'`).
  ///
  /// Si la connexion anonyme échoue, lève l'exception pour être affichée
  /// à l'utilisateur avec un message exploitable.
  static Future<void> ensureAuthenticated() async {
    final SupabaseClient client = Supabase.instance.client;
    final Session? session = client.auth.currentSession;
    if (session != null && !session.isExpired) {
      return; // ✅ déjà authentifié
    }
    try {
      await client.auth.signInAnonymously();
    } on Object catch (error) {
      throw StateError(
        'Impossible de créer une session Supabase (connexion anonyme échouée) : '
        '$error. Vérifiez que le bucket `artist-media` autorise les uploads '
        'aux utilisateurs anonymes ou authentifiés dans la console Supabase.',
      );
    }
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
  /// `upsert: true` évite les conflits 409 sur fichiers existants.
  /// Le `contentType` est détecté automatiquement via [_contentTypeFor].
  /// Une connexion Supabase anonyme est créée si nécessaire (voir [ensureAuthenticated]).
  ///
  /// Lève une [StateError] détaillée si le téléversement échoue
  /// (403 Forbidden, 404 bucket introuvable, 409 conflit, réseau, etc.).
  static Future<String> uploadMedia({
    required String artistId,
    required String fileName,
    required Uint8List bytes,
    String bucketName = _bucketName,
  }) async {
    // 1. Valider la configuration au moment de l'appel.
    ensureInitialized();

    // 2. S'assurer qu'une session Supabase est active.
    await ensureAuthenticated();

    final String path = '$artistId/$fileName';
    final String contentType = _contentTypeFor(fileName);

    try {
      await client.storage
          .from(bucketName)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      return client.storage.from(bucketName).getPublicUrl(path);
    } on StorageException catch (e) {
      throw _wrapStorageError(e, path, bucketName);
    } on PostgrestException catch (e) {
      throw StateError('Erreur Supabase lors de l\'upload de $path : $e');
    }
  }

  /// Type MIME déduit de l'extension du fichier.
  static String _contentTypeFor(String fileName) {
    final String ext = fileName.split('.').last.toLowerCase();
    if (ext == 'mp3') return 'audio/mpeg';
    if (ext == 'wav') return 'audio/wav';
    if (ext == 'm4a') return 'audio/mp4';
    if (ext == 'aac') return 'audio/aac';
    if (ext == 'flac') return 'audio/flac';
    if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
    if (ext == 'png') return 'image/png';
    if (ext == 'webp') return 'image/webp';
    return 'application/octet-stream';
  }

  /// Enveloppe une erreur Supabase en message exploitable par l'UI.
  static StateError _wrapStorageError(
    Object error,
    String path,
    String bucketName,
  ) {
    final String msg = error.toString();

    if (msg.contains('403') ||
        msg.contains('Forbidden') ||
        msg.contains('Unauthorized') ||
        msg.contains('not allowed')) {
      return StateError(
        'Accès refusé par Supabase Storage (403 Forbidden) pour '
        '\'$path\' dans le bucket \'$bucketName\'.\n\n'
        'Causes possibles :\n'
        '• Le bucket n\'existe pas ou le nom est incorrect\n'
        '• Les regles RLS du bucket refusent l\'ecriture\n'
        '• Aucune session Supabase valide\n'
        '• Les regles CORS bloquent l\'upload depuis le web\n\n'
        'Verifiez dans la console Supabase -> Storage -> Rules : '
        'autoriser write pour authenticated ou anon.',
      );
    }

    if (msg.contains('404') || msg.contains('not found')) {
      return StateError(
        'Bucket Supabase \'$bucketName\' introuvable. '
        'Verifiez le nom du bucket.',
      );
    }

    if (msg.contains('409') || msg.contains('Conflict')) {
      return StateError(
        'Conflit sur le fichier \'$path\'. '
        'Le fichier existe deja — upsert est active.',
      );
    }

    return StateError('Echec de l\'upload Supabase pour \'$path\' : $msg');
  }
}
