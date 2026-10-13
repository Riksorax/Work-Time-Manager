/// Lokaler Zustand der einmaligen Bewertungsanfrage.
///
/// Bewusst ohne Firestore und ohne Login-Bezug: Erstnutzungsdatum und Flag
/// liegen nur auf dem Gerät (SharedPreferences), damit die Anfrage auch für
/// ausgeloggte Nutzer funktioniert und nie ein Backend-Zugriff entsteht.
abstract class ReviewPromptRepository {
  /// Kalendertag der Erstnutzung (lokale Mitternacht) oder `null`, wenn noch
  /// nicht erfasst.
  DateTime? getFirstUseDate();

  /// Speichert den Kalendertag der Erstnutzung. Überschreibt nichts, wenn
  /// bereits ein Datum vorhanden ist.
  Future<void> saveFirstUseDateIfAbsent(DateTime date);

  /// Ob die Bewertungsanfrage schon einmal ausgelöst wurde.
  bool wasPrompted();

  /// Merkt sich dauerhaft, dass die Anfrage ausgelöst wurde.
  Future<void> markPrompted();
}
