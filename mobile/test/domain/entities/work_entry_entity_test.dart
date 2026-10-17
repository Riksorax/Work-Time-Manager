import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';

void main() {
  group('WorkEntryEntity.isHomeOffice', () {
    final base = WorkEntryEntity(id: '2026-06-05', date: DateTime(2026, 6, 5));

    test('Default ist false', () {
      expect(base.isHomeOffice, isFalse);
    });

    test('copyWith setzt, erhaelt und setzt zurueck', () {
      final on = base.copyWith(isHomeOffice: true);
      expect(on.isHomeOffice, isTrue);
      expect(on.copyWith().isHomeOffice, isTrue);
      expect(on.copyWith(isHomeOffice: false).isHomeOffice, isFalse);
    });

    test('Equatable beruecksichtigt das Flag', () {
      expect(base, isNot(base.copyWith(isHomeOffice: true)));
      expect(base, base.copyWith(isHomeOffice: false));
    });
  });
}
