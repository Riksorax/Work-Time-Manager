import 'package:flutter_work_time/core/utils/logger.dart';
import 'package:flutter_work_time/data/datasources/remote/firestore_datasource.dart';
import 'package:flutter_work_time/domain/repositories/overtime_repository.dart';

/// Repository für Überstunden, das Firestore als Backend nutzt.
/// Wird verwendet, wenn der User eingeloggt ist.
class FirebaseOvertimeRepositoryImpl implements OvertimeRepository {
  final FirestoreDataSource _dataSource;
  final String _userId;

  // Lokaler Cache für schnelle synchrone Reads
  Duration? _cachedOvertime;
  DateTime? _cachedLastUpdate;

  FirebaseOvertimeRepositoryImpl({
    required FirestoreDataSource dataSource,
    required String userId,
  })  : _dataSource = dataSource,
        _userId = userId;

  @override
  Duration getOvertime() {
    // Synchroner Zugriff - gibt gecachten Wert zurück oder Duration.zero
    // Der eigentliche Wert wird beim ersten async-Zugriff geladen
    if (_cachedOvertime != null) {
      logger.i('[FirebaseOvertimeRepository] getOvertime (cached): ${_cachedOvertime!.inMinutes} min');
      return _cachedOvertime!;
    }

    // Starte async Laden im Hintergrund
    _loadFromFirestore();

    logger.i('[FirebaseOvertimeRepository] getOvertime: Cache leer, gebe 0 zurück (lädt async)');
    return Duration.zero;
  }

  @override
  Future<void> saveOvertime(Duration overtime) async {
    logger.i('[FirebaseOvertimeRepository] saveOvertime: ${overtime.inMinutes} min');
    _cachedOvertime = overtime;
    await _dataSource.saveOvertime(_userId, overtime);
  }

  @override
  DateTime? getLastUpdateDate() {
    // Synchroner Zugriff - gibt gecachten Wert zurück
    if (_cachedLastUpdate != null) {
      return _cachedLastUpdate;
    }

    // Starte async Laden im Hintergrund
    _loadFromFirestore();

    return null;
  }

  @override
  Future<void> saveLastUpdateDate(DateTime date) async {
    logger.i('[FirebaseOvertimeRepository] saveLastUpdateDate: $date');
    _cachedLastUpdate = date;
    await _dataSource.saveLastOvertimeUpdate(_userId, date);
  }

  /// Lädt Daten async von Firestore und aktualisiert den Cache
  Future<void> _loadFromFirestore() async {
    try {
      final overtime = await _dataSource.getOvertime(_userId);
      _cachedOvertime = overtime;

      final lastUpdate = await _dataSource.getLastOvertimeUpdate(_userId);
      _cachedLastUpdate = lastUpdate;

      logger.i('[FirebaseOvertimeRepository] Daten von Firestore geladen: ${overtime.inMinutes} min, lastUpdate: $lastUpdate');
    } catch (e) {
      logger.e('[FirebaseOvertimeRepository] Fehler beim Laden von Firestore: $e');
    }
  }

  /// Lädt die Daten explizit von Firestore (für initiale Synchronisation)
  Future<Duration> loadOvertimeAsync() async {
    final overtime = await _dataSource.getOvertime(_userId);
    _cachedOvertime = overtime;
    return overtime;
  }

  /// Lädt das Update-Datum explizit von Firestore
  Future<DateTime?> loadLastUpdateAsync() async {
    final lastUpdate = await _dataSource.getLastOvertimeUpdate(_userId);
    _cachedLastUpdate = lastUpdate;
    return lastUpdate;
  }
}
