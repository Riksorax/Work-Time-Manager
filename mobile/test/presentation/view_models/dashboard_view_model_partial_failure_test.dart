import 'dart:async';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:logger/logger.dart';

import '../../support/dashboard_harness.dart';
import '../../support/fake_repositories.dart';

typedef Tap = ({
  bool? Function() value,
  bool Function() done,
  Object? Function() error
});

// Teilfehler Eintrag/Saldo im Dashboard (#412). Feste Daten: Mo 2026-10-05,
// Soll Mo-Fr 8 h, Saldo 120 min, Uhr 17:00. Der Stop von 08:00-17:00 ergibt
// 45 min Auto-Pause und Saldo 135 min. Reihenfolge der Writes: Eintrag, Saldo,
// lastUpdate; scheitert der Saldo, wird der Eintrag auf den Vorzustand
// zurueckgeschrieben. Jeder Hold wird vor Szenario-Ende freigegeben.
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  final mo = DateTime(2026, 10, 5);
  final moKey = dayKey(mo);
  final di = DateTime(2026, 10, 6);
  DateTime at(int h, [int m = 0, int s = 0]) => DateTime(2026, 10, 5, h, m, s);

  final empty = entryOf(mo);
  final running = entryOf(mo, start: at(8));
  final finished = entryOf(mo, start: at(8), end: at(17));
  final breakB1 =
      BreakEntity(id: 'b1', name: 'Pause 1', start: at(12), end: at(12, 30));
  final finishedWithBreak =
      entryOf(mo, start: at(8), end: at(17), breaks: [breakB1]);

  void Function(Harness) prep(WorkEntryEntity a) => (h) {
        h.seed(a);
        h.overtime.stored = const Duration(minutes: 120);
        h.workB.store[moKey] = entryOf(mo);
        h.overtimeB.stored = const Duration(minutes: 30);
      };

  final stopWrites = [
    'A:entry:$moKey:08:00-17:00',
    'A:overtime:135',
    'A:lastUpdate',
  ];
  final entryAlt = 'A:entry:$moKey:08:00--';

  Tap tap(Harness h, Future<bool> Function() f) {
    bool? result;
    Object? error;
    var done = false;
    unawaited(f().then((v) {
      result = v;
      done = true;
    }, onError: (Object e) {
      error = e;
      done = true;
    }));
    h.async.flushMicrotasks();
    return (value: () => result, done: () => done, error: () => error);
  }

  void releaseAll(Harness h) {
    h.work.holdSaves = false;
    h.workB.holdSaves = false;
    h.overtime.holdSaveOvertime = false;
    h.overtimeB.holdSaveOvertime = false;
    for (final list in [
      h.work.pendingSaves,
      h.workB.pendingSaves,
      h.overtime.pendingOvertimeSaves,
      h.overtimeB.pendingOvertimeSaves,
    ]) {
      for (final c in list) {
        if (!c.isCompleted) c.complete();
      }
    }
    h.async.flushMicrotasks();
  }

  /// Faengt Error-Level-Logs waehrend [body] (Text ohne Stacktrace).
  String errorLogs(void Function() body) {
    final events = <LogEvent>[];
    Logger.addLogListener(events.add);
    try {
      body();
    } finally {
      Logger.removeLogListener(events.add);
    }
    return events
        .where((e) => e.level == Level.error)
        .map((e) => '${e.message} ${e.error}')
        .join(' | ');
  }

  // Aktionen auf geschlossenem Eintrag (E3/E5).
  final closedActions =
      <String, ({WorkEntryEntity seed, Future<bool> Function(Harness) run})>{
    'setManualEndTime': (
      seed: finishedWithBreak,
      run: (h) => h.vm.setManualEndTime(const TimeOfDay(hour: 16, minute: 30))
    ),
    'setManualStartTime': (
      seed: finished,
      run: (h) => h.vm.setManualStartTime(const TimeOfDay(hour: 8, minute: 30))
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

  group('E1 Reihenfolge Eintrag vor Saldo', () {
    scenario('Erfolg: Eintrag, Saldo, lastUpdate', at(17), (h) {
      h.boot();
      final r = tap(h, h.vm.startOrStopTimer);
      expect(r.value(), isTrue);
      expect(h.writeLog, stopWrites);
    }, setUp: prep(running), profiles: true);

    scenario('Eintrag gehalten: kein Saldo-Write, State laeuft noch', at(17),
        (h) {
      h.boot();
      h.work.holdSaves = true;
      final r = tap(h, h.vm.startOrStopTimer);
      expect(h.work.pendingSaves, hasLength(1));
      expect(h.overtime.saveOvertimeCalls, 0);
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.state.isSaving, isTrue);

      h.work.holdSaves = false;
      h.work.pendingSaves.single.complete();
      h.async.flushMicrotasks();
      expect(r.value(), isTrue);
      expect(h.writeLog, stopWrites);
    }, setUp: prep(running), profiles: true);

    scenario(
        'Saldo gehalten: Eintrag im Log, State und Timer unveraendert', at(17),
        (h) {
      h.boot();
      h.overtime.holdSaveOvertime = true;
      final r = tap(h, h.vm.startOrStopTimer);
      expect(h.overtime.pendingOvertimeSaves, hasLength(1));
      expect(h.writeLog, ['A:entry:$moKey:08:00-17:00']);
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.async.periodicTimerCount, 1);

      releaseAll(h);
      expect(r.value(), isTrue);
      expect(h.state.workEntry.workEnd, at(17));
      expect(h.async.periodicTimerCount, 0);
    }, setUp: prep(running), profiles: true);
  });

  group('E2 Eintrag-Fehler beim Stop', () {
    scenario(
        'false, nichts geschrieben, State/Timer unveraendert, Log ohne Daten',
        at(17), (h) {
      h.boot();
      h.work.failSaves = true;
      late Tap r;
      final logs = errorLogs(() => r = tap(h, h.vm.startOrStopTimer));

      expect(r.error(), isNull);
      expect(r.value(), isFalse);
      expect(h.writeLog, isEmpty);
      expect(h.work.saved, isEmpty);
      expect(h.overtime.savedOvertimes, isEmpty);
      expect(h.overtime.saveOvertimeCalls, 0);
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.async.periodicTimerCount, 1);
      expect(h.state.isSaving, isFalse);
      expect(logs, contains('Eintrag'));
      expect(logs, isNot(contains('offline')));
      expect(logs, isNot(contains('2026-10-05')));
    }, setUp: prep(running), profiles: true);

    scenario('Wiederholen: genau ein Saldo-Write', at(17), (h) {
      h.boot();
      h.work.failSaves = true;
      expect(tap(h, h.vm.startOrStopTimer).value(), isFalse);
      h.work.failSaves = false;
      expect(tap(h, h.vm.startOrStopTimer).value(), isTrue);
      expect(h.writeLog, stopWrites);
      expect(h.overtime.saveOvertimeCalls, 1);
    }, setUp: prep(running), profiles: true);

    scenario('Autosave schreibt danach den laufenden Eintrag', at(17), (h) {
      h.boot();
      h.work.failSaves = true;
      tap(h, h.vm.startOrStopTimer);
      h.work.failSaves = false;
      h.tick(const Duration(seconds: 30));
      expect(h.work.saved.last.workEnd, isNull);
      expect(h.work.saved.last.workStart, at(8));
    }, setUp: prep(running), profiles: true);
  });

  group('E3 Eintrag-Fehler auf geschlossenem Eintrag', () {
    for (final e in closedActions.entries) {
      scenario('${e.key}: false, nichts veraendert, Reload ohne Verfaelschung',
          at(17), (h) {
        h.boot();
        final stateBefore = h.state;
        h.work.failSaves = true;
        final r = tap(h, () => e.value.run(h));

        expect(r.error(), isNull);
        expect(r.value(), isFalse);
        expect(identical(h.work.store[moKey], e.value.seed), isTrue);
        expect(h.state.workEntry, stateBefore.workEntry);
        expect(h.state.initialOvertime, stateBefore.initialOvertime);
        expect(h.state.totalOvertime, stateBefore.totalOvertime);
        expect(h.overtime.stored, const Duration(minutes: 120));
        expect(h.overtime.saveOvertimeCalls, 0);

        // Folge-Beleg: ein Reload verfaelscht die Saldo-Basis nicht.
        h.switchProfile('B');
        h.switchProfile(null);
        expect(h.state.initialOvertime, stateBefore.initialOvertime);

        h.work.failSaves = false;
        expect(tap(h, () => e.value.run(h)).value(), isTrue);
        expect(h.writeLog.length, 3);
        expect(h.writeLog[0], startsWith('A:entry:'));
        expect(h.writeLog[1], startsWith('A:overtime:'));
        expect(h.writeLog[2], 'A:lastUpdate');
      }, setUp: prep(e.value.seed), profiles: true);
    }
  });

  group('E4 Saldo-Fehler beim Stop', () {
    scenario('false, Eintrag neu dann Vorzustand, State laeuft', at(17), (h) {
      h.boot();
      h.overtime.failSaveOvertime = true;
      final r = tap(h, h.vm.startOrStopTimer);

      expect(r.value(), isFalse);
      expect(h.writeLog, ['A:entry:$moKey:08:00-17:00', entryAlt]);
      expect(h.work.store[moKey], running);
      expect(h.overtime.lastUpdate, isNull);
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.async.periodicTimerCount, 1);
      expect(h.state.isSaving, isFalse);

      h.overtime.failSaveOvertime = false;
      h.writeLog.clear();
      expect(tap(h, h.vm.startOrStopTimer).value(), isTrue);
      expect(h.writeLog, stopWrites);
    }, setUp: prep(running), profiles: true);
  });

  group('E5 Saldo-Fehler auf geschlossenem Eintrag', () {
    for (final e in closedActions.entries) {
      scenario('${e.key}: false, Paar neu + alt, store = Seed', at(17), (h) {
        h.boot();
        final stateBefore = h.state;
        h.overtime.failSaveOvertime = true;
        final r = tap(h, () => e.value.run(h));

        expect(r.value(), isFalse);
        expect(h.work.saved, hasLength(2));
        expect(h.work.saved[0], isNot(e.value.seed));
        expect(h.work.saved[1], e.value.seed);
        expect(h.work.store[moKey], e.value.seed);
        expect(h.writeLog.where((l) => l.contains('overtime')), isEmpty);
        expect(h.state.workEntry, stateBefore.workEntry);
        expect(h.state.totalOvertime, stateBefore.totalOvertime);
      }, setUp: prep(e.value.seed), profiles: true);
    }
  });

  group('E6 lastUpdated-Kopplung', () {
    scenario('a: Saldo-Fehler laesst lastUpdate unberuehrt', at(17), (h) {
      h.boot();
      h.overtime.lastUpdate = at(9);
      h.overtime.failSaveOvertime = true;
      tap(h, h.vm.startOrStopTimer);
      expect(h.overtime.lastUpdate, at(9));
      expect(h.overtime.savedKeepLastUpdated, isEmpty);
    }, setUp: prep(running), profiles: true);

    scenario(
        'b: lastUpdate-Fehler nach Saldo: false, Eintrag kompensiert', at(17),
        (h) {
      h.boot();
      h.overtime.failSaveLastUpdate = true;
      final r = tap(h, h.vm.startOrStopTimer);
      expect(r.value(), isFalse);
      expect(h.work.store[moKey], running);
      // Bekannte Grenze: der Saldo ist bereits neu, lastUpdate alt.
      expect(h.overtime.stored, const Duration(minutes: 135));
      expect(h.overtime.lastUpdate, isNull);
      expect(h.state.workEntry.workEnd, isNull);
    }, setUp: prep(running), profiles: true);

    scenario('c: Eintrag-Fehler schreibt weder Saldo noch lastUpdate', at(17),
        (h) {
      h.boot();
      h.overtime.lastUpdate = at(9);
      h.work.failSaves = true;
      tap(h, h.vm.startOrStopTimer);
      expect(h.overtime.lastUpdate, at(9));
      expect(h.overtime.saveOvertimeCalls, 0);
    }, setUp: prep(running), profiles: true);
  });

  group('E7 Kompensation scheitert', () {
    scenario('Stop-Fall: kein Wurf, false, Autosave heilt', at(17), (h) {
      h.boot();
      h.overtime.failSaveOvertime = true;
      h.work.failSaveCalls.add(2);
      late Tap r;
      final logs = errorLogs(() => r = tap(h, h.vm.startOrStopTimer));

      expect(r.error(), isNull);
      expect(r.value(), isFalse);
      expect(h.writeLog, ['A:entry:$moKey:08:00-17:00']);
      expect(logs, contains('Kompensation'));
      expect(logs, isNot(contains('offline')));
      expect(logs, isNot(contains('2026-10-05')));
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.async.periodicTimerCount, 1);
      expect(h.work.store[moKey]!.workEnd, at(17));

      h.tick(const Duration(seconds: 30));
      expect(h.work.store[moKey], running);
    }, setUp: prep(running), profiles: true);

    scenario('geschlossener Eintrag: Grenze festgeschrieben, Wiederholen heilt',
        at(17), (h) {
      h.boot();
      h.overtime.failSaveOvertime = true;
      h.work.failSaveCalls.add(2);
      final r =
          tap(h, () => h.vm.updateBreak(breakB1.copyWith(end: at(12, 45))));
      expect(r.value(), isFalse);
      expect(h.state.workEntry, finishedWithBreak);
      // Bekannte Grenze (Doppelfehler): Eintrag neu, Saldo alt.
      expect(h.work.store[moKey], isNot(finishedWithBreak));
      expect(h.overtime.stored, const Duration(minutes: 120));

      h.overtime.failSaveOvertime = false;
      final r2 =
          tap(h, () => h.vm.updateBreak(breakB1.copyWith(end: at(12, 45))));
      expect(r2.value(), isTrue);
      expect(h.work.store[moKey]!.breaks.single.end, at(12, 45));
      expect(h.overtime.stored, isNot(const Duration(minutes: 120)));
    }, setUp: prep(finishedWithBreak), profiles: true);
  });

  group('E8 Vortags-Lauf ueber Mitternacht', () {
    final night = entryOf(mo, start: at(22));
    void jump(Harness h) {
      h.boot();
      h.clock.jumpTo(DateTime(2026, 10, 6, 1));
      h.tick();
    }

    scenario(
        'Erfolg: Reinit auf Di, Reihenfolge Eintrag, Saldo, lastUpdate', at(23),
        (h) {
      jump(h);
      expect(tap(h, h.vm.startOrStopTimer).value(), isTrue);
      h.async.flushMicrotasks();
      expect(h.writeLog[0], startsWith('A:entry:$moKey:22:00-01:00'));
      expect(h.writeLog[1], startsWith('A:overtime:'));
      expect(h.writeLog[2], 'A:lastUpdate');
      expect(h.state.workEntry.date, di);
    }, setUp: prep(night), profiles: true);

    scenario('Eintrag-Fehler: false, kein Reinit, kein Saldo-Write', at(23),
        (h) {
      jump(h);
      h.work.failSaves = true;
      expect(tap(h, h.vm.startOrStopTimer).value(), isFalse);
      h.async.flushMicrotasks();
      expect(h.state.workEntry.date, mo);
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.async.periodicTimerCount, 1);
      expect(h.overtime.saveOvertimeCalls, 0);
    }, setUp: prep(night), profiles: true);

    scenario(
        'Saldo-Fehler: false, kein Reinit, Kompensation geschrieben', at(23),
        (h) {
      jump(h);
      h.overtime.failSaveOvertime = true;
      expect(tap(h, h.vm.startOrStopTimer).value(), isFalse);
      h.async.flushMicrotasks();
      expect(h.state.workEntry.date, mo);
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.async.periodicTimerCount, 1);
      expect(h.writeLog.last, 'A:entry:$moKey:22:00--');
    }, setUp: prep(night), profiles: true);
  });

  group('E9 Tageswechsel im Schreibfenster', () {
    final lateEntry = entryOf(mo, start: at(8));

    void startHeld(Harness h) {
      h.boot();
      h.clock.jumpTo(at(23, 59, 20));
      h.tick();
    }

    scenario('Freigabe: laeuft im Fenster weiter, danach Reinit auf Di',
        at(23, 59, 20), (h) {
      startHeld(h);
      h.work.holdSaves = true;
      final r = tap(h, h.vm.startOrStopTimer);
      h.clock.jumpTo(DateTime(2026, 10, 6, 0, 0, 10));
      h.tick();
      expect(h.state.workEntry.date, mo);
      expect(h.state.workEntry.workEnd, isNull);

      h.work.holdSaves = false;
      h.work.pendingSaves.single.complete();
      h.async.flushMicrotasks();
      expect(r.value(), isTrue);
      expect(h.state.workEntry.date, di);
    }, setUp: prep(lateEntry), profiles: true);

    scenario('Eintrag-Fehler: weiter laufend, kein Reinit', at(23, 59, 20),
        (h) {
      startHeld(h);
      h.work.holdSaves = true;
      final r = tap(h, h.vm.startOrStopTimer);
      h.clock.jumpTo(DateTime(2026, 10, 6, 0, 0, 10));
      h.tick();
      h.work.failSaves = true;
      h.work.holdSaves = false;
      h.work.pendingSaves.single.complete();
      h.async.flushMicrotasks();
      expect(r.value(), isFalse);
      expect(h.state.workEntry.date, mo);
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.async.periodicTimerCount, 1);
    }, setUp: prep(lateEntry), profiles: true);
  });

  group('E10 Profilwechsel mitten in der Aktion', () {
    scenario('Saldo-Fehler ueberholt: Kompensation in A, nichts in B', at(17),
        (h) {
      h.boot();
      h.overtime.holdSaveOvertime = true;
      final r = tap(h, h.vm.startOrStopTimer);
      h.switchProfile('B');
      final stateB = h.state;
      final timersB = h.async.periodicTimerCount;
      h.overtime.failSaveOvertime = true;
      h.overtime.holdSaveOvertime = false;
      h.overtime.pendingOvertimeSaves.single.complete();
      h.async.flushMicrotasks();

      expect(r.value(), isFalse);
      expect(h.writeLog, ['A:entry:$moKey:08:00-17:00', entryAlt]);
      expect(h.writeLog.where((l) => l.startsWith('B:')), isEmpty);
      expect(h.state.workEntry, stateB.workEntry);
      expect(h.state.isSaving, stateB.isSaving);
      expect(h.async.periodicTimerCount, timersB);
    }, setUp: prep(running), profiles: true);

    scenario('Eintrag-Fehler ueberholt: false, nichts in B', at(17), (h) {
      h.boot();
      h.work.holdSaves = true;
      final r = tap(h, h.vm.startOrStopTimer);
      h.switchProfile('B');
      final stateB = h.state;
      h.work.failSaves = true;
      h.work.holdSaves = false;
      h.work.pendingSaves.single.complete();
      h.async.flushMicrotasks();

      expect(r.value(), isFalse);
      expect(h.writeLog, isEmpty);
      expect(h.state.workEntry, stateB.workEntry);
    }, setUp: prep(running), profiles: true);

    scenario('Erfolg ueberholt: true, Writes in A', at(17), (h) {
      h.boot();
      h.work.holdSaves = true;
      final r = tap(h, h.vm.startOrStopTimer);
      h.switchProfile('B');
      h.work.holdSaves = false;
      h.work.pendingSaves.single.complete();
      h.async.flushMicrotasks();

      expect(r.value(), isTrue);
      expect(h.writeLog, stopWrites);
    }, setUp: prep(running), profiles: true);
  });

  group('E11 Gegenproben: Aktionen ohne Saldo-Block bleiben optimistisch', () {
    scenario('Pause auf laufendem Eintrag + Eintrag-Fehler: true', at(17), (h) {
      h.boot();
      h.work.failSaves = true;
      expect(tap(h, h.vm.startOrStopBreak).value(), isTrue);
      expect(h.async.periodicTimerCount, 1);
      expect(h.state.workEntry.breaks, hasLength(1));
    }, setUp: prep(running), profiles: true);

    scenario('Start + Eintrag-Fehler: true, Timer laeuft', at(17), (h) {
      h.boot();
      h.work.failSaves = true;
      expect(tap(h, h.vm.startOrStopTimer).value(), isTrue);
      expect(h.state.workEntry.workStart, at(17));
      expect(h.async.periodicTimerCount, 1);
    }, setUp: prep(empty), profiles: true);

    final noSaldo = <String, Future<bool> Function(Harness)>{
      'clearEndTime': (h) => h.vm.clearEndTime(),
      'startNewSession': (h) => h.vm.startNewSession(),
      'startNewSessionKeepBreaks': (h) => h.vm.startNewSessionKeepBreaks(),
    };
    for (final e in noSaldo.entries) {
      scenario('${e.key} + Eintrag-Fehler: true, Timer laeuft', at(17), (h) {
        h.boot();
        h.work.failSaves = true;
        expect(tap(h, () => e.value(h)).value(), isTrue);
        expect(h.state.workEntry.workEnd, isNull);
        expect(h.async.periodicTimerCount, 1);
      }, setUp: prep(finishedWithBreak), profiles: true);
    }
  });

  // Timeouts: Aktionsbeginn auf t=5 s, damit der Autosave-Tick (Sekunde 30)
  // nicht mit dem Timeout (t=35) zusammenfaellt.
  group('E12/E15/E16 Timeouts', () {
    scenario(
        'E12 Eintrag-Timeout: false wie Fehler, spaetes Landen bekannt', at(17),
        (h) {
      h.boot();
      h.tick(const Duration(seconds: 5));
      h.work.holdSaves = true;
      late Tap r;
      late Tap r2;
      final logs = errorLogs(() {
        r = tap(h, h.vm.startOrStopTimer);
        expect(h.work.pendingSaves, hasLength(1));
        h.work.holdSaves = false;
        h.tick(const Duration(seconds: 29));
        expect(r.done(), isFalse);
        r2 = tap(h, h.vm.startOrStopTimer);
        expect(r2.value(), isTrue);
        h.tick();
      });

      expect(r.done(), isTrue);
      expect(r.value(), isFalse);
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.async.periodicTimerCount, 1);
      expect(h.state.isSaving, isFalse);
      expect(h.overtime.saveOvertimeCalls, 0);
      expect(logs, contains('TimeoutException'));
      expect(logs, isNot(contains('2026-10-05')));

      // Bekannte Grenze: der aufgegebene Write ist nicht abbrechbar und landet
      // spaeter; ein Saldo-Write folgt daraus nie. Autosave/Wiederholen
      // ueberschreibt den Eintrag.
      h.work.pendingSaves.single.complete();
      h.async.flushMicrotasks();
      expect(h.overtime.saveOvertimeCalls, 0);
      expect(h.state.workEntry.workEnd, isNull);
    }, setUp: prep(running), profiles: true);

    scenario(
        'E15 Saldo-Timeout: false, Kompensation direkt, spaeter Saldo '
        'ohne Folgeschritte',
        at(17), (h) {
      h.boot();
      h.tick(const Duration(seconds: 5));
      h.overtime.holdSaveOvertime = true;
      final r = tap(h, h.vm.startOrStopTimer);
      h.tick(const Duration(seconds: 29));
      expect(r.done(), isFalse);
      h.tick();

      expect(r.value(), isFalse);
      expect(h.writeLog, ['A:entry:$moKey:08:00-17:00', entryAlt]);
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.state.isSaving, isFalse);

      h.overtime.holdSaveOvertime = false;
      h.overtime.pendingOvertimeSaves.single.complete();
      h.async.flushMicrotasks();
      expect(h.writeLog, [
        'A:entry:$moKey:08:00-17:00',
        entryAlt,
        'A:overtime:135',
      ]);
      expect(h.writeLog.where((l) => l.contains('lastUpdate')), isEmpty);

      expect(tap(h, h.vm.startOrStopTimer).value(), isTrue);
      expect(h.writeLog.last, 'A:lastUpdate');
      expect(h.state.workEntry.workEnd, isNotNull);
    }, setUp: prep(running), profiles: true);

    scenario('E16 Kompensation-Timeout: false nach 30 s, Flag frei', at(17),
        (h) {
      h.boot();
      h.tick(const Duration(seconds: 5));
      h.overtime.failSaveOvertime = true;
      h.work.holdSaves = true;
      final r = tap(h, h.vm.startOrStopTimer);
      expect(h.work.pendingSaves, hasLength(1));
      h.work.pendingSaves.first.complete();
      h.async.flushMicrotasks();
      expect(h.work.pendingSaves, hasLength(2));
      expect(r.done(), isFalse);

      h.tick(const Duration(seconds: 29));
      expect(r.done(), isFalse);
      h.tick();
      expect(r.value(), isFalse);
      expect(h.state.isSaving, isFalse);

      h.work.holdSaves = false;
      releaseAll(h);
      h.overtime.failSaveOvertime = false;
      expect(tap(h, h.vm.startOrStopTimer).value(), isTrue);
    }, setUp: prep(running), profiles: true);
  });
}
