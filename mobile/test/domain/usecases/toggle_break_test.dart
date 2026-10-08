import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/usecases/toggle_break.dart';

import '../../support/fake_clock.dart';

/// `ToggleBreak` ist eine reine Transformation Entry -> Entry (#386):
/// kein Repository, kein Speichern (das macht das ViewModel einmal).
void main() {
  final baseDate = DateTime(2026, 10, 5);

  test('startet eine neue Pause, wenn keine aktiv ist', () async {
    final clock = FakeClock(DateTime(2026, 10, 5, 9, 0, 40));
    final toggleBreak = ToggleBreak(clock: clock.call);

    final result = await toggleBreak(WorkEntryEntity(id: '1', date: baseDate));

    expect(result.breaks.length, 1);
    expect(result.breaks.first.end, isNull);
    expect(result.breaks.first.name, 'Pause 1');
    expect(result.breaks.first.start, DateTime(2026, 10, 5, 9, 0));
  });

  test('beendet die aktive Pause, auf Minuten abgeschnitten', () async {
    final clock = FakeClock(DateTime(2026, 10, 5, 9, 30, 59));
    final toggleBreak = ToggleBreak(clock: clock.call);
    final entry = WorkEntryEntity(id: '1', date: baseDate, breaks: [
      BreakEntity(id: 'b', name: 'Pause 1', start: DateTime(2026, 10, 5, 9)),
    ]);

    final result = await toggleBreak(entry);

    expect(result.breaks.length, 1);
    expect(result.breaks.single.end, DateTime(2026, 10, 5, 9, 30));
  });

  test('haengt eine weitere Pause an und laesst abgeschlossene unberuehrt',
      () async {
    final clock = FakeClock(DateTime(2026, 10, 5, 14, 0));
    final toggleBreak = ToggleBreak(clock: clock.call);
    final done = BreakEntity(
        id: 'a',
        name: 'Pause 1',
        start: DateTime(2026, 10, 5, 12),
        end: DateTime(2026, 10, 5, 12, 30));

    final result = await toggleBreak(
        WorkEntryEntity(id: '1', date: baseDate, breaks: [done]));

    expect(result.breaks.length, 2);
    expect(result.breaks.first, done);
    expect(result.breaks.last.name, 'Pause 2');
    expect(result.breaks.last.end, isNull);
  });
}
