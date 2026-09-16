import '../../domain/entities/work_entry_entity.dart';
import '../../domain/repositories/work_repository.dart';
import '../datasources/remote/firestore_datasource.dart';
import '../models/work_entry_model.dart';

/// Die konkrete Implementierung des WorkRepository-Vertrags.
/// Sie ist verantwortlich für die Umwandlung zwischen Domain-Entities und Daten-Models.
class WorkRepositoryImpl implements WorkRepository {
  final FirestoreDataSource dataSource;
  final String userId;

  /// Aktives Arbeitszeit-Profil (siehe #138) - `null`/`'default'` verwendet
  /// den bestehenden, nicht migrierten Datenpfad.
  final String? profileId;

  WorkRepositoryImpl({
    required this.dataSource,
    required this.userId,
    this.profileId,
  });

  @override
  Future<WorkEntryEntity> getWorkEntry(DateTime date) async {
    final model = await dataSource.getWorkEntry(userId, date, profileId: profileId);
    // Das Model ist bereits eine Entity, daher ist keine Konvertierung nötig.
    // Wenn das Model null ist (kein Eintrag in Firestore), wird ein leeres Model zurückgegeben.
    return model ?? WorkEntryModel.empty(date);
  }

  @override
  Future<void> saveWorkEntry(WorkEntryEntity entry) async {
    // Wandle die Domain-Entity in ein speicherbares Firestore-Model um.
    final model = WorkEntryModel.fromEntity(entry);
    await dataSource.saveWorkEntry(userId, model, profileId: profileId);
  }

  @override
  Future<List<WorkEntryEntity>> getWorkEntriesForMonth(int year, int month) async {
    // Die von der Datenquelle zurückgegebenen Models sind bereits Entities.
    return await dataSource.getWorkEntriesForMonth(userId, year, month, profileId: profileId);
  }

  @override
  Future<void> deleteWorkEntry(String entryId) async {
    await dataSource.deleteWorkEntry(userId, entryId, profileId: profileId);
  }
}
