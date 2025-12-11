import '../../domain/entities/work_entry_entity.dart';
import '../../domain/repositories/work_repository.dart';
import 'package:flutter_work_time/core/utils/logger.dart';

/// Hybrid Repository, das automatisch zwischen Firebase und Local wechselt.
///
/// - Wenn userId vorhanden: Nutze Firebase (Cloud-Sync)
/// - Wenn kein userId: Nutze Local (SharedPreferences)
class HybridWorkRepositoryImpl implements WorkRepository {
  final WorkRepository _firebaseRepository;
  final WorkRepository _localRepository;
  final String? _userId;

  HybridWorkRepositoryImpl({
    required WorkRepository firebaseRepository,
    required WorkRepository localRepository,
    required String? userId,
  })  : _firebaseRepository = firebaseRepository,
        _localRepository = localRepository,
        _userId = userId;

  /// Gibt das aktive Repository zurück
  WorkRepository get _activeRepository {
    if (_userId != null && _userId!.isNotEmpty) {
      logger.i('[HybridWorkRepository] Verwende Firebase (User: $_userId)');
      return _firebaseRepository;
    } else {
      logger.i('[HybridWorkRepository] Verwende Local (Offline)');
      return _localRepository;
    }
  }

  @override
  Future<WorkEntryEntity> getWorkEntry(DateTime date) async {
    return await _activeRepository.getWorkEntry(date);
  }

  @override
  Future<List<WorkEntryEntity>> getWorkEntriesForMonth(int year, int month) async {
    return await _activeRepository.getWorkEntriesForMonth(year, month);
  }

  @override
  Future<void> saveWorkEntry(WorkEntryEntity entry) async {
    await _activeRepository.saveWorkEntry(entry);
  }

  @override
  Future<void> deleteWorkEntry(String entryId) async {
    await _activeRepository.deleteWorkEntry(entryId);
  }

  /// Gibt true zurück, wenn Firebase verwendet wird
  bool get isUsingFirebase => _userId != null && _userId!.isNotEmpty;

  /// Gibt true zurück, wenn Local verwendet wird
  bool get isUsingLocal => !isUsingFirebase;

  /// Gibt das lokale Repository zurück (für Sync-Operationen)
  WorkRepository get localRepository => _localRepository;

  /// Gibt das Firebase Repository zurück (für Sync-Operationen)
  WorkRepository get firebaseRepository => _firebaseRepository;
}
