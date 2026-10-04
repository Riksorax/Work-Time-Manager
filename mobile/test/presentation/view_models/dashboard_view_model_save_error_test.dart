import 'dart:async';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:logger/logger.dart';

import '../../support/dashboard_harness.dart';
import '../../support/fake_repositories.dart';

// Saldo-Fehler im Dashboard (#402). Feste Daten: Mo 2026-10-05, Soll Mo-Fr 8 h,
// Saldo 120 min, Uhr 17:00. Der Stop von 08:00-17:00 ergibt 45 min Auto-Pause
// und damit Saldo 135 min. Fehler wird ueber `failSaveOvertime` injiziert.
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  final mo = DateTime(2026, 10, 5);
  final moKey = dayKey(mo);
  DateTime at(int h, [int m = 0, int s = 0]) => DateTime(2026, 10, 5, h, m, s);

  final running = entryOf(mo, start: at(8));
  final finished = entryOf(mo, start: at(8), end: at(17));
  final breakB1 =
      BreakEntity(id: 'b1', name: 'Pause 1', start: at(12), end: at(12, 30));
  final finishedWithBreak =
      entryOf(mo, start: at(8), end: at(17), breaks: [breakB1]);

  void Function(Harness) prep(WorkEntryEntity a) => (h) {
        h.seed(a);
        h.overtime.stored = const Duration(minutes: 120);
      };

  /// Startet [action], faengt einen etwaigen Wurf (sonst beendet ein
  /// unbehandelter Zonenfehler den Test) und gibt ihn ueber [errors] zurueck.
  void go(Harness h, List<Object> errors, Future<void> Function() action) {
    unawaited(
        action().then<void>((_) {}, onError: (Object e) => errors.add(e)));
    h.async.flushMicrotasks();
  }

  void releaseSaldo(Harness h) {
    h.overtime.holdSaveOvertime = false;
    h.overtime.pendingOvertimeSaves.single.complete();
    h.async.flushMicrotasks();
  }

  final stopWrites = [
    'A:overtime:135',
    'A:lastUpdate',
    'A:entry:$moKey:08:00-17:00',
  ];

  group('Stop-Pfad bei Saldo-Fehler', () {
    scenario(
        'S-1 kein Wurf, State laeuft, Timer bleibt, nichts geschrieben', at(17),
        (h) {
      h.boot();
      h.overtime.failSaveOvertime = true;
      final errors = <Object>[];
      go(h, errors, h.vm.startOrStopTimer);

      expect(errors, isEmpty);
      expect(h.state.workEntry.workStart, at(8));
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.async.periodicTimerCount, 1);
      expect(h.writeLog, isEmpty);
      expect(h.work.saved, isEmpty);
    }, setUp: prep(running), profiles: true);

    scenario('S-2 Timer laeuft weiter, Autosave schreibt den laufenden Eintrag',
        at(17), (h) {
      h.boot();
      h.overtime.failSaveOvertime = true;
      go(h, [], h.vm.startOrStopTimer);
      final before = h.state.grossWorkDuration!;

      h.tick(const Duration(seconds: 5));
      expect(h.state.grossWorkDuration! > before, isTrue);

      h.tick(const Duration(seconds: 30));
      expect(h.work.saved, isNotEmpty);
      expect(h.work.saved.last.workEnd, isNull);
      expect(h.work.saved.last.workStart, at(8));
    }, setUp: prep(running), profiles: true);

    scenario(
        'S-3 Wiederholen: je ein Saldo- und Eintrag-Write, Timer weg', at(17),
        (h) {
      h.boot();
      h.overtime.failSaveOvertime = true;
      go(h, [], h.vm.startOrStopTimer);

      h.overtime.failSaveOvertime = false;
      final errors = <Object>[];
      go(h, errors, h.vm.startOrStopTimer);

      expect(errors, isEmpty);
      expect(h.writeLog, stopWrites);
      expect(h.state.workEntry.workEnd, at(17));
      expect(h.async.periodicTimerCount, 0);
    }, setUp: prep(running), profiles: true);

    scenario(
        'S-5 Tick im Schreibfenster: Timer laeuft bis zum Setzen des States',
        at(17), (h) {
      h.boot();
      h.overtime.holdSaveOvertime = true;
      go(h, [], h.vm.startOrStopTimer);
      expect(h.overtime.pendingOvertimeSaves, hasLength(1));
      final before = h.state.grossWorkDuration!;

      h.tick(const Duration(seconds: 3));
      expect(h.async.periodicTimerCount, 1);
      expect(h.state.grossWorkDuration! > before, isTrue);

      releaseSaldo(h);
      expect(h.writeLog, stopWrites);
      expect(h.state.workEntry.workEnd, isNotNull);
      expect(h.async.periodicTimerCount, 0);
    }, setUp: prep(running), profiles: true);

    scenario(
        'Fehler wird auf Error-Level geloggt, ohne Eintragsinhalte', at(17),
        (h) {
      h.boot();
      h.overtime.failSaveOvertime = true;
      final events = <LogEvent>[];
      Logger.addLogListener(events.add);
      try {
        go(h, [], h.vm.startOrStopTimer);
      } finally {
        Logger.removeLogListener(events.add);
      }
      final errorsLogged = events
          .where((e) => e.level == Level.error)
          .map((e) => '${e.message} ${e.error}'.toLowerCase())
          .toList();
      expect(errorsLogged, isNotEmpty);
      expect(errorsLogged.join(), contains('saldo'));
      expect(errorsLogged.join(), isNot(contains('2026-10-05')));
    }, setUp: prep(running), profiles: true);
  });

  group('S-4 weitere Aktionen mit Saldo-Block bei Saldo-Fehler', () {
    final actions =
        <String, ({WorkEntryEntity seed, Future<void> Function(Harness) run})>{
      'setManualEndTime': (
        seed: running,
        run: (h) => h.vm.setManualEndTime(const TimeOfDay(hour: 16, minute: 30))
      ),
      'setManualStartTime': (
        seed: finished,
        run: (h) =>
            h.vm.setManualStartTime(const TimeOfDay(hour: 8, minute: 30))
      ),
      'updateBreak': (
        seed: finishedWithBreak,
        run: (h) => h.vm.updateBreak(breakB1.copyWith(end: at(12, 45)))
      ),
      'deleteBreak': (
        seed: finishedWithBreak,
        run: (h) => h.vm.deleteBreak('b1')
      ),
      'startOrStopBreak': (seed: finished, run: (h) => h.vm.startOrStopBreak()),
    };

    for (final e in actions.entries) {
      scenario('${e.key}: kein Wurf, State und Timer unveraendert, kein Write',
          at(17), (h) {
        h.boot();
        final stateBefore = h.state;
        final timers = h.async.periodicTimerCount;
        h.overtime.failSaveOvertime = true;
        final errors = <Object>[];
        go(h, errors, () => e.value.run(h));

        expect(errors, isEmpty);
        expect(h.state.workEntry, stateBefore.workEntry);
        expect(h.state.totalOvertime, stateBefore.totalOvertime);
        expect(h.async.periodicTimerCount, timers);
        expect(h.writeLog, isEmpty);
        expect(h.work.saved, isEmpty);
      }, setUp: prep(e.value.seed), profiles: true);
    }
  });

  group('S-6/S-7 Aktionen ohne Saldo-Block, Ueberholung', () {
    scenario(
        'S-6 startNewSession: Saldo-Fehler irrelevant, Eintrag geschrieben',
        at(17), (h) {
      h.boot();
      h.overtime.failSaveOvertime = true;
      final errors = <Object>[];
      go(h, errors, h.vm.startNewSession);

      expect(errors, isEmpty);
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.work.saved, hasLength(1));
      expect(h.async.periodicTimerCount, 1);
    }, setUp: prep(finished), profiles: true);

    scenario('S-6 startNewSessionKeepBreaks: ebenso', at(17), (h) {
      h.boot();
      h.overtime.failSaveOvertime = true;
      final errors = <Object>[];
      go(h, errors, h.vm.startNewSessionKeepBreaks);

      expect(errors, isEmpty);
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.work.saved, hasLength(1));
      expect(h.async.periodicTimerCount, 1);
    }, setUp: prep(finishedWithBreak), profiles: true);

    scenario(
        'S-7 ueberholt + Saldo-Fehler: B-State und Timer unberuehrt', at(17),
        (h) {
      h.boot();
      h.overtime.holdSaveOvertime = true;
      final errors = <Object>[];
      go(h, errors, h.vm.startOrStopTimer);

      h.switchProfile('B');
      final stateB = h.state;
      h.overtime.failSaveOvertime = true;
      releaseSaldo(h);

      expect(errors, isEmpty);
      expect(h.state.workEntry, stateB.workEntry);
      expect(h.async.periodicTimerCount, 0);
      expect(h.writeLog, isEmpty);
      expect(h.work.saved, isEmpty);
      expect(h.workB.saved, isEmpty);
    }, setUp: (h) {
      prep(running)(h);
      h.workB.store[moKey] = entryOf(mo, start: at(9), end: at(12));
    }, profiles: true);
  });
}
