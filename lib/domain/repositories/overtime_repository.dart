import '../../data/datasources/local/storage_datasource.dart';

/// Das Repository für die Verwaltung des Überstundensaldos.
/// Es entkoppelt die Anwendungslogik von der konkreten Datenspeicherung.
abstract class OvertimeRepository {
  /// Ruft den aktuellen Überstundensaldo ab.
  Duration getOvertime();

  /// Speichert den neuen Überstundensaldo.
  Future<void> saveOvertime(Duration overtime);
}

/// Die konkrete Implementierung des OvertimeRepository.
/// Sie leitet die Aufrufe an die [StorageDataSource] weiter.
class OvertimeRepositoryImpl implements OvertimeRepository {
  final StorageDataSource _dataSource;

  OvertimeRepositoryImpl(this._dataSource);

  @override
  Duration getOvertime() {
    return _dataSource.getOvertime();
  }

  @override
  Future<void> saveOvertime(Duration overtime) async {
    await _dataSource.saveOvertime(overtime);
  }
}