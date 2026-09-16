import 'package:flutter_work_time/data/datasources/remote/firestore_datasource.dart';
import 'package:flutter_work_time/domain/entities/weekly_reflection_entity.dart';
import 'package:flutter_work_time/domain/repositories/weekly_reflection_repository.dart';

/// Repository für Wochen-Reflexionen, das Firestore als Backend nutzt
/// (siehe #137). Wird nur für eingeloggte Nutzer instanziiert.
class WeeklyReflectionRepositoryImpl implements WeeklyReflectionRepository {
  final FirestoreDataSource _dataSource;
  final String _userId;

  WeeklyReflectionRepositoryImpl({
    required FirestoreDataSource dataSource,
    required String userId,
  })  : _dataSource = dataSource,
        _userId = userId;

  @override
  Future<WeeklyReflectionEntity?> getReflection(int year, int week) {
    return _dataSource.getWeeklyReflection(_userId, year, week);
  }

  @override
  Future<void> saveReflection(WeeklyReflectionEntity reflection) {
    return _dataSource.saveWeeklyReflection(_userId, reflection);
  }
}
