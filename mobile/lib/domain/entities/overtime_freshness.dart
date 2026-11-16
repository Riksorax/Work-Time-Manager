/// Herkunft des Gleitzeit-Saldos, den ein `OvertimeRepository` zuletzt
/// geliefert hat (#573).
enum OvertimeFreshness {
  /// Frisch geladen oder gespeichert (bzw. lokal im Gast-Modus).
  current,

  /// Der Server war nicht erreichbar; es gilt der zuletzt bekannte Stand, den
  /// das Gerät nach dem letzten erfolgreichen Laden/Speichern gemerkt hat.
  cached,

  /// Der Server war nicht erreichbar und es gibt keinen gemerkten Stand. Der
  /// Saldo ist unbekannt und darf nicht als 0 angezeigt werden.
  unknown,
}
