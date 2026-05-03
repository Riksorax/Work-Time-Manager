import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_work_time/data/repositories/local_overtime_repository_impl.dart';

void main() {
  late SharedPreferences prefs;
  late LocalOvertimeRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = LocalOvertimeRepositoryImpl(prefs);
  });

  group('LocalOvertimeRepositoryImpl', () {
    test('should save and get overtime', () async {
      const overtime = Duration(hours: 10, minutes: 30);
      await repository.saveOvertime(overtime);

      final result = repository.getOvertime();
      expect(result, overtime);
    });

    test('should return zero duration if no overtime saved', () {
      final result = repository.getOvertime();
      expect(result, Duration.zero);
    });

    test('should save and get last update date', () async {
      final now = DateTime.now();
      await repository.saveLastUpdateDate(now);

      final result = repository.getLastUpdateDate();
      // Use toIso8601String comparison to avoid microsecond precision issues in some environments
      expect(result?.toIso8601String(), now.toIso8601String());
    });
  });
}
