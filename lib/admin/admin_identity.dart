/// Artiste de travail du panneau d'administration.
///
/// Rôle et artiste sont lus depuis `admin_users/{uid}` — le même document que
/// consulte l'écran d'upload. Les formeriels événements et merchandise
/// doivent écrire le `artistId` correspondant, sans quoi leurs documents
/// restent invisibles : les écrans mobiles filtrent sur ce champ.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Artiste sélectionné dans la barre latérale du panneau.
///
/// Publié par l'écran d'upload (qui porte le sélecteur) et consommé par les
/// formulaires billetterie et merchandise, afin qu'un événement soit rattaché
/// au même artiste que les titres. Sans cela, chaque écran choisirait son
/// artiste indépendamment et les documents seraient dispersés.
final ValueNotifier<String?> shellArtistIdNotifier = ValueNotifier<String?>(
  null,
);

/// Identifiants des rôles gérés par `admin_users`.
abstract final class AdminRole {
  /// Compte d'agence : peut basculer entre tous les artistes.
  static const String agencyAdmin = 'agency_admin';

  /// Compte d'artiste : verrouillé sur son `assignedArtistId`.
  static const String artist = 'artist';

  /// Valeur d'`assignedArtistId` donnant accès à tous les artistes.
  static const String allArtists = 'all';
}

/// Identité de l'administrateur connecté, lue depuis `admin_users/{uid}`.
///
/// Sans document, le compte est traité comme artiste sans artiste assigné :
/// c'est le mode le plus restrictif, et il évite qu'une erreur réseau
/// n'ouvre par inadvertance la publication pour tous les artistes.
final ValueNotifier<AdminIdentity?> adminIdentityNotifier =
    ValueNotifier<AdminIdentity?>(null);

/// Rôle et artiste effectif d'un compte du panneau.
@immutable
class AdminIdentity {
  const AdminIdentity({required this.role, required this.assignedArtistId});

  /// Rôle brut tel que stocké dans Firestore.
  final String role;

  /// Artiste assigné ; vide ou `'all'` pour un compte d'agence.
  final String assignedArtistId;

  /// `true` si le compte peut basculer entre tous les artistes.
  bool get isAgencyAdmin => role == AdminRole.agencyAdmin;

  /// `true` si l'identité n'a pas encore été lue.
  bool get isResolved => this != loading;

  /// Identité transitoire, avant lecture de Firestore.
  static const AdminIdentity loading = AdminIdentity(
    role: AdminRole.artist,
    assignedArtistId: '',
  );

  /// Charger l'identité de l'utilisateur Firebase courant.
  ///
  /// Renvoie [loading] si aucun compte n'est connecté, et se rabat sur un rôle
  /// artiste restreint si le document est absent ou illisible.
  static Future<AdminIdentity> load([FirebaseFirestore? firestore]) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return loading;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await (firestore ??
              FirebaseFirestore.instance)
          .collection('admin_users')
          .doc(user.uid)
          .get();
      final Map<String, dynamic>? data = doc.data();
      if (!doc.exists || data == null) {
        return loading;
      }
      return AdminIdentity(
        role: data['role'] as String? ?? AdminRole.artist,
        assignedArtistId: data['assignedArtistId'] as String? ?? '',
      );
    } on FirebaseException {
      return loading;
    }
  }
}