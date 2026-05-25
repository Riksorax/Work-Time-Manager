/// Das Repository für die Verwaltung des Überstundensaldos.
/// Es entkoppelt die Anwendungslogik von der konkreten Datenspeicherung.
abstract class OvertimeRepository {
  /// Ruft den aktuellen Überstundensaldo ab (synchron, aus Cache).
  Duration getOvertime();

  /// Speichert den neuen Überstundensaldo.
  Future<void> saveOvertime(Duration overtime);

  /// Ruft das Datum der letzten Überstunden-Aktualisierung ab (synchron, aus Cache).
  DateTime? getLastUpdateDate();

  /// Speichert das Datum der letzten Überstunden-Aktualisierung.
  Future<void> saveLastUpdateDate(DateTime date);

  /// Stellt sicher, dass der Überstundensaldo aus dem Backend geladen ist,
  /// und gibt ihn zurück. Remote-Implementierungen überschreiben diese Methode
  /// mit einem echten async-Abruf; lokale Implementierungen delegieren auf [getOvertime].
  Future<Duration> ensureOvertimeLoaded() async => getOvertime();

  /// Stellt sicher, dass das letzte Update-Datum aus dem Backend geladen ist.
  /// Entspricht [ensureOvertimeLoaded] für das Update-Datum.
  Future<DateTime?> ensureLastUpdateLoaded() async => getLastUpdateDate();
}
