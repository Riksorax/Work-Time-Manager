import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/utils/break_duration.dart';

// Pausendauer (#504). Feste Zeitpunkte, keine Abhängigkeit von Datum oder Zeitzone.
void main() {
  DateTime at(int h, [int m = 0, int s = 0]) => DateTime(2026, 3, 18, h, m, s);

  test('abgeschlossene Pause: Ende minus Start', () {
    final b =
        BreakEntity(id: '1', name: 'Pause', start: at(12), end: at(12, 30));
    expect(breakDuration(b, at(18)), const Duration(minutes: 30));
  });

  test('laufende Pause: bis jetzt', () {
    final b = BreakEntity(id: '1', name: 'Pause', start: at(12));
    expect(breakDuration(b, at(12, 12, 30)),
        const Duration(minutes: 12, seconds: 30));
  });

  test('nie negativ (Uhr vor dem Start)', () {
    final b = BreakEntity(id: '1', name: 'Pause', start: at(12));
    expect(breakDuration(b, at(11, 59)), Duration.zero);
  });
}
