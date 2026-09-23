/// Service d'authentification du panneau d'administration.
///
/// Contrat de domaine : l'écran de connexion ne connaît ni Firebase ni le
/// mécanisme de vérification des privilèges. Toute dérogation (identifiants
/// refusés, compte non administrateur, service injoignable) se traduit par une
/// `AdminException` portant un message prêt à être affiché.
abstract interface class AdminAuthService {
  /// `true` lorsqu'un administrateur est déjà connecté (session courante).
  bool get isSignedIn;

  /// Connexion e-mail / mot de passe réservée aux administrateurs.
  ///
  /// Lève une `AdminException` si les identifiants sont refusés ou si le compte
  /// n'est pas celui d'un administrateur.
  Future<void> signIn({required String email, required String password});

  /// Déconnexion de la session d'administration courante.
  Future<void> signOut();
}
