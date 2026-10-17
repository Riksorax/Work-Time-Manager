import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/timer_status.dart';

/// Inkonsistente Fixture wie in `*_entry_day_test.dart`: Id Montag, `date`
/// Sonntag. Der Tagesschluessel muss aus der Id kommen (#418).
WorkEntryEntity _entry({
  DateTime? start,
  DateTime? end,
  List<BreakEntity> breaks = const [],
}) =>
    WorkEntryEntity(
      id: '2026-10-05',
      date: DateTime(2026, 10, 4),
      workStart: start,
      workEnd: end,
      breaks: breaks,
    );

final _start = DateTime.utc(2026, 10, 5, 8, 15);
final _end = DateTime.utc(2026, 10, 5, 16, 45);
final _pauseStart = DateTime.utc(2026, 10, 5, 12);
const _net = Duration(hours: 3, minutes: 45, seconds: 30);

void main() {
  group('buildTimerSnapshot', () {
    test('leerer Tag -> notStarted ohne Zeiten', () {
      final s = buildTimerSnapshot(entry: _entry(), net: Duration.zero);
      expect(s.status, TimerStatus.notStarted);
      expect(s.workStartMs, isNull);
      expect(s.pauseStartMs, isNull);
      expect(s.netMinutes, 0);
      expect(s.dayKey, '2026-10-05');
    });

    test('Start ohne Ende -> running, Startzeit als Epoch-Millisekunden', () {
      final s = buildTimerSnapshot(entry: _entry(start: _start), net: _net);
      expect(s.status, TimerStatus.running);
      expect(s.workStartMs, _start.millisecondsSinceEpoch);
      expect(s.pauseStartMs, isNull);
      expect(s.netMinutes, 225);
    });

    test('geschlossene Pause -> weiter running', () {
      final s = buildTimerSnapshot(
        entry: _entry(start: _start, breaks: [
          BreakEntity(
              id: 'b', name: 'Pause', start: _pauseStart, end: _pauseStart),
        ]),
        net: _net,
      );
      expect(s.status, TimerStatus.running);
      expect(s.pauseStartMs, isNull);
    });

    test('offene Pause -> paused mit Pausenstart', () {
      final s = buildTimerSnapshot(
        entry: _entry(start: _start, breaks: [
          BreakEntity(id: 'b', name: 'Pause', start: _pauseStart),
        ]),
        net: _net,
      );
      expect(s.status, TimerStatus.paused);
      expect(s.pauseStartMs, _pauseStart.millisecondsSinceEpoch);
      expect(s.workStartMs, _start.millisecondsSinceEpoch);
    });

    test('Ende gesetzt -> stopped', () {
      final s = buildTimerSnapshot(
          entry: _entry(start: _start, end: _end),
          net: const Duration(hours: 8));
      expect(s.status, TimerStatus.stopped);
      expect(s.netMinutes, 480);
      expect(s.workStartMs, _start.millisecondsSinceEpoch);
    });

    test('Netto wird auf volle Minuten abgeschnitten, nie negativ', () {
      expect(
          buildTimerSnapshot(
                  entry: _entry(start: _start),
                  net: const Duration(minutes: 59, seconds: 59))
              .netMinutes,
          59);
      expect(
          buildTimerSnapshot(
                  entry: _entry(start: _start),
                  net: const Duration(minutes: -5))
              .netMinutes,
          0);
    });

    test('Tagesschluessel kommt aus der Id, nicht aus date', () {
      final s = buildTimerSnapshot(entry: _entry(start: _start), net: _net);
      expect(s.dayKey, '2026-10-05');
    });

    test('Gleichheit: gleiche Eingabe -> gleicher Snapshot', () {
      final a = buildTimerSnapshot(entry: _entry(start: _start), net: _net);
      final b = buildTimerSnapshot(entry: _entry(start: _start), net: _net);
      expect(a, b);
      expect(
          a,
          isNot(buildTimerSnapshot(
              entry: _entry(start: _start),
              net: _net + const Duration(minutes: 1))));
    });
  });
}
