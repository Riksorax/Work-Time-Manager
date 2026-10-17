import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/timer_action.dart';

import '../../support/dashboard_harness.dart';
import '../../support/fake_repositories.dart';

// Timer-Aktions-Dispatcher (#274 Teil A): `performTimerAction` entscheidet
// zustandsbewusst auf dem geladenen State und nutzt den normalen Start/Stop-Pfad.
// Feste Daten: Mo 2026-10-05, Uhr 17:00 (Stop) bzw. 08:30 (Start), Saldo 120 min.
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  final mo = DateTime(2026, 10, 5);
  final moKey = dayKey(mo);
  DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 5, h, m);

  final running = entryOf(mo, start: at(8));
  final finished = entryOf(mo, start: at(8), end: at(17));

  void Function(Harness) prep([WorkEntryEntity? a]) => (h) {
        if (a != null) h.seed(a);
        h.overtime.stored = const Duration(minutes: 120);
        h.overtimeB.stored = const Duration(minutes: 30);
      };

  ({TimerActionResult? Function() value, bool Function() done}) run(
      Harness h, TimerAction action) {
    TimerActionResult? result;
    var done = false;
    unawaited(h.vm.performTimerAction(action).then((v) {
      result = v;
      done = true;
    }));
    h.async.flushMicrotasks();
    return (value: () => result, done: () => done);
  }

  ({bool? Function() value, bool Function() done}) runToggle(Harness h) {
    bool? result;
    var done = false;
    unawaited(h.vm.startOrStopTimer().then((v) {
      result = v;
      done = true;
    }));
    h.async.flushMicrotasks();
    return (value: () => result, done: () => done);
  }

  int count(Harness h, String prefix) =>
      h.writeLog.where((e) => e.startsWith(prefix)).length;

  void releaseAll(Harness h) {
    h.work.holdSaves = false;
    h.work.holdReads = false;
    h.overtime.holdSaveOvertime = false;
    for (final c in [
      ...h.work.pendingSaves,
      ...h.work.pendingReads,
      ...h.overtime.pendingOvertimeSaves,
    ]) {
      if (!c.isCompleted) c.complete();
    }
    h.async.flushMicrotasks();
  }

  final stopWrites = [
    'A:entry:$moKey:08:00-17:00',
    'A:overtime:135',
    'A:lastUpdate',
  ];

  group('Start', () {
    scenario('A1 leerer Tag: gespeichert, applied; zweiter Start notApplicable',
        at(8, 30), (h) {
      h.boot();
      final r = run(h, TimerAction.start);

      expect(r.value(), TimerActionResult.applied);
      expect(h.vm.isTimerRunning, isTrue);
      expect(h.work.saved.last.workStart, at(8, 30));
      final writes = h.work.saveCalls;
      expect(writes, greaterThan(0));

      final r2 = run(h, TimerAction.start);
      expect(r2.value(), TimerActionResult.notApplicable);
      expect(h.work.saveCalls, writes);
      expect(h.vm.isTimerRunning, isTrue);
    }, setUp: prep(), profiles: true);

    scenario('A2 laufender Timer: notApplicable, nichts geschrieben', at(17),
        (h) {
      h.boot();
      final r = run(h, TimerAction.start);
      expect(r.value(), TimerActionResult.notApplicable);
      expect(h.writeLog, isEmpty);
      expect(h.work.saveCalls, 0);
      expect(h.vm.isTimerRunning, isTrue);
    }, setUp: prep(running), profiles: true);

    scenario('A3 gestoppter Tag: notApplicable, nichts geschrieben', at(17),
        (h) {
      h.boot();
      final r = run(h, TimerAction.start);
      expect(r.value(), TimerActionResult.notApplicable);
      expect(h.work.saveCalls, 0);
    }, setUp: prep(finished), profiles: true);

    scenario('A4 Eintrag-Write scheitert: optimistischer Start bleibt applied',
        at(8, 30), (h) {
      h.boot();
      h.work.failSaves = true;
      final r = run(h, TimerAction.start);
      // #402: Start ohne Saldo-Block ist optimistisch (Autosave heilt).
      expect(r.value(), TimerActionResult.applied);
      expect(h.vm.isTimerRunning, isTrue);
    }, setUp: prep(), profiles: true);
  });

  group('Stop', () {
    scenario('A5 laufend: Eintrag -> Saldo, wie beim UI-Stop, applied', at(17),
        (h) {
      h.boot();
      final r = run(h, TimerAction.stop);

      expect(r.value(), TimerActionResult.applied);
      expect(h.writeLog, stopWrites);
      expect(h.state.workEntry.workEnd, isNotNull);
      expect(h.vm.isTimerRunning, isFalse);
      expect(h.async.periodicTimerCount, 0);
      // 9 h brutto -> Pflichtpause 45 min (Auto-Pausen wie beim UI-Stop).
      expect(
          h.work.store[moKey]!.breaks.fold<Duration>(
              Duration.zero, (p, b) => p + b.end!.difference(b.start)),
          const Duration(minutes: 45));
    }, setUp: prep(running), profiles: true);

    scenario('A6 leerer Tag: notApplicable, null Writes', at(17), (h) {
      h.boot();
      final r = run(h, TimerAction.stop);
      expect(r.value(), TimerActionResult.notApplicable);
      expect(h.writeLog, isEmpty);
      expect(h.work.saveCalls, 0);
      expect(h.overtime.saveOvertimeCalls, 0);
    }, setUp: prep(), profiles: true);

    scenario('A7 gestoppter Tag: notApplicable, null Writes', at(17), (h) {
      h.boot();
      final r = run(h, TimerAction.stop);
      expect(r.value(), TimerActionResult.notApplicable);
      expect(h.work.saveCalls, 0);
      expect(h.overtime.saveOvertimeCalls, 0);
    }, setUp: prep(finished), profiles: true);

    scenario('A8 Eintrag-Write scheitert: failed, State und Timer unveraendert',
        at(17), (h) {
      h.boot();
      h.work.failSaves = true;
      final r = run(h, TimerAction.stop);

      expect(r.value(), TimerActionResult.failed);
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.async.periodicTimerCount, 1);
      expect(h.writeLog, isEmpty);
      expect(h.overtime.saveOvertimeCalls, 0);
    }, setUp: prep(running), profiles: true);

    scenario('A9 Saldo-Write scheitert: failed, Eintrag kompensiert', at(17),
        (h) {
      h.boot();
      h.overtime.failSaveOvertime = true;
      final r = run(h, TimerAction.stop);

      expect(r.value(), TimerActionResult.failed);
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.async.periodicTimerCount, 1);
      expect(h.work.store[moKey], running);
    }, setUp: prep(running), profiles: true);
  });

  group('Warten', () {
    scenario('A10 Ladelauf: entscheidet erst auf geladenem State', at(17), (h) {
      h.work.holdReads = true;
      h.boot();
      expect(h.state.isLoading, isTrue);
      // Auf dem Platzhalter (leer) waere "Start" anwendbar: darf nicht passieren.
      final start = run(h, TimerAction.start);
      expect(start.done(), isFalse);
      expect(h.writeLog, isEmpty);

      releaseAll(h);
      expect(start.value(), TimerActionResult.notApplicable);
      expect(h.work.saveCalls, 0);
      expect(h.vm.isTimerRunning, isTrue);
    }, setUp: prep(running), profiles: true);

    scenario('A11 Ladelauf: Stop wartet ab und stoppt danach', at(17), (h) {
      h.work.holdReads = true;
      h.boot();
      final stop = run(h, TimerAction.stop);
      expect(stop.done(), isFalse);

      releaseAll(h);
      expect(stop.value(), TimerActionResult.applied);
      expect(h.writeLog, stopWrites);
    }, setUp: prep(running), profiles: true);

    scenario(
        'A12 laufende Aktion: wartet, weder verworfen noch doppelt', at(17),
        (h) {
      h.boot();
      h.overtime.holdSaveOvertime = true;
      final tap = runToggle(h);
      final r = run(h, TimerAction.stop);

      expect(r.done(), isFalse);
      expect(h.overtime.pendingOvertimeSaves, hasLength(1));

      releaseAll(h);
      expect(tap.value(), isTrue);
      expect(r.value(), TimerActionResult.notApplicable);
      expect(h.writeLog, stopWrites);
      expect(h.overtime.saveOvertimeCalls, 1);
    }, setUp: prep(running), profiles: true);

    scenario('A13 laufender Start-Tap: zweiter Start notApplicable', at(8, 30),
        (h) {
      h.boot();
      h.work.holdSaves = true;
      final tap = runToggle(h);
      final r = run(h, TimerAction.start);
      expect(r.done(), isFalse);

      releaseAll(h);
      expect(tap.value(), isTrue);
      expect(r.value(), TimerActionResult.notApplicable);
      expect(h.work.saved, hasLength(1));
      expect(h.vm.isTimerRunning, isTrue);
    }, setUp: prep(), profiles: true);

    scenario(
        'A14 Profilwechsel beim Warten: kein Write ins falsche Profil', at(17),
        (h) {
      h.boot();
      h.overtime.holdSaveOvertime = true;
      runToggle(h);
      final r = run(h, TimerAction.stop);
      expect(r.done(), isFalse);

      h.switchProfile('B');
      expect(r.done(), isTrue);
      expect(r.value(), TimerActionResult.notApplicable);
      expect(count(h, 'B:'), 0);

      releaseAll(h);
      expect(count(h, 'B:'), 0);
    }, setUp: prep(running), profiles: true);
  });

  group('Tageswechsel und Profile', () {
    scenario('A15 Lauf ueber Mitternacht (#379): Stop am Starttag, Start nein',
        at(23), (h) {
      h.boot();
      h.clock.jumpTo(DateTime(2026, 10, 6, 1));
      h.tick();
      expect(h.state.workEntry.date, mo);

      final start = run(h, TimerAction.start);
      expect(start.value(), TimerActionResult.notApplicable);
      expect(h.work.saveCalls, 0);

      final stop = run(h, TimerAction.stop);
      expect(stop.value(), TimerActionResult.applied);
      expect(h.work.saved.last.date, mo);
      expect(h.work.saved.last.workEnd, DateTime(2026, 10, 6, 1));
    }, setUp: prep(entryOf(mo, start: at(22))), profiles: true);

    scenario('A16 zusaetzliches Profil B: Start schreibt nur nach B', at(8, 30),
        (h) {
      h.switchProfile('B');
      h.boot();
      final r = run(h, TimerAction.start);

      expect(r.value(), TimerActionResult.applied);
      expect(count(h, 'A:'), 0);
      expect(h.workB.saved.last.workStart, at(8, 30));
    }, setUp: prep(), profiles: true);

    scenario('A17 Standard-Profil ohne Profil-Harness: Stop applied', at(17),
        (h) {
      h.boot();
      final r = run(h, TimerAction.stop);
      expect(r.value(), TimerActionResult.applied);
      expect(h.work.saved.last.workEnd, at(17));
    }, setUp: prep(running));
  });
}
