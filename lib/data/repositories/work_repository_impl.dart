import '../../domain/entities/work_entry_entity.dart';
import '../../domain/repositories/work_repository.dart';
import '../datasources/remote/firestore_datasource.dart';
import '../models/work_entry_model.dart';

/// Die konkrete Implementierung des WorkRepository-Vertrags aus der Domain-Schicht.
///
/// Diese Klasse koordiniert die Datenoperationen, indem sie die entsprechende
/// Datenquelle (DataSource) aufruft. Sie ist auch für die Umwandlung
/// zwischen reinen Entities (Domain) und Models (Data) zuständig.
class WorkRepositoryImpl implements WorkRepository {
  final FirestoreDataSource _dataSource;
  final String _userId;

  /// Die Abhängigkeiten (FirestoreDataSource und userId) werden
  /// über den Konstruktor injiziert. Der Use Case muss die userId nicht kennen,
  /// das ist die Aufgabe des Repositories.
  WorkRepositoryImpl({
    required FirestoreDataSource dataSource,
    required String userId,
  })  : _dataSource = dataSource,
        _userId = userId;

  /// Ruft einen Arbeitseintrag ab.
  @override
  Future<WorkEntryEntity> getWorkEntry(DateTime date) async {
    // 1. Rufe das datenbankspezifische Model von der Datenquelle ab.
    final workEntryModel = await _dataSource.getWorkEntry(_userId, date);

    // 2. Wandle das Model in eine Entity um. Da `WorkEntryModel` von
    // `WorkEntryEntity` erbt, ist keine explizite Konvertierung nötig.
    // Das Model IST bereits eine gültige Entity.
    return workEntryModel;
  }

  /// Speichert einen Arbeitseintrag.
  @override
  Future<void> saveWorkEntry(WorkEntryEntity entry) async {
    // 1. Die Methode erhält eine reine WorkEntryEntity aus der Domain-Schicht.
    // Wir müssen sie in ein WorkEntryModel umwandeln, bevor wir sie an die
    // Datenquelle weitergeben können, da nur das Model die toFirestore-Logik enthält.
    final workEntryModel = WorkEntryModel.fromEntity(entry);

    // 2. Rufe die Speichermethode der Datenquelle mit dem Model auf.
    await _dataSource.saveWorkEntry(_userId, workEntryModel);
  }

  /// Ruft alle Arbeitseinträge für einen bestimmten Monat ab.
  @override
  Future<List<WorkEntryEntity>> getWorkEntriesForMonth(
      int year, int month) async {
    // Rufe die Liste der Models von der Datenquelle ab.
    final models =
    await _dataSource.getWorkEntriesForMonth(_userId, year, month);

    // Eine `List<WorkEntryModel>` ist auch eine `List<WorkEntryEntity>`,
    // da das Model eine Unterklasse der Entity ist.
    // Wir können die Liste direkt zurückgeben.
    return models;
  }
}