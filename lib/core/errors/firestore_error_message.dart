/// Traduction des erreurs Firestore en messages utilisables par l'interface.
///
/// Une requête composite exige un index déployé : tant qu'il manque,
/// Firestore répond `failed-precondition` (« The query requires an index »).
/// Renvoyer cette exception brute au public — c'est-à-dire son `toString()` —
/// affiche un détail technique et une consigne de déploiement qui ne concerne
/// que le développeur. L'application mobile affiche donc un message d'attente,
/// tandis que le panneau d'administration (outil de production) conserve la
/// consigne de déploiement.
library;

/// Message affiché quand un index composite est absent ou en construction.
const String missingFirestoreIndexMessage =
    'Contenu en cours de préparation : les index Firestore sont en cours de '
    'création. Réessayez dans quelques instants.';

/// `true` si [error] signale un index composite absent ou en cours de création.
///
/// Reconnaissance par texte plutôt que par type : l'erreur remonte imbriquée
/// (`FirebaseException` enveloppée dans une exception métier) et seule la chaîne
/// reste stable d'une couche à l'autre.
bool isMissingFirestoreIndex(Object? error) {
  final String raw = error?.toString() ?? '';
  return raw.contains('failed-precondition') ||
      raw.contains('requires an index');
}

/// Message d'interface correspondant à [error].
///
/// [fallback] est repris tel quel pour une panne classique : l'appelant reste
/// maître de la formulation métier de son écran.
String firestoreErrorMessage(Object? error, {required String fallback}) =>
    isMissingFirestoreIndex(error) ? missingFirestoreIndexMessage : fallback;

/// Détail technique affichable sous le message d'erreur.
///
/// Vide pour un index manquant (le message d'attente suffit et la trace brute
/// est précisément ce qu'il ne faut pas montrer), borné sinon : une pile
/// Firestore complète n'apporte rien de lisible à l'utilisateur.
String firestoreErrorDetail(Object? error, {int maxLength = 120}) {
  if (isMissingFirestoreIndex(error)) {
    return '';
  }
  final String raw = error?.toString() ?? 'Erreur inconnue.';
  return raw.length <= maxLength ? raw : '${raw.substring(0, maxLength)}…';
}