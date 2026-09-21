/// Mise en forme des durées pour l'affichage.
abstract final class DurationFormatter {
  /// Formate une durée en `m:ss`, ou `h:mm:ss` dès qu'elle atteint une heure.
  ///
  /// Une durée nulle ou négative est affichée `0:00`, ce qui couvre le cas d'une
  /// position de lecture non encore connue.
  static String format(Duration duration) {
    final int totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    final String twoDigitsSeconds = seconds.toString().padLeft(2, '0');
    if (hours == 0) {
      return '$minutes:$twoDigitsSeconds';
    }
    final String twoDigitsMinutes = minutes.toString().padLeft(2, '0');
    return '$hours:$twoDigitsMinutes:$twoDigitsSeconds';
  }
}
