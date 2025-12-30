import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/data/models/break_model.dart';
import 'package:flutter_work_time/data/models/work_entry_model.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';

void main() {
  group('WorkEntryModel', () {
    final date = DateTime(2023, 10, 26);
    final workStart = DateTime(2023, 10, 26, 8, 0);
    final workEnd = DateTime(2023, 10, 26, 17, 0);

    test('should create from Entity correctly', () {
      final entity = WorkEntryEntity(
        id: '2023-10-26',
        date: date,
        workStart: workStart,
        workEnd: workEnd,
        type: WorkEntryType.work,
        description: 'Test day',
      );

      final model = WorkEntryModel.fromEntity(entity);

      expect(model.id, '2023-10-26');
      expect(model.date, date);
      expect(model.description, 'Test day');
    });

    test('should serialize to Map correctly', () {
      final breakModel = BreakModel(
        name: 'Lunch',
        start: DateTime(2023, 10, 26, 12, 0),
        end: DateTime(2023, 10, 26, 12, 30),
      );

      final model = WorkEntryModel(
        id: '1',
        date: date,
        workStart: workStart,
        workEnd: workEnd,
        breaks: [breakModel],
        manualOvertime: const Duration(minutes: 15),
        type: WorkEntryType.vacation,
      );

      final map = model.toMap();

      expect(map['type'], 'vacation');
      expect(map['manualOvertimeMinutes'], 15);
      expect(map['breaks'], isA<List>());
      expect((map['breaks'] as List).length, 1);
      expect(map['workStart'], isA<Timestamp>());
    });

    test('should deserialize from Map correctly', () {
      final map = {
        'date': Timestamp.fromDate(date),
        'workStart': Timestamp.fromDate(workStart),
        'workEnd': Timestamp.fromDate(workEnd),
        'type': 'sick',
        'manualOvertimeMinutes': 30,
        'isManuallyEntered': true,
        'breaks': [
           {
             'name': 'P1',
             'start': Timestamp.fromDate(DateTime(2023, 10, 26, 10, 0)),
             'end': Timestamp.fromDate(DateTime(2023, 10, 26, 10, 15)),
           }
        ],
      };

      final model = WorkEntryModel.fromMap(map);

      expect(model.type, WorkEntryType.sick);
      expect(model.manualOvertime, const Duration(minutes: 30));
      expect(model.isManuallyEntered, true);
      expect(model.breaks.length, 1);
      expect(model.breaks.first.name, 'P1');
    });

    test('generateId and parseId should be consistent', () {
      final id = WorkEntryModel.generateId(date);
      expect(id, '2023-10-26');
      
      final parsedDate = WorkEntryModel.parseId(id);
      expect(parsedDate.year, date.year);
      expect(parsedDate.month, date.month);
      expect(parsedDate.day, date.day);
    });

    test('empty factory should create valid model', () {
      final model = WorkEntryModel.empty(date);
      expect(model.id, '2023-10-26');
      expect(model.workStart, isNull);
      expect(model.breaks, isEmpty);
    });
  });
}
