import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/services/admin_auth_service.dart';

/// Authentification Firebase (e-mail / mot de passe) réservée aux
/// administrateurs.
///
/// Deux garde-fous sont appliqués :
/// 1. seuls les comptes dont l'adresse appartient au domaine autorisé peuvent
///    ouvrir une session (l'attribut custom claim `admin: true` reste la
///    vérification de référence dès qu'il est configuré côté projet Firebase) ;
/// 2. les erreurs Firebase sont traduites en `AdminException` portant un
///    message compréhensible, jamais l'exception brute.
///
/// L'instance [FirebaseAuth] est injectable : les tests fournissent un double,
/// la production utilise [FirebaseAuth.instance].
class FirebaseAdminAuthService implements AdminAuthService {
  FirebaseAdminAuthService({FirebaseAuth? auth, this.authorizedDomain})
    : _auth = auth;

  /// Instance Firebase Auth (injectable pour les tests).
  final FirebaseAuth? _auth;

  /// Domaine e-mail autorisé, `null` pour accepter tout compte vérifié par les
  /// custom claims. Exemple : `tomker.dev` → seuls `xxx@tomker.dev` passent.
  final String? authorizedDomain;

  FirebaseAuth get _authInstance => _auth ?? FirebaseAuth.instance;

  @override
  bool get isSignedIn => _authInstance.currentUser != null;

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      final UserCredential credential = await _authInstance
          .signInWithEmailAndPassword(email: email, password: password);
      final User? user = credential.user;
      if (user == null) {
        await _authInstance.signOut();
        throw const AdminException(
          'Connexion impossible : aucun compte n\'a été retourné.',
        );
      }
      await _ensureAdmin(user);
    } on AdminException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AdminException(_describe(error), cause: error);
    } on Object catch (error) {
      throw AdminException(
        'Connexion impossible : le service d\'authentification est injoignable.',
        cause: error,
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _authInstance.signOut();
    } on Object catch (error) {
      throw AdminException('Déconnexion impossible.', cause: error);
    }
  }

  /// Vérifie que le compte connecté a les droits d'administration.
  ///
  /// Le contrôle principal repose sur le custom claim `admin` défini depuis la
  /// console ou la CLI (`admin stripe` côté serveur). À défaut de claim, le
  /// domaine e-mail autorisé sert de filet de secours.
  Future<void> _ensureAdmin(User user) async {
    final IdTokenResult token = await user.getIdTokenResult(true);
    final Object? claim = token.claims?['admin'];
    if (claim == true) {
      return;
    }
    final String? domain = user.email?.split('@').last.toLowerCase();
    final String? expected = authorizedDomain?.toLowerCase();
    if (expected != null && domain == expected) {
      return;
    }
    // Le compte n'est pas administrateur : la session est immédiatement
    // refermée pour ne pas laisser un accès « à moitié » ouvert.
    await _authInstance.signOut();
    throw const AdminException(
      'Ce compte n\'a pas les droits d\'administration.',
    );
  }

  /// Traduit les erreurs Firebase Auth en messages affichables.
  static String _describe(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Adresse e-mail invalide.';
      case 'user-disabled':
        return 'Ce compte a été désactivé.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou mot de passe incorrect.';
      case 'too-many-requests':
        return 'Trop de tentatives : réessayez dans quelques instants.';
      case 'network-request-failed':
        return 'Réseau injoignable : vérifiez votre connexion.';
      default:
        return 'Connexion impossible (${error.code}).';
    }
  }
}
