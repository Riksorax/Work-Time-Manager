import '../entities/work_entry_entity.dart';
import '../repositories/work_repository.dart';

/// Use Case zum Speichern eines Arbeitseintrags.
class SaveWorkEntry {
  final WorkRepository _repository;

  SaveWorkEntry(this._repository);

  /// Führt den Use Case aus und speichert die übergebene Entity.
  Future<void> call(WorkEntryEntity entry) async {
    await _repository.saveWorkEntry(entry);
  }
}