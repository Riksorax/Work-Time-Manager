import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';

void main() {
  group('SettingsState', () {
    test('should create initial state with null lastOvertimeUpdate', () {
      final state = SettingsState.initial();

      expect(state.lastOvertimeUpdate, isNull);
      expect(state.overtimeBalance, Duration.zero);
      expect(state.isLoading, true);
    });

    test('should create state with lastOvertimeUpdate', () {
      final updateDate = DateTime(2026, 1, 29, 14, 30);
      final state = SettingsState(
        settings: const SettingsEntity(),
        overtimeBalance: const Duration(hours: 5),
        lastOvertimeUpdate: updateDate,
      );

      expect(state.lastOvertimeUpdate, updateDate);
      expect(state.overtimeBalance, const Duration(hours: 5));
    });

    test('copyWith should update lastOvertimeUpdate', () {
      final initialState = SettingsState(
        settings: const SettingsEntity(),
        overtimeBalance: const Duration(hours: 2),
        lastOvertimeUpdate: null,
      );

      final newDate = DateTime(2026, 1, 30, 10, 0);
      final updatedState = initialState.copyWith(lastOvertimeUpdate: newDate);

      expect(updatedState.lastOvertimeUpdate, newDate);
      expect(updatedState.overtimeBalance, const Duration(hours: 2));
    });

    test('copyWith should preserve lastOvertimeUpdate when not specified', () {
      final originalDate = DateTime(2026, 1, 28);
      final initialState = SettingsState(
        settings: const SettingsEntity(),
        overtimeBalance: const Duration(hours: 3),
        lastOvertimeUpdate: originalDate,
      );

      final updatedState = initialState.copyWith(
        overtimeBalance: const Duration(hours: 5),
      );

      expect(updatedState.lastOvertimeUpdate, originalDate);
      expect(updatedState.overtimeBalance, const Duration(hours: 5));
    });

    test('props should include lastOvertimeUpdate for equality', () {
      final date = DateTime(2026, 1, 29);
      final state1 = SettingsState(
        settings: const SettingsEntity(),
        overtimeBalance: const Duration(hours: 1),
        lastOvertimeUpdate: date,
      );

      final state2 = SettingsState(
        settings: const SettingsEntity(),
        overtimeBalance: const Duration(hours: 1),
        lastOvertimeUpdate: date,
      );

      final state3 = SettingsState(
        settings: const SettingsEntity(),
        overtimeBalance: const Duration(hours: 1),
        lastOvertimeUpdate: DateTime(2026, 1, 30),
      );

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });
  });
}
