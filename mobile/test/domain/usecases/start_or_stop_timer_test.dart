import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/repositories/work_repository.dart';
import 'package:flutter_work_time/domain/usecases/start_or_stop_timer.dart';

import 'start_or_stop_timer_test.mocks.dart';

@GenerateMocks([WorkRepository])
void main() {
  late MockWorkRepository mockWorkRepository;
  late StartOrStopTimer startOrStopTimer;

  setUp(() {
    mockWorkRepository = MockWorkRepository();
    startOrStopTimer = StartOrStopTimer(mockWorkRepository);
  });

  final baseDate = DateTime(2023, 10, 26);

  test('should start timer if workStart is null', () async {
    final entry = WorkEntryEntity(
      id: '1',
      date: baseDate,
      workStart: null,
      workEnd: null,
    );

    when(mockWorkRepository.saveWorkEntry(any))
        .thenAnswer((_) async {});

    final result = await startOrStopTimer(entry);

    expect(result.workStart, isNotNull);
    expect(result.workEnd, isNull);
    verify(mockWorkRepository.saveWorkEntry(result)).called(1);
  });

  test('should stop timer if workStart is set and workEnd is null', () async {
    final start = baseDate.add(const Duration(hours: 8));
    final entry = WorkEntryEntity(
      id: '1',
      date: baseDate,
      workStart: start,
      workEnd: null,
    );

    when(mockWorkRepository.saveWorkEntry(any))
        .thenAnswer((_) async {});

    final result = await startOrStopTimer(entry);

    expect(result.workStart, equals(start));
    expect(result.workEnd, isNotNull);
    verify(mockWorkRepository.saveWorkEntry(result)).called(1);
  });

  test('should do nothing if timer is already stopped (workEnd is set)', () async {
    final start = baseDate.add(const Duration(hours: 8));
    final end = baseDate.add(const Duration(hours: 16));
    final entry = WorkEntryEntity(
      id: '1',
      date: baseDate,
      workStart: start,
      workEnd: end,
    );

    final result = await startOrStopTimer(entry);

    expect(result, equals(entry));
    verifyNever(mockWorkRepository.saveWorkEntry(any));
  });
}
