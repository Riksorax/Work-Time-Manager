import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_work_time/domain/repositories/overtime_repository.dart';
import 'package:flutter_work_time/domain/usecases/overtime_usecases.dart';

import 'overtime_usecases_test.mocks.dart';

@GenerateMocks([OvertimeRepository])
void main() {
  late MockOvertimeRepository mockRepository;
  late GetOvertime getOvertime;
  late UpdateOvertime updateOvertime;
  late SetOvertime setOvertime;

  setUp(() {
    mockRepository = MockOvertimeRepository();
    getOvertime = GetOvertime(mockRepository);
    updateOvertime = UpdateOvertime(mockRepository);
    setOvertime = SetOvertime(mockRepository);
  });

  group('GetOvertime', () {
    test('should return overtime from repository', () {
      const duration = Duration(hours: 5);
      when(mockRepository.getOvertime()).thenReturn(duration);

      final result = getOvertime();

      expect(result, duration);
      verify(mockRepository.getOvertime()).called(1);
    });
  });

  group('UpdateOvertime', () {
    test('should add amount to current overtime and save', () async {
      const currentOvertime = Duration(hours: 10);
      const amountToAdd = Duration(hours: 2);
      const expectedOvertime = Duration(hours: 12);

      when(mockRepository.getOvertime()).thenReturn(currentOvertime);
      when(mockRepository.saveOvertime(any)).thenAnswer((_) async {});

      final result = await updateOvertime(amount: amountToAdd);

      expect(result, expectedOvertime);
      verify(mockRepository.getOvertime()).called(1);
      verify(mockRepository.saveOvertime(expectedOvertime)).called(1);
    });

    test('should handle negative amount correctly', () async {
      const currentOvertime = Duration(hours: 10);
      const amountToSubtract = Duration(hours: -2);
      const expectedOvertime = Duration(hours: 8);

      when(mockRepository.getOvertime()).thenReturn(currentOvertime);
      when(mockRepository.saveOvertime(any)).thenAnswer((_) async {});

      final result = await updateOvertime(amount: amountToSubtract);

      expect(result, expectedOvertime);
      verify(mockRepository.saveOvertime(expectedOvertime)).called(1);
    });
  });

  group('SetOvertime', () {
    test('should save exact overtime', () async {
      const overtime = Duration(hours: 20);

      when(mockRepository.saveOvertime(any)).thenAnswer((_) async {});

      await setOvertime(overtime: overtime);

      verify(mockRepository.saveOvertime(overtime)).called(1);
    });
  });
}
