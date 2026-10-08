import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/presentation/state/dashboard_state.dart';

void main() {
  final day = DateTime(2026, 10, 5);
  DashboardState base() => DashboardState(
        workEntry: WorkEntryEntity(id: 'x', date: day),
        elapsedTime: Duration.zero,
      );

  group('DashboardState.isSaving (#413)', () {
    test('Default ist false', () {
      expect(base().isSaving, isFalse);
    });

    test('initial() ist false', () {
      expect(DashboardState.initial(now: day).isSaving, isFalse);
    });

    test('copyWith(isSaving: true) setzt den Wert', () {
      expect(base().copyWith(isSaving: true).isSaving, isTrue);
    });

    test('copyWith ohne Argument behaelt den Wert', () {
      final saving = base().copyWith(isSaving: true);
      expect(saving.copyWith().isSaving, isTrue);
      expect(saving.copyWith(isSaving: false).isSaving, isFalse);
    });

    test('Gleichheit unterscheidet isSaving', () {
      expect(base(), base());
      expect(base() == base().copyWith(isSaving: true), isFalse);
    });
  });
}
