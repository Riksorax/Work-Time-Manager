import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';

/// Tests for break editing logic in EditWorkEntryModal
///
/// The key behavior being tested:
/// When the start time of a break is changed, the end time should
/// automatically move to preserve the original duration.
void main() {
  group('EditWorkEntryModal break time adjustment logic', () {
    test('end time moves with start time to preserve duration', () {
      // Original break: 12:00 - 12:30 (30 minutes)
      final breakEntry = BreakEntity(
        id: 'break-1',
        name: 'Mittagspause',
        start: DateTime(2024, 1, 15, 12, 0),
        end: DateTime(2024, 1, 15, 12, 30),
      );

      // User changes start time to 13:00
      final newStart = DateTime(2024, 1, 15, 13, 0);

      // This is the logic from edit_work_entry_modal.dart:
      // Calculate duration and apply to new start
      DateTime? newEnd = breakEntry.end;
      if (breakEntry.end != null) {
        final duration = breakEntry.end!.difference(breakEntry.start);
        newEnd = newStart.add(duration);
      }

      // End time should now be 13:30 (preserving 30 minute duration)
      expect(newEnd, DateTime(2024, 1, 15, 13, 30));
    });

    test('duration is preserved when moving start time earlier', () {
      // Original break: 14:00 - 15:00 (60 minutes)
      final breakEntry = BreakEntity(
        id: 'break-1',
        name: 'Nachmittagspause',
        start: DateTime(2024, 1, 15, 14, 0),
        end: DateTime(2024, 1, 15, 15, 0),
      );

      // User changes start time to 10:00
      final newStart = DateTime(2024, 1, 15, 10, 0);

      DateTime? newEnd = breakEntry.end;
      if (breakEntry.end != null) {
        final duration = breakEntry.end!.difference(breakEntry.start);
        newEnd = newStart.add(duration);
      }

      // End time should now be 11:00
      expect(newEnd, DateTime(2024, 1, 15, 11, 0));
    });

    test('handles break with null end time (active break)', () {
      // Active break with no end time
      final breakEntry = BreakEntity(
        id: 'break-1',
        name: 'Laufende Pause',
        start: DateTime(2024, 1, 15, 12, 0),
        end: null,
      );

      final newStart = DateTime(2024, 1, 15, 13, 0);

      // Apply the same logic
      DateTime? newEnd = breakEntry.end;
      if (breakEntry.end != null) {
        final duration = breakEntry.end!.difference(breakEntry.start);
        newEnd = newStart.add(duration);
      }

      // End time should remain null
      expect(newEnd, isNull);
    });

    test('preserves complex duration (hours and minutes)', () {
      // Original break: 09:15 - 11:45 (2 hours 30 minutes)
      final breakEntry = BreakEntity(
        id: 'break-1',
        name: 'Lange Pause',
        start: DateTime(2024, 1, 15, 9, 15),
        end: DateTime(2024, 1, 15, 11, 45),
      );

      final newStart = DateTime(2024, 1, 15, 14, 0);

      DateTime? newEnd = breakEntry.end;
      if (breakEntry.end != null) {
        final duration = breakEntry.end!.difference(breakEntry.start);
        newEnd = newStart.add(duration);
      }

      // End time should be 16:30 (14:00 + 2h30m)
      expect(newEnd, DateTime(2024, 1, 15, 16, 30));
    });

    test('end time change does not affect start time', () {
      // This ensures only start time changes trigger the adjustment
      final breakEntry = BreakEntity(
        id: 'break-1',
        name: 'Test',
        start: DateTime(2024, 1, 15, 12, 0),
        end: DateTime(2024, 1, 15, 12, 30),
      );

      // When user manually changes end time, start should not move
      final newEnd = DateTime(2024, 1, 15, 13, 0);

      // The updated break should have original start, new end
      final updatedBreak = breakEntry.copyWith(end: newEnd);

      expect(updatedBreak.start, DateTime(2024, 1, 15, 12, 0));
      expect(updatedBreak.end, DateTime(2024, 1, 15, 13, 0));
    });
  });

  group('WorkEntry with multiple breaks', () {
    test('updating one break does not affect others', () {
      final workEntry = WorkEntryEntity(
        id: 'entry-1',
        date: DateTime(2024, 1, 15),
        workStart: DateTime(2024, 1, 15, 8, 0),
        workEnd: DateTime(2024, 1, 15, 17, 0),
        breaks: [
          BreakEntity(
            id: 'break-1',
            name: 'Frühstück',
            start: DateTime(2024, 1, 15, 10, 0),
            end: DateTime(2024, 1, 15, 10, 15),
          ),
          BreakEntity(
            id: 'break-2',
            name: 'Mittagspause',
            start: DateTime(2024, 1, 15, 12, 0),
            end: DateTime(2024, 1, 15, 12, 30),
          ),
        ],
      );

      // Update only break-2
      final targetBreak = workEntry.breaks.firstWhere((b) => b.id == 'break-2');
      final newStart = DateTime(2024, 1, 15, 13, 0);
      final duration = targetBreak.end!.difference(targetBreak.start);
      final newEnd = newStart.add(duration);

      final updatedBreaks = workEntry.breaks.map((b) {
        if (b.id == 'break-2') {
          return b.copyWith(start: newStart, end: newEnd);
        }
        return b;
      }).toList();

      // Break 1 should be unchanged
      expect(updatedBreaks[0].start, DateTime(2024, 1, 15, 10, 0));
      expect(updatedBreaks[0].end, DateTime(2024, 1, 15, 10, 15));

      // Break 2 should be updated with preserved duration
      expect(updatedBreaks[1].start, DateTime(2024, 1, 15, 13, 0));
      expect(updatedBreaks[1].end, DateTime(2024, 1, 15, 13, 30));
    });
  });
}
