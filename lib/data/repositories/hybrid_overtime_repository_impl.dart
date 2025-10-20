import '../../domain/repositories/overtime_repository.dart';

/// Hybrid Repository für Überstunden, das automatisch zwischen Firebase und Local wechselt.
class HybridOvertimeRepositoryImpl implements OvertimeRepository {
  final OvertimeRepository _firebaseRepository;
  final OvertimeRepository _localRepository;
  final String? _userId;

  HybridOvertimeRepositoryImpl({
    required OvertimeRepository firebaseRepository,
    required OvertimeRepository localRepository,
    required String? userId,
  })  : _firebaseRepository = firebaseRepository,
        _localRepository = localRepository,
        _userId = userId;

  /// Gibt das aktive Repository zurück
  OvertimeRepository get _activeRepository {
    if (_userId != null && _userId!.isNotEmpty) {
      print('[HybridOvertimeRepository] Verwende Firebase (User: $_userId)');
      return _firebaseRepository;
    } else {
      print('[HybridOvertimeRepository] Verwende Local (Offline)');
      return _localRepository;
    }
  }

  @override
  Duration getOvertime() {
    return _activeRepository.getOvertime();
  }

  @override
  Future<void> saveOvertime(Duration overtime) async {
    await _activeRepository.saveOvertime(overtime);
  }

  /// Gibt true zurück, wenn Firebase verwendet wird
  bool get isUsingFirebase => _userId != null && _userId!.isNotEmpty;

  /// Gibt true zurück, wenn Local verwendet wird
  bool get isUsingLocal => !isUsingFirebase;

  /// Gibt das lokale Repository zurück (für Sync-Operationen)
  OvertimeRepository get localRepository => _localRepository;

  /// Gibt das Firebase Repository zurück (für Sync-Operationen)
  OvertimeRepository get firebaseRepository => _firebaseRepository;
}
