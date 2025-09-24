import 'package:flutter_work_time/data/datasources/local/storage_datasource.dart';
import 'package:flutter_work_time/domain/repositories/overtime_repository.dart';

class OvertimeRepositoryImpl implements OvertimeRepository {
  final StorageDataSource dataSource;

  OvertimeRepositoryImpl(this.dataSource);

  @override
  Duration getOvertime() {
    return dataSource.getOvertime();
  }

  @override
  Future<void> saveOvertime(Duration overtime) {
    return dataSource.saveOvertime(overtime);
  }
}
