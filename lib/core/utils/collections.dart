/// Utilitaires de collection écrits en Dart pur.
///
/// L'application utilise `listEquals` de `package:flutter/foundation.dart`, mais
/// la couche `domain/` ne doit dépendre que du SDK Dart : ces fonctions y
/// remplacent donc les utilitaires Flutter équivalents.
library;

/// Compare deux listes élément par élément à l'aide de l'opérateur `==`.
///
/// Deux listes `null` sont considérées comme égales, une liste `null` et une
/// liste vide comme différentes.
bool itemsEqual<T>(List<T>? first, List<T>? second) {
  if (identical(first, second)) {
    return true;
  }
  if (first == null || second == null || first.length != second.length) {
    return false;
  }
  for (int index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}
