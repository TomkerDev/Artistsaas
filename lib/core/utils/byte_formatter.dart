/// Mise en forme des tailles de fichiers pour l'affichage.
abstract final class ByteFormatter {
  /// Formate un nombre d'octets en Ko, Mo ou Go avec une décimale.
  ///
  /// En dessous d'un kilooctet, la valeur est affichée en octets.
  static String format(int bytes) {
    if (bytes < 1024) {
      return '$bytes o';
    }
    final double kiloBytes = bytes / 1024;
    if (kiloBytes < 1024) {
      return '${kiloBytes.toStringAsFixed(1)} Ko';
    }
    final double megaBytes = kiloBytes / 1024;
    if (megaBytes < 1024) {
      return '${megaBytes.toStringAsFixed(1)} Mo';
    }
    return '${(megaBytes / 1024).toStringAsFixed(1)} Go';
  }
}
