/// Dünne Abstraktion über die Store-Bewertungsabfrage (Google-Play-In-App-
/// Review), damit Use Cases und ViewModels ohne Plugin testbar bleiben.
abstract class ReviewRequester {
  /// Ob die Abfrage auf dieser Plattform verfügbar ist (nur Android, Play
  /// Services vorhanden). Wirft nie.
  Future<bool> isAvailable();

  /// Löst den Bewertungsdialog aus. Google entscheidet, ob er tatsächlich
  /// erscheint. Wirft nie.
  Future<void> requestReview();
}
