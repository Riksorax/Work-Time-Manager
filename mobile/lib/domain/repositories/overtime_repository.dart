/// Das Repository für die Verwaltung des Überstundensaldos.
/// Es entkoppelt die Anwendungslogik von der konkreten Datenspeicherung.
abstract class OvertimeRepository {
  /// Ruft den aktuellen Überstundensaldo ab (synchron, aus Cache).
  Duration getOvertime();

  /// Speichert den neuen Überstundensaldo.
  ///
  /// Mit [keepLastUpdated] `true` bleibt das Datum der letzten Aktualisierung
  /// unverändert, auch wenn das Backend es beim Speichern sonst auf "jetzt"
  /// setzt (nachträgliches Beenden eines Vortags, #385/#406). Lokale
  /// Implementierungen schreiben das Datum in dieser Methode ohnehin nie.
  Future<void> saveOvertime(Duration overtime, {bool keepLastUpdated = false});

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
