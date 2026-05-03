import '../entities/work_entry_entity.dart';

/// Das WorkRepository ist die Schnittstelle (der Vertrag) für alle
/// Datenoperationen, die mit Arbeitseinträgen zu tun haben.
///
/// Diese abstrakte Klasse gehört zur Domain-Schicht. Sie definiert, was
/// getan werden kann, aber nicht wie es getan wird. Die konkrete
/// Implementierung befindet sich in der Data-Schicht (WorkRepositoryImpl).
///
/// Use Cases in der Domain-Schicht arbeiten ausschließlich gegen dieses
/// Repository, um von der Datenquelle (z.B. Firebase) entkoppelt zu sein.
abstract class WorkRepository {
  /// Ruft einen einzelnen Arbeitseintrag für ein bestimmtes Datum ab.
  ///
  /// Gibt eine WorkEntryEntity zurück. Wenn für diesen Tag noch kein
  /// Eintrag in der Datenquelle existiert, sollte die Implementierung
  /// eine leere, aber gültige WorkEntryEntity zurückgeben.
  Future<WorkEntryEntity> getWorkEntry(DateTime date);

  /// Speichert einen Arbeitseintrag.
  ///
  /// Diese Methode wird sowohl zum Erstellen neuer Einträge als auch
  /// zum Aktualisieren bestehender Einträge verwendet.
  Future<void> saveWorkEntry(WorkEntryEntity entry);

  /// Ruft eine Liste aller Arbeitseinträge für einen bestimmten Monat und ein bestimmtes Jahr ab.
  ///
  /// Nützlich für die Kalenderansicht und Monatsberichte.
  Future<List<WorkEntryEntity>> getWorkEntriesForMonth(int year, int month);

  /// Löscht einen Arbeitseintrag anhand seiner ID.
  Future<void> deleteWorkEntry(String entryId);
}