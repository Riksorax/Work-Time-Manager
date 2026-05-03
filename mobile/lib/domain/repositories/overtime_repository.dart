/// Das Repository für die Verwaltung des Überstundensaldos.
/// Es entkoppelt die Anwendungslogik von der konkreten Datenspeicherung.
abstract class OvertimeRepository {
  /// Ruft den aktuellen Überstundensaldo ab.
  Duration getOvertime();

  /// Speichert den neuen Überstundensaldo.
  Future<void> saveOvertime(Duration overtime);

  /// Ruft das Datum der letzten Überstunden-Aktualisierung ab.
  DateTime? getLastUpdateDate();

  /// Speichert das Datum der letzten Überstunden-Aktualisierung.
  Future<void> saveLastUpdateDate(DateTime date);
}
