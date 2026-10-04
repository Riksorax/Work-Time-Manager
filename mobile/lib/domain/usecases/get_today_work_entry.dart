import '../entities/work_entry_entity.dart';
import '../repositories/work_repository.dart';

/// Use Case, um den Arbeitseintrag für den aktuellen Tag abzurufen.
class GetTodayWorkEntry {
  final WorkRepository _repository;
  final DateTime Function() _clock;

  /// [clock] liefert "jetzt"; Tests und der Tageswechsel (#379) injizieren
  /// hier die Uhr aus `clockProvider`.
  GetTodayWorkEntry(this._repository,
      {DateTime Function() clock = DateTime.now})
      : _clock = clock;

  /// Führt den Use Case aus.
  Future<WorkEntryEntity> call() async {
    return await _repository.getWorkEntry(_clock());
  }
}
