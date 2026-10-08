import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';

import '../../support/dashboard_harness.dart';
import '../../support/fake_repositories.dart';

// Stop beim Profilwechsel (#388, PR 2): `stopRunningForSwitch` nutzt den
// normalen Stop-Pfad. Feste Daten: Mo 2026-10-05, Uhr 17:00, A laufend ab
// 08:00, Saldo 120 min.
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  final mo = DateTime(2026, 10, 5);
  final moKey = dayKey(mo);
  DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 5, h, m);

  final running = entryOf(mo, start: at(8));
  final finished = entryOf(mo, start: at(8), end: at(17));

  void Function(Harness) prep([WorkEntryEntity? a]) => (h) {
        h.seed(a ?? running);
        h.overtime.stored = const Duration(minutes: 120);
        h.overtimeB.stored = const Duration(minutes: 30);
      };

  /// Startet [f], flusht Microtasks und liefert das (ggf. noch offene)
  /// Ergebnis.
  ({bool? Function() value, bool Function() done}) run(
      Harness h, Future<bool> Function() f) {
    bool? result;
    var done = false;
    unawaited(f().then((v) {
      result = v;
      done = true;
    }));
    h.async.flushMicrotasks();
    return (value: () => result, done: () => done);
  }

  int count(Harness h, String prefix) =>
      h.writeLog.where((e) => e.startsWith(prefix)).length;

  group('stopRunningForSwitch', () {
    scenario('S1 Erfolg: Saldo vor Eintrag, Timer aus, kein Wechsel', at(17),
        (h) {
      h.boot();
      expect(h.async.periodicTimerCount, 1);
      final r = run(h, () => h.vm.stopRunningForSwitch('default'));

      expect(r.value(), isTrue);
      expect(h.writeLog, [
        'A:overtime:135',
        'A:lastUpdate',
        'A:entry:$moKey:08:00-17:00',
      ]);
      expect(h.state.workEntry.workEnd, isNotNull);
      expect(h.async.periodicTimerCount, 0);
      expect(h.container.read(activeWorkProfileIdProvider), isNull);
      expect(count(h, 'B:'), 0);
    }, setUp: prep(), profiles: true);

    scenario('S2 Paritaet zum Stop-Button', at(17), (h) {
      h.boot();
      h.act(h.vm.startOrStopTimer);
      final expectedLog = List<String>.of(h.writeLog);
      final expectedEntry = h.work.store[moKey];
      final expectedSaldo = h.overtime.stored;
      expect(expectedLog, hasLength(3));

      // Zweiter Lauf: Zustand zuruecksetzen und ueber den Switch-Pfad stoppen.
      h.writeLog.clear();
      h.work.store[moKey] = running;
      h.overtime
        ..stored = const Duration(minutes: 120)
        ..lastUpdate = null;
      h.switchProfile('B');
      h.switchProfile(null);
      final r = run(h, () => h.vm.stopRunningForSwitch('default'));

      expect(r.value(), isTrue);
      expect(h.writeLog, expectedLog);
      // Pausen-IDs sind zufaellig: ohne ID vergleichen.
      String sig(WorkEntryEntity? e) =>
          '${e!.workStart}-${e.workEnd}|${e.breaks.map((b) => '${b.name}:${b.start}-${b.end}')}';
      expect(sig(h.work.store[moKey]), sig(expectedEntry));
      expect(h.overtime.stored, expectedSaldo);
      // Pflichtpause: 9 h brutto -> 45 min.
      expect(
          expectedEntry!.breaks.fold<Duration>(
              Duration.zero, (p, b) => p + b.end!.difference(b.start)),
          const Duration(minutes: 45));
    }, setUp: prep(), profiles: true);

    scenario('S3 Saldo-Fehler: false, Timer laeuft weiter, kein Eintrag-Write',
        at(17), (h) {
      h.boot();
      h.overtime.failSaveOvertime = true;
      final r = run(h, () => h.vm.stopRunningForSwitch('default'));

      expect(r.value(), isFalse);
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.async.periodicTimerCount, 1);
      expect(h.writeLog.where((e) => e.contains(':entry:')), isEmpty);
    }, setUp: prep(), profiles: true);

    scenario('S4 nicht laufend (beendet): true ohne Writes', at(17), (h) {
      h.boot();
      final r = run(h, () => h.vm.stopRunningForSwitch('default'));
      expect(r.value(), isTrue);
      expect(h.writeLog, isEmpty);
    }, setUp: prep(finished), profiles: true);

    scenario('S4b nicht laufend (leer): true ohne Writes', at(17), (h) {
      h.boot();
      final r = run(h, () => h.vm.stopRunningForSwitch('default'));
      expect(r.value(), isTrue);
      expect(h.writeLog, isEmpty);
    }, setUp: prep(entryOf(mo)), profiles: true);

    scenario('S5 Profil nicht mehr from: false, keine Writes', at(17), (h) {
      h.boot();
      h.switchProfile('B');
      final r = run(h, () => h.vm.stopRunningForSwitch('default'));
      expect(r.value(), isFalse);
      expect(h.writeLog, isEmpty);
    }, setUp: prep(), profiles: true);

    scenario('S6 Ladelauf: wartet ab, stoppt danach', at(17), (h) {
      h.work.holdReads = true;
      h.boot();
      expect(h.state.isLoading, isTrue);
      final r = run(h, () => h.vm.stopRunningForSwitch('default'));
      expect(r.done(), isFalse);
      expect(h.writeLog, isEmpty);

      h.work.holdReads = false;
      for (final c in h.work.pendingReads) {
        c.complete();
      }
      h.async.flushMicrotasks();

      expect(r.done(), isTrue);
      expect(r.value(), isTrue);
      expect(h.state.workEntry.workEnd, isNotNull);
      expect(h.writeLog.last, 'A:entry:$moKey:08:00-17:00');
    }, setUp: prep(), profiles: true);

    scenario('S8 Vortag ueber Mitternacht: Stop am Starttag, Reinit', at(23),
        (h) {
      h.boot();
      h.clock.jumpTo(DateTime(2026, 10, 6, 1));
      h.tick();
      expect(h.state.workEntry.date, mo);
      final r = run(h, () => h.vm.stopRunningForSwitch('default'));

      expect(r.value(), isTrue);
      expect(h.work.saved.last.date, mo);
      expect(h.work.saved.last.workEnd, DateTime(2026, 10, 6, 1));
      h.async.flushMicrotasks();
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.state.workEntry.workStart, isNull);
      expect(h.state.workEntry.date, DateTime(2026, 10, 6));
      expect(h.async.periodicTimerCount, 0);
    }, setUp: prep(entryOf(mo, start: at(22))), profiles: true);
  });

  // Stop beim Wechsel und laufende Schreibaktion (#413): der Switch wartet auf
  // die Aktion, statt parallel zu stoppen.
  group('stopRunningForSwitch und Reentranz-Sperre (#413)', () {
    final stopWrites = [
      'A:overtime:135',
      'A:lastUpdate',
      'A:entry:$moKey:08:00-17:00',
    ];

    void releaseAll(Harness h) {
      h.work.holdSaves = false;
      h.overtime.holdSaveOvertime = false;
      for (final c in [
        ...h.work.pendingSaves,
        ...h.overtime.pendingOvertimeSaves
      ]) {
        if (!c.isCompleted) c.complete();
      }
      h.async.flushMicrotasks();
    }

    scenario(
        'B12a wartet auf einen laufenden Stop, stoppt nicht doppelt', at(17),
        (h) {
      h.boot();
      h.overtime.holdSaveOvertime = true;
      final stop = run(h, h.vm.startOrStopTimer);
      final r = run(h, () => h.vm.stopRunningForSwitch('default'));

      expect(r.done(), isFalse);
      expect(h.overtime.pendingOvertimeSaves, hasLength(1));
      expect(h.writeLog, isEmpty);

      releaseAll(h);
      expect(stop.value(), isTrue);
      expect(r.done(), isTrue);
      expect(r.value(), isTrue);
      expect(h.writeLog, stopWrites);
      expect(h.overtime.saveOvertimeCalls, 1);
    }, setUp: prep(), profiles: true);

    scenario('B12b wartet auf eine laufende Pause, stoppt danach', at(17), (h) {
      h.boot();
      h.work.holdSaves = true;
      final pause = run(h, h.vm.startOrStopBreak);
      final r = run(h, () => h.vm.stopRunningForSwitch('default'));
      expect(r.done(), isFalse);
      expect(h.work.pendingSaves, hasLength(1));
      h.work.holdSaves = false;

      h.work.pendingSaves.single.complete();
      h.async.flushMicrotasks();
      expect(pause.value(), isTrue);
      expect(r.done(), isTrue);
      expect(r.value(), isTrue);
      expect(h.state.workEntry.workEnd, isNotNull);
      expect(h.vm.isTimerRunning, isFalse);
    }, setUp: prep(), profiles: true);

    scenario(
        'B12c Profilwechsel waehrend des Wartens: false, kein Haengen', at(17),
        (h) {
      h.boot();
      h.overtime.holdSaveOvertime = true;
      run(h, h.vm.startOrStopTimer);
      final r = run(h, () => h.vm.stopRunningForSwitch('default'));
      expect(r.done(), isFalse);

      h.switchProfile('B');
      expect(r.done(), isTrue);
      expect(r.value(), isFalse);
      expect(count(h, 'B:'), 0);

      releaseAll(h);
      expect(count(h, 'B:'), 0);
    }, setUp: prep(), profiles: true);
  });

  group('isTimerRunning', () {
    scenario('S9 false beim Laden, true laufend, false nach Stop', at(17), (h) {
      h.work.holdReads = true;
      h.boot();
      expect(h.vm.isTimerRunning, isFalse);
      h.work.holdReads = false;
      for (final c in h.work.pendingReads) {
        c.complete();
      }
      h.async.flushMicrotasks();
      expect(h.vm.isTimerRunning, isTrue);
      h.act(h.vm.startOrStopTimer);
      expect(h.vm.isTimerRunning, isFalse);
    }, setUp: prep(), profiles: true);
  });
}
