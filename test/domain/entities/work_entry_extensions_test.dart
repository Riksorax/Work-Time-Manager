import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_extensions.dart';

void main() {
  group('WorkEntryCalculations', () {
    final baseDate = DateTime(2023, 10, 26);
    const targetDailyHours = Duration(hours: 8);

    test('calculateOvertime should return zero for special types (vacation, sick, holiday)', () {
      final types = [WorkEntryType.vacation, WorkEntryType.sick, WorkEntryType.holiday];
      
      for (final type in types) {
        final entry = WorkEntryEntity(
          id: '1',
          date: baseDate,
          type: type,
          // Even if times are set (which usually aren't for these types), overtime should be 0 (or manualOvertime)
          workStart: baseDate.add(const Duration(hours: 9)), 
          workEnd: baseDate.add(const Duration(hours: 17)),
        );

        expect(entry.calculateOvertime(targetDailyHours), Duration.zero, reason: 'Type $type failed');
      }
    });

    test('calculateOvertime should include manualOvertime for special types', () {
      final entry = WorkEntryEntity(
        id: '1',
        date: baseDate,
        type: WorkEntryType.vacation,
        manualOvertime: const Duration(hours: 1),
      );

      expect(entry.calculateOvertime(targetDailyHours), const Duration(hours: 1));
    });

    test('calculateOvertime should return zero if workEnd is null (timer running)', () {
      final entry = WorkEntryEntity(
        id: '1',
        date: baseDate,
        type: WorkEntryType.work,
        workStart: baseDate.add(const Duration(hours: 8)),
        workEnd: null,
      );

      // Should be zero because day is not finished
      expect(entry.calculateOvertime(targetDailyHours), Duration.zero);
    });

    test('calculateOvertime should calculate correct positive overtime', () {
      // 9 hours work (8h target) -> +1h overtime
      final start = baseDate.add(const Duration(hours: 8));
      final end = baseDate.add(const Duration(hours: 17));
      
      final entry = WorkEntryEntity(
        id: '1',
        date: baseDate,
        type: WorkEntryType.work,
        workStart: start,
        workEnd: end,
        breaks: [],
      );

      expect(entry.calculateOvertime(targetDailyHours), const Duration(hours: 1));
    });

    test('calculateOvertime should calculate correct negative overtime', () {
      // 6 hours work (8h target) -> -2h overtime
      final start = baseDate.add(const Duration(hours: 8));
      final end = baseDate.add(const Duration(hours: 14));
      
      final entry = WorkEntryEntity(
        id: '1',
        date: baseDate,
        type: WorkEntryType.work,
        workStart: start,
        workEnd: end,
        breaks: [],
      );

      expect(entry.calculateOvertime(targetDailyHours), const Duration(hours: -2));
    });

    test('calculateOvertime should deduct breaks correctly', () {
      // 9h elapsed, 1h break -> 8h work -> 0 overtime
      final start = baseDate.add(const Duration(hours: 8));
      final end = baseDate.add(const Duration(hours: 17)); // 17 - 8 = 9h
      
      final breakEntity = BreakEntity(
        id: 'b1',
        name: 'Lunch',
        start: baseDate.add(const Duration(hours: 12)),
        end: baseDate.add(const Duration(hours: 13)), // 1h
      );

      final entry = WorkEntryEntity(
        id: '1',
        date: baseDate,
        type: WorkEntryType.work,
        workStart: start,
        workEnd: end,
        breaks: [breakEntity],
      );

      expect(entry.calculateOvertime(targetDailyHours), Duration.zero);
    });

    test('effectiveWorkDuration should default to zero if workStart is null', () {
       final entry = WorkEntryEntity(
        id: '1',
        date: baseDate,
        workStart: null,
      );
      expect(entry.effectiveWorkDuration, Duration.zero);
    });
  });
}
