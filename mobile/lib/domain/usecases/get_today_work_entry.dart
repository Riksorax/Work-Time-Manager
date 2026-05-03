import '../entities/work_entry_entity.dart';
import '../repositories/work_repository.dart';

/// Use Case, um den Arbeitseintrag für den aktuellen Tag abzurufen.
class GetTodayWorkEntry {
  final WorkRepository _repository;

  GetTodayWorkEntry(this._repository);

  /// Führt den Use Case aus.
  Future<WorkEntryEntity> call() async {
    return await _repository.getWorkEntry(DateTime.now());
  }
}