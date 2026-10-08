import 'dart:async';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/usecases/toggle_break.dart';
import 'package:flutter_work_time/presentation/state/dashboard_state.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';

import '../../support/dashboard_harness.dart';
import '../../support/fake_repositories.dart';

// Reentranz-Sperre der Schreibaktionen im DashboardViewModel (#413).
// Feste Daten: Mo 2026-10-05, Soll Mo-Fr 8 h, Saldo 120 min, Uhr 17:00. Der
// Stop von 08:00-17:00 ergibt 45 min Auto-Pause und Saldo 135 min. Ein
// verworfener zweiter Aufruf liefert sofort `true`. Jeder Hold wird vor dem
// Szenario-Ende freigegeben (offene Completer/Timeout-Timer loesen sonst den
// Timer-Leak-Check aus).
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  final mo = DateTime(2026, 10, 5);
  final moKey = dayKey(mo);
  final di = DateTime(2026, 10, 6);
  final diKey = dayKey(di);
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
    'A:overtime:135',
    'A:lastUpdate',
    'A:entry:$moKey:08:00-17:00',
  ];

  /// Startet [f], flusht Microtasks und liefert das (ggf. noch offene)
  /// Ergebnis. Ein Wurf landet in `error()`.
  ({bool? Function() value, bool Function() done, Object? Function() error})
      tap(Harness h, Future<bool> Function() f) {
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

  /// Gibt alle Holds aller Repos frei.
  void releaseAll(Harness h) {
    h.work.holdReads = false;
    h.work.holdSaves = false;
    h.workB.holdReads = false;
    h.workB.holdSaves = false;
    h.overtime.holdSaveOvertime = false;
    h.overtimeB.holdSaveOvertime = false;
    for (final list in [
      h.work.pendingReads,
      h.work.pendingSaves,
      h.workB.pendingReads,
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

  group('B1-B6 Doppeltippen', () {
    scenario('B1 Doppel-Start: genau ein Write, zweiter Tap verworfen', at(17),
        (h) {
      h.boot();
      h.work.holdSaves = true;
      final r1 = tap(h, h.vm.startOrStopTimer);
      final r2 = tap(h, h.vm.startOrStopTimer);

      expect(h.work.pendingSaves, hasLength(1));
      expect(r2.done(), isTrue);
      expect(r2.value(), isTrue);
      expect(h.state.workEntry.workStart, at(17));
      expect(h.state.workEntry.workEnd, isNull);

      releaseAll(h);
      expect(r1.value(), isTrue);
      expect(h.writeLog, ['A:entry:$moKey:17:00--']);
      expect(h.async.periodicTimerCount, 1);
      expect(h.overtime.saveOvertimeCalls, 0);
    }, setUp: prep(empty), profiles: true);

    scenario('B2 Doppel-Stop: genau ein Saldo-/Eintrag-Write, danach frei',
        at(17), (h) {
      h.boot();
      h.overtime.holdSaveOvertime = true;
      final r1 = tap(h, h.vm.startOrStopTimer);
      final r2 = tap(h, h.vm.startOrStopTimer);

      expect(h.overtime.pendingOvertimeSaves, hasLength(1));
      expect(r2.done(), isTrue);
      expect(r2.value(), isTrue);

      releaseAll(h);
      expect(r1.value(), isTrue);
      expect(h.writeLog, stopWrites);
      expect(h.overtime.saveOvertimeCalls, 1);

      final r3 = tap(h, h.vm.startNewSession);
      expect(r3.value(), isTrue);
      expect(h.work.saved, hasLength(2));
      expect(h.state.workEntry.workEnd, isNull);
    }, setUp: prep(running), profiles: true);

    scenario('B3a Flag frei nach Saldo-Fehler', at(17), (h) {
      h.boot();
      h.overtime.failSaveOvertime = true;
      final r1 = tap(h, h.vm.startOrStopTimer);
      expect(r1.value(), isFalse);
      expect(h.state.isSaving, isFalse);

      h.overtime.failSaveOvertime = false;
      final r2 = tap(h, h.vm.startOrStopTimer);
      expect(r2.value(), isTrue);
      expect(h.writeLog, stopWrites);
    }, setUp: prep(running), profiles: true);

    scenario('B3b Flag frei nach Wurf im Body, Wurf erreicht den Aufrufer',
        at(17), (h) {
      h.boot();
      final r1 = tap(h, h.vm.startOrStopBreak);
      expect(r1.done(), isTrue);
      expect(r1.error(), isA<StateError>());
      expect(h.state.isSaving, isFalse);

      final r2 = tap(h, h.vm.startOrStopTimer);
      expect(r2.value(), isTrue);
      expect(h.writeLog, stopWrites);
    }, setUp: prep(running), profiles: true, overrides: [
      toggleBreakUseCaseProvider
          .overrideWith((ref) => _ThrowingToggleBreak(ref.watch(clockProvider))),
    ]);

    scenario('B4 Pause/Pause: eine Pause, ein Write', at(17), (h) {
      h.boot();
      h.work.holdSaves = true;
      final r1 = tap(h, h.vm.startOrStopBreak);
      final r2 = tap(h, h.vm.startOrStopBreak);

      expect(h.state.workEntry.breaks, hasLength(1));
      expect(h.state.workEntry.breaks.single.end, isNull);
      expect(h.work.pendingSaves, hasLength(1));
      expect(r2.done(), isTrue);
      expect(r2.value(), isTrue);

      releaseAll(h);
      expect(r1.value(), isTrue);
      expect(h.work.saved, hasLength(1));
      expect(h.work.saved.single.breaks.single.end, isNull);
    }, setUp: prep(running), profiles: true);

    scenario('B5a Pause + Stop: Stop verworfen', at(17), (h) {
      h.boot();
      h.work.holdSaves = true;
      final r1 = tap(h, h.vm.startOrStopBreak);
      final r2 = tap(h, h.vm.startOrStopTimer);

      expect(r2.done(), isTrue);
      expect(r2.value(), isTrue);
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.work.pendingSaves, hasLength(1));
      expect(h.overtime.saveOvertimeCalls, 0);

      releaseAll(h);
      expect(r1.value(), isTrue);
      expect(h.writeLog, ['A:entry:$moKey:08:00--']);
      expect(h.state.workEntry.workEnd, isNull);
    }, setUp: prep(running), profiles: true);

    scenario('B5b Stop + Pause: Pause verworfen', at(17), (h) {
      h.boot();
      h.overtime.holdSaveOvertime = true;
      final r1 = tap(h, h.vm.startOrStopTimer);
      final r2 = tap(h, h.vm.startOrStopBreak);

      expect(r2.done(), isTrue);
      expect(r2.value(), isTrue);
      expect(h.state.workEntry.breaks, isEmpty);
      expect(h.writeLog, isEmpty);
      expect(h.work.saved, isEmpty);

      releaseAll(h);
      expect(r1.value(), isTrue);
      expect(h.writeLog, stopWrites);
    }, setUp: prep(running), profiles: true);

    scenario('B6 manuelle Endzeit + Stop: genau ein Saldo-Write', at(17), (h) {
      h.boot();
      h.overtime.holdSaveOvertime = true;
      final r1 =
          tap(h, () => h.vm.setManualEndTime(const TimeOfDay(hour: 16, minute: 0)));
      final r2 = tap(h, h.vm.startOrStopTimer);

      expect(h.overtime.pendingOvertimeSaves, hasLength(1));
      expect(r2.done(), isTrue);
      expect(r2.value(), isTrue);

      releaseAll(h);
      expect(r1.value(), isTrue);
      expect(h.overtime.saveOvertimeCalls, 1);
      expect(h.writeLog.where((e) => e.contains(':overtime:')), hasLength(1));
    }, setUp: prep(running), profiles: true);
  });

  group('B7 alle neun Aktionen', () {
    final actions = <String,
        ({
      WorkEntryEntity seed,
      bool saldo,
      Future<bool> Function(Harness) run
    })>{
      'startOrStopTimer': (
        seed: running,
        saldo: true,
        run: (h) => h.vm.startOrStopTimer()
      ),
      'startNewSession': (
        seed: finishedWithBreak,
        saldo: false,
        run: (h) => h.vm.startNewSession()
      ),
      'startNewSessionKeepBreaks': (
        seed: finishedWithBreak,
        saldo: false,
        run: (h) => h.vm.startNewSessionKeepBreaks()
      ),
      'setManualStartTime': (
        seed: finished,
        saldo: true,
        run: (h) =>
            h.vm.setManualStartTime(const TimeOfDay(hour: 8, minute: 30))
      ),
      'setManualEndTime': (
        seed: running,
        saldo: true,
        run: (h) => h.vm.setManualEndTime(const TimeOfDay(hour: 16, minute: 30))
      ),
      'clearEndTime': (
        seed: finishedWithBreak,
        saldo: false,
        run: (h) => h.vm.clearEndTime()
      ),
      'startOrStopBreak': (
        seed: finished,
        saldo: true,
        run: (h) => h.vm.startOrStopBreak()
      ),
      'deleteBreak': (
        seed: finishedWithBreak,
        saldo: true,
        run: (h) => h.vm.deleteBreak('b1')
      ),
      'updateBreak': (
        seed: finishedWithBreak,
        saldo: true,
        run: (h) => h.vm.updateBreak(breakB1.copyWith(end: at(12, 45)))
      ),
    };

    for (final e in actions.entries) {
      scenario('${e.key}: zweiter Aufruf waehrend der ersten verworfen', at(17),
          (h) {
        h.boot();
        if (e.value.saldo) {
          h.overtime.holdSaveOvertime = true;
        } else {
          h.work.holdSaves = true;
        }
        final r1 = tap(h, () => e.value.run(h));
        final pending = e.value.saldo
            ? h.overtime.pendingOvertimeSaves
            : h.work.pendingSaves;
        expect(pending, hasLength(1));
        expect(h.state.isSaving, isTrue);

        final r2 = tap(h, () => e.value.run(h));
        expect(r2.done(), isTrue);
        expect(r2.value(), isTrue);
        expect(pending, hasLength(1));

        releaseAll(h);
        expect(r1.value(), isTrue);
        expect(h.state.isSaving, isFalse);
        expect(h.work.saved, hasLength(1));
        expect(h.overtime.saveOvertimeCalls, e.value.saldo ? 1 : 0);
      }, setUp: prep(e.value.seed), profiles: true);
    }
  });

  group('B8 Ladeluecke', () {
    scenario('Tap im Ladefenster sperrt, zweiter Tap verworfen', at(17), (h) {
      h.work.holdReads = true;
      h.boot();
      expect(h.state.isLoading, isTrue);

      final r1 = tap(h, h.vm.startOrStopTimer);
      expect(h.state.isSaving, isTrue);
      expect(h.state.isLoading, isTrue);

      final r2 = tap(h, h.vm.startOrStopTimer);
      expect(r2.done(), isTrue);
      expect(r2.value(), isTrue);
      expect(r1.done(), isFalse);

      releaseAll(h);
      expect(r1.value(), isTrue);
      expect(h.writeLog, ['A:entry:$moKey:17:00--']);
      expect(h.state.workEntry.workStart, at(17));
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.state.isSaving, isFalse);
    }, setUp: prep(empty), profiles: true);
  });

  group('B14 Profilwechsel', () {
    scenario('a: alte Aktion gibt das Flag der neuen nicht frei', at(17), (h) {
      h.boot();
      h.overtime.holdSaveOvertime = true;
      final rA = tap(h, h.vm.startOrStopTimer);
      expect(h.state.isSaving, isTrue);

      h.switchProfile('B');
      expect(h.state.isSaving, isFalse);
      expect(h.state.workEntry.workStart, isNull);

      h.workB.holdSaves = true;
      final rB = tap(h, h.vm.startOrStopTimer);
      expect(h.workB.pendingSaves, hasLength(1));
      expect(h.state.isSaving, isTrue);

      // A schreibt zu Ende (Bestand), das Flag von B bleibt.
      h.overtime.holdSaveOvertime = false;
      h.overtime.pendingOvertimeSaves.single.complete();
      h.async.flushMicrotasks();
      expect(rA.done(), isTrue);
      expect(h.writeLog, containsAllInOrder(stopWrites));
      expect(h.state.isSaving, isTrue);

      final rB2 = tap(h, h.vm.startOrStopTimer);
      expect(rB2.done(), isTrue);
      expect(rB2.value(), isTrue);
      expect(h.workB.pendingSaves, hasLength(1));

      releaseAll(h);
      expect(rB.value(), isTrue);
      expect(h.state.isSaving, isFalse);
      expect(h.writeLog.where((e) => e.startsWith('B:entry')), hasLength(1));
    }, setUp: prep(running), profiles: true);

    scenario('b: Wechsel mitten in der Aktion, Start in B sofort moeglich',
        at(17), (h) {
      h.boot();
      h.overtime.holdSaveOvertime = true;
      tap(h, h.vm.startOrStopTimer);

      h.switchProfile('B');
      final rB = tap(h, h.vm.startOrStopTimer);

      expect(rB.value(), isTrue);
      expect(h.workB.saved, hasLength(1));
      expect(h.state.workEntry.workStart, at(17));
      releaseAll(h);
    }, setUp: prep(running), profiles: true);
  });

  group('B15 Tageswechsel', () {
    scenario('a: Reinit in _ensureCurrentDay behaelt die Sperre', at(23, 59, 50),
        (h) {
      h.boot();
      h.clock.jumpTo(DateTime(2026, 10, 6, 0, 0, 10));
      h.work.holdReads = true;
      final r1 = tap(h, h.vm.startOrStopTimer);
      expect(h.state.isSaving, isTrue);

      final r2 = tap(h, h.vm.startOrStopTimer);
      expect(r2.done(), isTrue);
      expect(r2.value(), isTrue);

      // Reads frei, den Start-Write am Di halten: der Reinit hat den State per
      // Konstruktor neu gebaut und muss die Sperre uebernommen haben.
      h.work.holdSaves = true;
      h.work.holdReads = false;
      for (final c in h.work.pendingReads) {
        if (!c.isCompleted) c.complete();
      }
      h.async.flushMicrotasks();
      expect(h.state.workEntry.date, di);
      expect(h.state.isLoading, isFalse);
      expect(h.state.isSaving, isTrue);
      expect(h.work.pendingSaves, hasLength(1));

      final r3 = tap(h, h.vm.startOrStopTimer);
      expect(r3.value(), isTrue);
      expect(h.work.pendingSaves, hasLength(1));

      releaseAll(h);
      expect(r1.value(), isTrue);
      expect(h.writeLog, hasLength(1));
      expect(h.writeLog.single, startsWith('A:entry:$diKey:'));
      expect(h.state.isSaving, isFalse);
    }, setUp: prep(empty), profiles: true);

    scenario('b: Stop eines Vortags, Reinit haelt die Sperre bis zum Ende',
        at(23), (h) {
      h.boot();
      final seen = <DashboardState>[];
      h.container.listen(dashboardViewModelProvider, (_, n) => seen.add(n));
      h.clock.jumpTo(DateTime(2026, 10, 6, 1));
      h.tick();
      h.overtime.holdSaveOvertime = true;
      final r1 = tap(h, h.vm.startOrStopTimer);
      expect(h.overtime.pendingOvertimeSaves, hasLength(1));

      h.overtime.holdSaveOvertime = false;
      h.overtime.pendingOvertimeSaves.single.complete();
      h.async.flushMicrotasks();

      expect(r1.value(), isTrue);
      expect(h.state.workEntry.date, di);
      expect(h.state.isSaving, isFalse);
      expect(h.async.periodicTimerCount, 0);
      final reinit = seen.firstWhere(
          (s) => s.workEntry.date == di && !s.isLoading,
          orElse: () => fail('kein Reinit-State'));
      expect(reinit.isSaving, isTrue);
    }, setUp: (h) => prep(entryOf(mo, start: at(22)))(h), profiles: true);
  });

  group('B16 Rueckgabe', () {
    scenario('nach Dispose: false ohne Wurf', at(17), (h) {
      h.boot();
      final vm = h.vm;
      h.dispose();
      final r = tap(h, vm.startOrStopTimer);
      expect(r.error(), isNull);
      expect(r.value(), isFalse);
      expect(h.writeLog, isEmpty);
    }, setUp: prep(running), profiles: true);

    scenario('Platzhalter ohne ladbaren Tag: false, nichts geschrieben', at(17),
        (h) {
      h.work.failReads = true;
      h.boot();
      final r = tap(h, h.vm.startOrStopTimer);
      expect(r.value(), isFalse);
      expect(h.writeLog, isEmpty);
      expect(h.state.isSaving, isFalse);
    }, setUp: prep(empty), profiles: true);
  });

  group('B17 isSaving-Verlauf', () {
    scenario('false nach Boot, true im Fenster, false nach Erfolg', at(17),
        (h) {
      h.boot();
      expect(h.state.isSaving, isFalse);

      h.work.holdSaves = true;
      tap(h, h.vm.startOrStopTimer);
      expect(h.state.isSaving, isTrue);
      releaseAll(h);
      expect(h.state.isSaving, isFalse);

      h.overtime.holdSaveOvertime = true;
      tap(h, h.vm.startOrStopTimer);
      expect(h.state.isSaving, isTrue);
      releaseAll(h);
      expect(h.state.isSaving, isFalse);
    }, setUp: prep(empty), profiles: true);

    scenario('false nach false-Ergebnis', at(17), (h) {
      h.boot();
      h.overtime.holdSaveOvertime = true;
      h.overtime.failSaveOvertime = true;
      final r = tap(h, h.vm.startOrStopTimer);
      expect(h.state.isSaving, isTrue);
      releaseAll(h);
      expect(r.value(), isFalse);
      expect(h.state.isSaving, isFalse);
    }, setUp: prep(running), profiles: true);

    scenario('false nach Profilwechsel', at(17), (h) {
      h.boot();
      h.overtime.holdSaveOvertime = true;
      tap(h, h.vm.startOrStopTimer);
      expect(h.state.isSaving, isTrue);
      h.switchProfile('B');
      expect(h.state.isSaving, isFalse);
      releaseAll(h);
      expect(h.state.isSaving, isFalse);
    }, setUp: prep(running), profiles: true);

    scenario('Fehler beim Eintrag-Write: Sperre trotzdem frei', at(17), (h) {
      h.boot();
      h.work.failSaves = true;
      final r = tap(h, h.vm.startOrStopTimer);
      expect(r.value(), isTrue);
      expect(h.state.isSaving, isFalse);
    }, setUp: prep(running), profiles: true);
  });
}

class _ThrowingToggleBreak extends ToggleBreak {
  _ThrowingToggleBreak(DateTime Function() clock) : super(clock: clock);

  @override
  Future<WorkEntryEntity> call(WorkEntryEntity currentEntry) async {
    throw StateError('toggle');
  }
}
