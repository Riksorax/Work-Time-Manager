/// Das Repository für die Verwaltung des Überstundensaldos.
/// Es entkoppelt die Anwendungslogik von der konkreten Datenspeicherung.
abstract class OvertimeRepository {
  /// Ruft den aktuellen Überstundensaldo ab.
  Duration getOvertime();

  /// Speichert den neuen Überstundensaldo.
  Future<void> saveOvertime(Duration overtime);
}
