import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/firebase_admin_auth_data_source.dart';
import '../data/datasources/firebase_track_publisher.dart';
import '../domain/services/admin_auth_service.dart';
import '../domain/services/track_publisher.dart';

/// Service d'authentification admin concret (Firebase Auth).
///
/// Le domaine e-mail autorisé peut être resserré à la compilation via
/// `--dart-define=ADMIN_EMAIL_DOMAIN=tomker.dev` ; sans define, la seule
/// vérification active est le custom claim `admin: true` du projet Firebase.
final Provider<AdminAuthService> adminAuthServiceProvider =
    Provider<AdminAuthService>((Ref ref) {
      const String domain = String.fromEnvironment('ADMIN_EMAIL_DOMAIN');
      return FirebaseAdminAuthService(
        auth: FirebaseAuth.instance,
        authorizedDomain: domain.isEmpty ? null : domain,
      );
    });

/// Session d'administration courante, exposée sous forme de flux.
///
/// L'écran de connexion observe ce flux pour rediriger vers `AdminUploadPage`
/// dès qu'un administrateur est authentifié (y compris une session déjà
/// ouverte dans l'onglet, restée active après un rechargement de page).
final StreamProvider<User?> adminSessionProvider = StreamProvider<User?>(
  (Ref ref) => FirebaseAuth.instance.authStateChanges(),
);

/// Sélecteur de fichiers concret (`file_picker`), remplaçable en test.
///
/// Le contract est minimal : un filtre de type + la sélection multiple. Les
/// tests d'écran substituent un double qui renvoie des `PlatformFile` fabriqués.
final Provider<AdminFilePicker> adminFilePickerProvider =
    Provider<AdminFilePicker>((Ref ref) => const FilePickerAdminFilePicker());

/// Publication de nouveautés concrète (Storage + Firestore).
final Provider<TrackPublisher> trackPublisherProvider = Provider<TrackPublisher>(
  (Ref ref) => FirebaseTrackPublisher(
    storage: FirebaseStorage.instance,
    firestore: FirebaseFirestore.instance,
  ),
);

/// Abstraction minimale du sélecteur de fichiers, portée par la présentation.
///
/// `file_picker` étant une dépendance de `data/`-niveau (API statique), cette
/// indirection permet aux widget tests de piloter la sélection sans ouvrir de
/// boîte de dialogue système.
abstract interface class AdminFilePicker {
  /// Sélectionne un MP3 unique ; renvoie `null` si l'utilisateur annule.
  Future<PlatformFile?> pickAudio();

  /// Sélectionne une pochette unique ; renvoie `null` si l'utilisateur annule.
  Future<PlatformFile?> pickCover();
}

/// Implémentation `file_picker` du sélecteur de fichiers.
final class FilePickerAdminFilePicker implements AdminFilePicker {
  const FilePickerAdminFilePicker();

  @override
  Future<PlatformFile?> pickAudio() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['mp3'],
      withData: true,
    );
    return result?.files.single;
  }

  @override
  Future<PlatformFile?> pickCover() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    return result?.files.single;
  }
}
