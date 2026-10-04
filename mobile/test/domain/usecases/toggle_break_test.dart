import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/repositories/work_repository.dart';
import 'package:flutter_work_time/domain/usecases/toggle_break.dart';

import 'toggle_break_test.mocks.dart';

@GenerateMocks([WorkRepository])
void main() {
  late MockWorkRepository mockRepository;
  late ToggleBreak toggleBreak;

  setUp(() {
    mockRepository = MockWorkRepository();
    toggleBreak = ToggleBreak(mockRepository);
  });

  final baseDate = DateTime(2023, 10, 26);

  test('should start a new break if no break is active', () async {
    final entry = WorkEntryEntity(
      id: '1',
      date: baseDate,
      breaks: [],
    );

    when(mockRepository.saveWorkEntry(any)).thenAnswer((_) async {});

    final result = await toggleBreak(entry);

    expect(result.breaks.length, 1);
    expect(result.breaks.first.end, isNull);
    verify(mockRepository.saveWorkEntry(any)).called(1);
  });

  test('should stop active break if one exists', () async {
    final start = baseDate.add(const Duration(hours: 10));
    final activeBreak = BreakEntity(
      id: 'break1',
      name: 'Pause 1',
      start: start,
      end: null,
    );

    final entry = WorkEntryEntity(
      id: '1',
      date: baseDate,
      breaks: [activeBreak],
    );

    when(mockRepository.saveWorkEntry(any)).thenAnswer((_) async {});

    final result = await toggleBreak(entry);

    expect(result.breaks.length, 1);
    expect(result.breaks.first.end, isNotNull);
    verify(mockRepository.saveWorkEntry(any)).called(1);
  });

  group('mit injizierter Uhr (#379)', () {
    test('Pausenstart nutzt die Uhr, auf Minuten abgeschnitten', () async {
      final clockValue = DateTime(2026, 10, 3, 9, 0, 40);
      final uc = ToggleBreak(mockRepository, clock: () => clockValue);
      when(mockRepository.saveWorkEntry(any)).thenAnswer((_) async {});

      final result = await uc(WorkEntryEntity(id: '1', date: baseDate));

      expect(result.breaks.single.start, DateTime(2026, 10, 3, 9, 0));
    });

    test('Pausenende nutzt die Uhr, auf Minuten abgeschnitten', () async {
      final clockValue = DateTime(2026, 10, 3, 9, 30, 59);
      final uc = ToggleBreak(mockRepository, clock: () => clockValue);
      when(mockRepository.saveWorkEntry(any)).thenAnswer((_) async {});
      final entry = WorkEntryEntity(id: '1', date: baseDate, breaks: [
        BreakEntity(
            id: 'b', name: 'Pause 1', start: DateTime(2026, 10, 3, 9, 0)),
      ]);

      final result = await uc(entry);

      expect(result.breaks.single.end, DateTime(2026, 10, 3, 9, 30));
    });
  });
}
