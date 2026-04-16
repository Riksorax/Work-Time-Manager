import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_work_time/data/repositories/local_work_repository_impl.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';

void main() {
  late SharedPreferences prefs;
  late LocalWorkRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = LocalWorkRepositoryImpl(prefs);
  });

  group('LocalWorkRepositoryImpl', () {
    final date = DateTime(2023, 10, 26);
    final workStart = DateTime(2023, 10, 26, 8, 0);
    final workEnd = DateTime(2023, 10, 26, 16, 0);

    test('should save and load a work entry correctly', () async {
      final entry = WorkEntryEntity(
        id: '2023-10-26',
        date: date,
        workStart: workStart,
        workEnd: workEnd,
        breaks: [
          BreakEntity(
            id: 'b1',
            name: 'Pause',
            start: DateTime(2023, 10, 26, 12, 0),
            end: DateTime(2023, 10, 26, 12, 30),
          )
        ],
        description: 'Test',
      );

      await repository.saveWorkEntry(entry);

      final loaded = await repository.getWorkEntry(date);

      expect(loaded.workStart, workStart);
      expect(loaded.workEnd, workEnd);
      expect(loaded.breaks.length, 1);
      expect(loaded.breaks.first.name, 'Pause');
      expect(loaded.description, 'Test');
    });

    test('should return empty entry if not found', () async {
      final loaded = await repository.getWorkEntry(DateTime(2000, 1, 1));
      expect(loaded.workStart, isNull);
      expect(loaded.breaks, isEmpty);
    });

    test('getWorkEntriesForMonth should return all entries in a month', () async {
      final entry1 = WorkEntryEntity(
        id: '2023-10-01',
        date: DateTime(2023, 10, 1),
        workStart: workStart,
      );
      final entry2 = WorkEntryEntity(
        id: '2023-10-02',
        date: DateTime(2023, 10, 2),
        workStart: workStart,
      );

      await repository.saveWorkEntry(entry1);
      await repository.saveWorkEntry(entry2);

      final entries = await repository.getWorkEntriesForMonth(2023, 10);

      expect(entries.length, 2);
      expect(entries.first.date.day, 1);
      expect(entries.last.date.day, 2);
    });

    test('deleteWorkEntry should remove entry', () async {
      final entry = WorkEntryEntity(id: '2023-10-26', date: date, workStart: workStart);
      await repository.saveWorkEntry(entry);
      
      await repository.deleteWorkEntry('2023-10-26');
      
      final loaded = await repository.getWorkEntry(date);
      expect(loaded.workStart, isNull);
    });

    test('getAllLocalEntries and clearAllLocalEntries should work for sync', () async {
      final entry = WorkEntryEntity(id: '2023-10-26', date: date, workStart: workStart);
      await repository.saveWorkEntry(entry);

      final all = await repository.getAllLocalEntries();
      expect(all.length, 1);

      await repository.clearAllLocalEntries();
      final afterClear = await repository.getAllLocalEntries();
      expect(afterClear, isEmpty);
    });
  });
}
