import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/timer_action.dart';

WorkEntryEntity _entry({
  DateTime? start,
  DateTime? end,
  List<BreakEntity> breaks = const [],
  WorkEntryType type = WorkEntryType.work,
}) =>
    WorkEntryEntity(
      id: '2026-10-05',
      date: DateTime(2026, 10, 5),
      workStart: start,
      workEnd: end,
      breaks: breaks,
      type: type,
    );

final _t0 = DateTime(2026, 10, 5, 8);
final _t1 = DateTime(2026, 10, 5, 12);

void main() {
  group('decideTimerAction', () {
    test('Start bei leerem Tag wird angewendet', () {
      expect(
          decideTimerAction(TimerAction.start, _entry()), TimerDecision.apply);
    });

    test('Start bei laufendem Timer ist nicht anwendbar', () {
      expect(decideTimerAction(TimerAction.start, _entry(start: _t0)),
          TimerDecision.notApplicable);
    });

    test('Start bei gestopptem Tag ist nicht anwendbar', () {
      expect(decideTimerAction(TimerAction.start, _entry(start: _t0, end: _t1)),
          TimerDecision.notApplicable);
    });

    test('Start bei Sonder-Eintrag (Urlaub, Krank, Feiertag) nicht anwendbar',
        () {
      for (final type in [
        WorkEntryType.vacation,
        WorkEntryType.sick,
        WorkEntryType.holiday,
      ]) {
        expect(decideTimerAction(TimerAction.start, _entry(type: type)),
            TimerDecision.notApplicable,
            reason: '$type');
      }
    });

    test('Stop bei laufendem Timer wird angewendet', () {
      expect(decideTimerAction(TimerAction.stop, _entry(start: _t0)),
          TimerDecision.apply);
    });

    test('Stop bei laufendem Timer mit offener Pause wird angewendet', () {
      final e = _entry(start: _t0, breaks: [
        BreakEntity(id: 'b', name: 'Pause', start: DateTime(2026, 10, 5, 10)),
      ]);
      expect(decideTimerAction(TimerAction.stop, e), TimerDecision.apply);
    });

    test('Stop bei leerem Tag ist nicht anwendbar', () {
      expect(decideTimerAction(TimerAction.stop, _entry()),
          TimerDecision.notApplicable);
    });

    test('Stop bei gestopptem Tag ist nicht anwendbar', () {
      expect(decideTimerAction(TimerAction.stop, _entry(start: _t0, end: _t1)),
          TimerDecision.notApplicable);
    });

    test('Stop bei Sonder-Eintrag ist nicht anwendbar', () {
      expect(
          decideTimerAction(
              TimerAction.stop, _entry(start: _t0, type: WorkEntryType.sick)),
          TimerDecision.notApplicable);
    });
  });

  group('Pause und Weiter (Widget, #276)', () {
    final openBreak = [
      BreakEntity(id: 'b', name: 'Pause', start: DateTime(2026, 10, 5, 10)),
    ];
    final closedBreak = [
      BreakEntity(
        id: 'b',
        name: 'Pause',
        start: DateTime(2026, 10, 5, 10),
        end: DateTime(2026, 10, 5, 10, 15),
      ),
    ];

    test('Pause nur bei laufendem Timer ohne offene Pause', () {
      expect(decideTimerAction(TimerAction.pause, _entry(start: _t0)),
          TimerDecision.apply);
      expect(
          decideTimerAction(
              TimerAction.pause, _entry(start: _t0, breaks: closedBreak)),
          TimerDecision.apply);
      expect(
          decideTimerAction(
              TimerAction.pause, _entry(start: _t0, breaks: openBreak)),
          TimerDecision.notApplicable);
      expect(decideTimerAction(TimerAction.pause, _entry()),
          TimerDecision.notApplicable);
      expect(decideTimerAction(TimerAction.pause, _entry(start: _t0, end: _t1)),
          TimerDecision.notApplicable);
    });

    test('Weiter nur bei offener Pause', () {
      expect(
          decideTimerAction(
              TimerAction.resume, _entry(start: _t0, breaks: openBreak)),
          TimerDecision.apply);
      expect(decideTimerAction(TimerAction.resume, _entry(start: _t0)),
          TimerDecision.notApplicable);
      expect(
          decideTimerAction(TimerAction.resume,
              _entry(start: _t0, end: _t1, breaks: openBreak)),
          TimerDecision.notApplicable);
    });

    test('Pause und Weiter bei Sonder-Eintrag nicht anwendbar', () {
      final e = _entry(start: _t0, type: WorkEntryType.vacation);
      expect(
          decideTimerAction(TimerAction.pause, e), TimerDecision.notApplicable);
    });
  });

  group('Id-Mapping', () {
    test('timerActionFromId kennt alle Aktions-Ids', () {
      expect(timerActionFromId('timer_start'), TimerAction.start);
      expect(timerActionFromId('timer_stop'), TimerAction.stop);
      expect(timerActionFromId('timer_pause'), TimerAction.pause);
      expect(timerActionFromId('timer_resume'), TimerAction.resume);
    });

    test('unbekannt, leer und null ergeben null', () {
      expect(timerActionFromId('open_dashboard'), isNull);
      expect(timerActionFromId(''), isNull);
      expect(timerActionFromId(null), isNull);
    });

    test('timerActionId ist die Umkehrung', () {
      for (final a in TimerAction.values) {
        expect(timerActionFromId(timerActionId(a)), a);
      }
    });
  });
}
