import '../entities/work_entry_entity.dart';
import '../repositories/work_repository.dart';

/// Use Case, um alle Arbeitseinträge für einen gegebenen Monat abzurufen.
class GetWorkEntriesForMonth {
  final WorkRepository _repository;

  GetWorkEntriesForMonth(this._repository);

  /// Führt den Use Case aus.
  Future<List<WorkEntryEntity>> call(int year, int month) async {
    return await _repository.getWorkEntriesForMonth(year, month);
  }
}