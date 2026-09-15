import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/utils/overtime_warning_utils.dart';

void main() {
  group('checkOvertimeWarning', () {
    test('gibt none zurück, wenn beide Warnungen deaktiviert sind', () {
      final result = checkOvertimeWarning(
        totalOvertime: const Duration(hours: 100),
        warnOnOvertime: false,
        overtimeThresholdHours: 10,
        warnOnUndertime: false,
        undertimeThresholdHours: 10,
      );
      expect(result, OvertimeWarningType.none);
    });

    test('gibt overtime zurück, wenn Schwellwert erreicht ist', () {
      final result = checkOvertimeWarning(
        totalOvertime: const Duration(hours: 10),
        warnOnOvertime: true,
        overtimeThresholdHours: 10,
        warnOnUndertime: false,
        undertimeThresholdHours: 10,
      );
      expect(result, OvertimeWarningType.overtime);
    });

    test('gibt none zurück, solange der Schwellwert nicht erreicht ist', () {
      final result = checkOvertimeWarning(
        totalOvertime: const Duration(hours: 9, minutes: 59),
        warnOnOvertime: true,
        overtimeThresholdHours: 10,
        warnOnUndertime: false,
        undertimeThresholdHours: 10,
      );
      expect(result, OvertimeWarningType.none);
    });

    test('gibt undertime zurück, wenn Minus-Schwellwert erreicht ist', () {
      final result = checkOvertimeWarning(
        totalOvertime: const Duration(hours: -10),
        warnOnOvertime: false,
        overtimeThresholdHours: 10,
        warnOnUndertime: true,
        undertimeThresholdHours: 10,
      );
      expect(result, OvertimeWarningType.undertime);
    });

    test('gibt none zurück, solange der Minus-Schwellwert nicht erreicht ist', () {
      final result = checkOvertimeWarning(
        totalOvertime: const Duration(hours: -9, minutes: -59),
        warnOnOvertime: false,
        overtimeThresholdHours: 10,
        warnOnUndertime: true,
        undertimeThresholdHours: 10,
      );
      expect(result, OvertimeWarningType.none);
    });

    test('overtime hat Vorrang, falls beide Schwellwerte (unrealistisch) gleichzeitig zuträfen', () {
      final result = checkOvertimeWarning(
        totalOvertime: const Duration(hours: 20),
        warnOnOvertime: true,
        overtimeThresholdHours: 10,
        warnOnUndertime: true,
        undertimeThresholdHours: 10,
      );
      expect(result, OvertimeWarningType.overtime);
    });

    test('respektiert deaktivierte Überstunden-Warnung trotz überschrittenem Wert', () {
      final result = checkOvertimeWarning(
        totalOvertime: const Duration(hours: 50),
        warnOnOvertime: false,
        overtimeThresholdHours: 10,
        warnOnUndertime: false,
        undertimeThresholdHours: 10,
      );
      expect(result, OvertimeWarningType.none);
    });
  });
}
