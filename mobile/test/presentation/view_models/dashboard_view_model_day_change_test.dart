import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart' show AppLifecycleState, TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/today_provider.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';

import '../../support/dashboard_harness.dart';
import '../../support/fake_repositories.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('4.0 toter Code', () {
    scenario(
        '_init laedt keine Monatseintraege mehr', DateTime(2026, 10, 2, 10),
        (h) {
      h.boot();
      expect(h.state.isLoading, isFalse);
      expect(h.work.getMonthCalls, 0);
    });
  });

  group('4.1 Soll und isExtraDay am Eintragsdatum', () {
    final fr = DateTime(2026, 10, 2);
    final so = DateTime(2026, 10, 4);
    final mo = DateTime(2026, 10, 5);

    scenario('Fr->Sa: Soll springt nicht', DateTime(2026, 10, 2, 23), (h) {
      h.boot();
      final before = h.state;
      expect(before.workEntry.date, fr);
      expect(before.isExtraDay, isFalse);
      h.clock.jumpTo(DateTime(2026, 10, 3, 1));
      h.tick();
      final after = h.state;
      expect(after.workEntry.date, fr);
      expect(after.dailyOvertime, after.elapsedTime - eightHours);
      expect(after.elapsedTime, const Duration(hours: 3, seconds: 1));
      expect(after.isExtraDay, isFalse);
      expect(after.expectedEndTime, before.expectedEndTime);
      expect(after.expectedEndTotalZero, before.expectedEndTotalZero);
    }, setUp: (h) {
      h.seed(entryOf(fr, start: DateTime(2026, 10, 2, 22)));
    });

    scenario(
        'So->Mo: Soll bleibt 0, isExtraDay bleibt', DateTime(2026, 10, 4, 23),
        (h) {
      h.boot();
      expect(h.state.isExtraDay, isTrue);
      expect(h.state.dailyOvertime, h.state.elapsedTime);
      h.clock.jumpTo(DateTime(2026, 10, 5, 1));
      h.tick();
      expect(h.state.workEntry.date, so);
      expect(h.state.dailyOvertime, h.state.elapsedTime);
      expect(h.state.isExtraDay, isTrue);
    }, setUp: (h) {
      h.seed(entryOf(so, start: DateTime(2026, 10, 4, 22)));
    });

    scenario('Gegenprobe: Montag laedt Soll 8 h', DateTime(2026, 10, 5, 10),
        (h) {
      h.boot();
      expect(h.state.workEntry.date, mo);
      expect(h.state.isExtraDay, isFalse);
      expect(h.state.dailyOvertime, const Duration(hours: 1) - eightHours);
    }, setUp: (h) {
      h.seed(entryOf(mo, start: DateTime(2026, 10, 5, 9)));
    });

    scenario('Stop Fr 22:00 -> Sa 01:00 rechnet mit Fr-Soll',
        DateTime(2026, 10, 2, 23), (h) {
      h.boot();
      h.clock.jumpTo(DateTime(2026, 10, 3, 1));
      h.act(h.vm.startOrStopTimer);
      final saved = h.work.saved.last;
      expect(saved.date, fr);
      expect(saved.workEnd, DateTime(2026, 10, 3, 1));
      expect(h.work.store.keys, [dayKey(fr)]);
      expect(h.overtime.savedOvertimes.single,
          const Duration(hours: 1) + const Duration(hours: 3) - eightHours);
    }, setUp: (h) {
      h.overtime.stored = const Duration(hours: 1);
      h.seed(entryOf(fr, start: DateTime(2026, 10, 2, 22)));
    });

    scenario('setManualEndTime auf laufendem Fr-Eintrag nach Mitternacht',
        DateTime(2026, 10, 2, 23), (h) {
      h.boot();
      h.clock.jumpTo(DateTime(2026, 10, 3, 1));
      h.act(() => h.vm.setManualEndTime(const TimeOfDay(hour: 23, minute: 30)));
      final saved = h.work.saved.last;
      expect(saved.date, fr);
      expect(saved.workEnd, DateTime(2026, 10, 2, 23, 30));
      expect(h.overtime.savedOvertimes.single,
          const Duration(hours: 1, minutes: 30) - eightHours);
    }, setUp: (h) {
      h.seed(entryOf(fr, start: DateTime(2026, 10, 2, 22)));
    });

    scenario('setManualStartTime bei leerem Eintrag nutzt das Eintragsdatum',
        DateTime(2026, 10, 2, 10), (h) {
      h.boot();
      h.act(
          () => h.vm.setManualStartTime(const TimeOfDay(hour: 9, minute: 15)));
      expect(h.work.saved.last.date, fr);
      expect(h.work.saved.last.workStart, DateTime(2026, 10, 2, 9, 15));
    });

    // DST-Invarianten: Soll am Starttag (Samstag), nie am Folgetag (Sonntag).
    test('laufender Timer ueber DST-/Zeitumstellungsnaechte (Invarianten)', () {
      final saturdays = [
        DateTime(2026, 3, 28),
        DateTime(2026, 10, 24),
        DateTime(2026, 3, 7),
        DateTime(2026, 10, 31),
        DateTime(2026, 4, 4),
        DateTime(2026, 9, 26),
      ];
      for (final d in saturdays) {
        fakeAsync((async) {
          final start = DateTime(d.year, d.month, d.day, 22);
          final h = Harness(async, DateTime(d.year, d.month, d.day, 23));
          h.settings
            ..workdays = [d.weekday]
            ..weeklyHours = 8;
          h.seed(entryOf(d, start: start));
          h.boot();
          h.clock.jumpTo(DateTime(d.year, d.month, d.day + 1, 3));
          h.tick();
          final expectedElapsed = h.clock().difference(start);
          expect(h.state.elapsedTime, expectedElapsed, reason: '$d');
          expect(h.state.dailyOvertime, expectedElapsed - eightHours,
              reason: '$d');
          expect(h.state.workEntry.date, d);
          h.dispose();
        });
      }
    });
  });

  group('4.2 Generationszaehler, Fehlerbehandlung, Cleanup', () {
    final fr = DateTime(2026, 10, 2);

    scenario('ueberholter _init bei Rebuild: neuer Lauf gewinnt',
        DateTime(2026, 10, 2, 10), (h) {
      h.work.holdReads = true;
      h.boot();
      expect(h.work.pendingReads, hasLength(1));
      h.container.invalidate(getTodayWorkEntryUseCaseProvider);
      h.async.elapse(Duration.zero);
      h.async.flushMicrotasks();
      expect(h.work.pendingReads, hasLength(2));

      final entryB = entryOf(fr,
          start: DateTime(2026, 10, 2, 9), end: DateTime(2026, 10, 2, 10));
      final entryA = entryOf(fr, start: DateTime(2026, 10, 2, 8));
      // Lauf 2 (B) wird zuerst fertig, Lauf 1 (A, laufend) danach.
      h.work.store[dayKey(fr)] = entryB;
      h.work.pendingReads[1].complete();
      h.async.flushMicrotasks();
      expect(h.state.workEntry, entryB);
      expect(h.state.isLoading, isFalse);

      h.work.store[dayKey(fr)] = entryA;
      h.work.pendingReads[0].complete();
      h.async.flushMicrotasks();
      expect(h.state.workEntry, entryB);
      expect(h.state.dailyOvertime, const Duration(hours: 1) - eightHours);
      expect(h.async.periodicTimerCount, 0, reason: 'alter Lauf startet Timer');
    });

    scenario('Offline-Fehler beim Laden beendet isLoading',
        DateTime(2026, 10, 2, 10), (h) {
      h.work.failReads = true;
      h.boot();
      expect(h.state.isLoading, isFalse);
      expect(h.async.periodicTimerCount, 0);
    });

    scenario('Dispose mitten im Lauf wirft nicht', DateTime(2026, 10, 2, 10),
        (h) {
      final hold = Completer<void>();
      h.overtime.holdOvertimeLoad = hold;
      h.boot();
      h.dispose();
      hold.complete();
      h.async.flushMicrotasks();
      expect(h.async.periodicTimerCount, 0);
      expect(h.async.nonPeriodicTimerCount, 0);
    }, setUp: (h) {
      h.seed(entryOf(fr, start: DateTime(2026, 10, 2, 8)));
    });

    scenario('Dispose bei laufendem Timer raeumt Timer auf',
        DateTime(2026, 10, 2, 10), (h) {
      h.boot();
      expect(h.async.periodicTimerCount, 1);
      h.dispose();
      expect(h.async.periodicTimerCount, 0);
      expect(h.async.nonPeriodicTimerCount, 0);
    }, setUp: (h) {
      h.seed(entryOf(fr, start: DateTime(2026, 10, 2, 8)));
    });
  });

  group('4.3 Tageswechsel: stiller Wechsel, laufender Timer, Basis', () {
    final fr = DateTime(2026, 10, 2);
    final sa = DateTime(2026, 10, 3);
    final mo = DateTime(2026, 10, 5);
    const toMidnight = Duration(seconds: 31);

    void resume() => TestWidgetsFlutterBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    scenario('Fr->Sa: stiller Wechsel bei leerem Eintrag',
        DateTime(2026, 10, 2, 23, 59, 30), (h) {
      h.boot();
      expect(h.state.workEntry.date, fr);
      expect(h.state.isExtraDay, isFalse);
      h.tick(toMidnight);
      expect(h.state.workEntry.date, sa);
      expect(h.state.workEntry.id, dayKey(sa));
      expect(h.state.isExtraDay, isTrue);
      expect(h.state.isLoading, isFalse);
      expect(h.work.saved, isEmpty);
      expect(h.overtime.savedOvertimes, isEmpty);
    });

    scenario('So->Mo: stiller Wechsel, Soll wieder 8 h',
        DateTime(2026, 10, 4, 23, 59, 30), (h) {
      h.boot();
      expect(h.state.isExtraDay, isTrue);
      h.tick(toMidnight);
      expect(h.state.workEntry.date, mo);
      expect(h.state.isExtraDay, isFalse);
      // Mo-Eintrag laeuft (Start 00:00): Soll 8 h wird abgezogen.
      expect(h.work.saved, isEmpty);
    });

    scenario('gestoppter, abgeschlossener Vortag -> leerer neuer Tag',
        DateTime(2026, 10, 2, 23, 59, 30), (h) {
      h.boot();
      expect(h.state.actualWorkDuration, const Duration(hours: 8, minutes: 30));
      expect(h.state.dailyOvertime, const Duration(minutes: 30));
      expect(h.state.totalOvertime, const Duration(hours: 2));
      h.tick(toMidnight);
      final s = h.state;
      expect(s.workEntry.date, sa);
      expect(s.workEntry.workStart, isNull);
      expect(s.actualWorkDuration, isNull);
      expect(s.grossWorkDuration, isNull);
      expect(s.expectedEndTime, isNull);
      expect(s.expectedEndTotalZero, isNull);
      expect(s.elapsedTime, Duration.zero);
      expect(s.dailyOvertime, Duration.zero);
      expect(s.initialOvertime, const Duration(hours: 2));
      expect(s.totalOvertime, const Duration(hours: 2));
      expect(h.work.saved, isEmpty);
      expect(h.overtime.savedOvertimes, isEmpty);
    }, setUp: (h) {
      h.overtime.stored = const Duration(hours: 2);
      h.overtime.lastUpdate = DateTime(2026, 10, 2, 17);
      h.seed(entryOf(fr,
          start: DateTime(2026, 10, 2, 8),
          end: DateTime(2026, 10, 2, 17),
          breaks: [
            BreakEntity(
                id: 'b1',
                name: 'Pause 1',
                start: DateTime(2026, 10, 2, 12),
                end: DateTime(2026, 10, 2, 12, 30)),
          ]));
    });

    scenario('laufender Timer bleibt ueber Mitternacht unveraendert',
        DateTime(2026, 10, 2, 23, 59, 30), (h) {
      h.boot();
      expect(h.work.getWorkEntryCalls, 1);
      h.tick(toMidnight);
      expect(h.work.getWorkEntryCalls, 1);
      expect(h.state.workEntry.date, fr);
      expect(h.state.workEntry.workStart, DateTime(2026, 10, 2, 22));
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.async.periodicTimerCount, 1);
      expect(
          h.state.elapsedTime, h.clock().difference(DateTime(2026, 10, 2, 22)));
      // Autosave nach 30 Ticks schreibt den Fr-Eintrag in den Fr-Schluessel.
      h.tick(const Duration(seconds: 30));
      expect(h.work.saved, isNotEmpty);
      expect(h.work.saved.every((e) => e.date == fr && e.id == dayKey(fr)),
          isTrue);
      expect(h.work.store.keys, [dayKey(fr)]);
    }, setUp: (h) {
      h.seed(entryOf(fr, start: DateTime(2026, 10, 2, 22)));
    });

    scenario(
        'Resume ueber Mitternacht ohne Timer-Ablauf', DateTime(2026, 10, 2, 10),
        (h) {
      h.boot();
      h.clock.jumpTo(DateTime(2026, 10, 3, 9));
      resume();
      h.async.flushMicrotasks();
      expect(h.state.workEntry.date, sa);
    });

    scenario('Standby-Haertung im Tick: todayProvider zieht nach',
        DateTime(2026, 10, 2, 23), (h) {
      h.boot();
      for (var i = 0; i < 5; i++) {
        h.tick();
      }
      expect(h.work.getWorkEntryCalls, 1, reason: 'Tick ohne Wechsel');
      expect(h.container.read(todayProvider), fr);
      h.clock.jumpTo(DateTime(2026, 10, 3, 1));
      h.tick();
      expect(h.container.read(todayProvider), sa);
      expect(h.state.workEntry.date, fr);
      expect(h.work.getWorkEntryCalls, 1);
    }, setUp: (h) {
      h.seed(entryOf(fr, start: DateTime(2026, 10, 2, 22)));
    });

    test('nach dispose feuert nichts mehr (kein Leak, keine Repo-Zugriffe)',
        () {
      fakeAsync((async) {
        final h = Harness(async, DateTime(2026, 10, 2, 23, 59, 30));
        h.boot();
        final calls = h.work.getWorkEntryCalls;
        h.dispose();
        expect(async.pendingTimers, isEmpty);
        async.elapse(const Duration(days: 2));
        resume();
        async.flushMicrotasks();
        expect(h.work.getWorkEntryCalls, calls);
      });
    });

    scenario('Basis-Ueberstunden: stored ist Basis (lastUpdate = neuer Tag)',
        DateTime(2026, 10, 2, 10), (h) {
      h.boot();
      h.clock.jumpTo(DateTime(2026, 10, 3, 9));
      resume();
      h.async.flushMicrotasks();
      expect(h.state.workEntry.date, sa);
      expect(h.state.workEntry.workStart, isNotNull);
      // Sa-Eintrag laeuft seit 08:00 (Daily +1 h, Soll 0). Der normale _init
      // wuerde 1 h abziehen (Basis 60 min); beim Tageswechsel ist stored Basis.
      expect(h.state.initialOvertime, const Duration(minutes: 120));
      expect(h.state.totalOvertime,
          const Duration(minutes: 120) + h.state.dailyOvertime!);
    }, setUp: (h) {
      h.overtime.stored = const Duration(minutes: 120);
      h.overtime.lastUpdate = DateTime(2026, 10, 3, 8, 30);
      h.seed(entryOf(sa, start: DateTime(2026, 10, 3, 8)));
    });

    scenario('Basis-Ausnahme dailyAlreadyStored: Heuristik greift',
        DateTime(2026, 10, 2, 23), (h) {
      h.boot();
      h.clock.jumpTo(DateTime(2026, 10, 3, 18));
      resume();
      h.async.flushMicrotasks();
      expect(h.state.workEntry.date, sa);
      // Sa: Soll 0, 9 h gearbeitet -> Daily +9 h, im Stored bereits enthalten.
      expect(h.state.dailyOvertime, const Duration(hours: 9));
      expect(h.state.initialOvertime, const Duration(hours: 1));
      expect(h.state.totalOvertime, const Duration(hours: 10));
    }, setUp: (h) {
      h.overtime.stored = const Duration(hours: 10);
      h.overtime.lastUpdate = DateTime(2026, 10, 3, 17);
      h.seed(entryOf(sa,
          start: DateTime(2026, 10, 3, 8), end: DateTime(2026, 10, 3, 17)));
    });

    scenario('Gegenprobe: normaler _init behaelt die Heuristik',
        DateTime(2026, 10, 3, 12), (h) {
      h.boot();
      // Daily = 4 h (Sa, Soll 0), stored enthaelt den Tag -> Basis = 2 h - 4 h.
      expect(h.state.initialOvertime, const Duration(hours: -2));
    }, setUp: (h) {
      h.overtime.stored = const Duration(hours: 2);
      h.overtime.lastUpdate = DateTime(2026, 10, 3, 10);
      h.seed(entryOf(sa, start: DateTime(2026, 10, 3, 8)));
    });

    scenario('Login um 23:59 + Mitternacht: genau ein gueltiger Endzustand',
        DateTime(2026, 10, 2, 23, 59, 30), (h) {
      h.work.holdReads = true;
      h.boot(); // pending[0] (Fr)
      h.container.invalidate(getTodayWorkEntryUseCaseProvider);
      h.async.elapse(Duration.zero); // pending[1] (Rebuild, Fr)
      h.tick(toMidnight); // pending[2] (Tageswechsel, Sa)
      expect(h.work.pendingReads, hasLength(3));
      h.work.pendingReads[2].complete();
      h.async.flushMicrotasks();
      expect(h.state.workEntry.date, sa);
      h.work.pendingReads[0].complete();
      h.work.pendingReads[1].complete();
      h.async.flushMicrotasks();
      expect(h.state.workEntry.date, sa);
      expect(h.state.isLoading, isFalse);
    });

    test('DST-/Zeitumstellungstage: stiller Wechsel auf den lokalen Folgetag',
        () {
      final days = [
        DateTime(2026, 3, 28),
        DateTime(2026, 3, 29),
        DateTime(2026, 10, 24),
        DateTime(2026, 10, 25),
        DateTime(2026, 3, 7),
        DateTime(2026, 3, 8),
        DateTime(2026, 10, 31),
        DateTime(2026, 11, 1),
        DateTime(2026, 4, 4),
        DateTime(2026, 4, 5),
        DateTime(2026, 9, 26),
        DateTime(2026, 9, 27),
      ];
      for (final d in days) {
        fakeAsync((async) {
          final start = DateTime(d.year, d.month, d.day, 23, 59, 30);
          final h = Harness(async, start);
          h.boot();
          final delay = DateTime(d.year, d.month, d.day + 1).difference(start);
          async.elapse(delay - const Duration(milliseconds: 1));
          async.flushMicrotasks();
          expect(h.state.workEntry.date, DateTime(d.year, d.month, d.day),
              reason: '$d vor Mitternacht');
          async.elapse(const Duration(milliseconds: 1));
          async.flushMicrotasks();
          final next = DateTime(d.year, d.month, d.day + 1);
          expect(h.state.workEntry.date, next, reason: '$d');
          expect(h.state.workEntry.id, dayKey(next), reason: '$d');
          h.dispose();
        });
      }
    });

    scenario(
        'Offline-Reinit: Zustand bleibt Vortag, Retry beim naechsten Trigger',
        DateTime(2026, 10, 2, 23, 59, 30), (h) {
      h.boot();
      h.work.failReads = true;
      h.tick(toMidnight);
      expect(h.state.workEntry.date, fr);
      expect(h.state.isLoading, isFalse);
      expect(h.work.saved, isEmpty);
      // Retry beim naechsten Trigger: der Aktions-Guard laedt den Tag neu.
      h.work.failReads = false;
      h.act(h.vm.startOrStopTimer);
      expect(h.state.workEntry.date, sa);
      expect(h.work.saved.every((e) => e.date == sa), isTrue);
      expect(h.work.saved, isNotEmpty);
    });
  });

  group('4.4 Aktionen-Guard', () {
    final fr = DateTime(2026, 10, 2);
    final sa = DateTime(2026, 10, 3);
    final frDone = entryOf(fr,
        start: DateTime(2026, 10, 2, 8),
        end: DateTime(2026, 10, 2, 17),
        breaks: [
          BreakEntity(
              id: 'b1',
              name: 'Pause 1',
              start: DateTime(2026, 10, 2, 12),
              end: DateTime(2026, 10, 2, 12, 30)),
        ]);

    scenario('Start nach Mitternacht schreibt nie in den Vortag',
        DateTime(2026, 10, 2, 10), (h) {
      h.boot();
      expect(h.state.workEntry.date, fr);
      h.clock.jumpTo(DateTime(2026, 10, 3, 9));
      h.act(h.vm.startOrStopTimer);
      expect(h.work.saved, isNotEmpty);
      expect(h.work.saved.every((e) => e.date == sa), isTrue);
      expect(h.work.store.containsKey(dayKey(fr)), isFalse);
      expect(h.work.store[dayKey(sa)]!.workStart, DateTime(2026, 10, 3, 9));
    });

    for (final keepBreaks in [false, true]) {
      scenario(
          'Neue Session (keepBreaks=$keepBreaks) ueberschreibt keinen Vortag',
          DateTime(2026, 10, 2, 18), (h) {
        h.boot();
        h.clock.jumpTo(DateTime(2026, 10, 3, 9));
        h.act(
            keepBreaks ? h.vm.startNewSessionKeepBreaks : h.vm.startNewSession);
        expect(h.work.store[dayKey(fr)], frDone);
        final s = h.work.store[dayKey(sa)]!;
        expect(s.workStart, DateTime(2026, 10, 3, 9));
        expect(s.workEnd, isNull);
        expect(s.breaks, isEmpty);
      }, setUp: (h) => h.seed(frDone));
    }

    final actions = <String, Future<void> Function(DashboardViewModel)>{
      'startOrStopBreak': (v) => v.startOrStopBreak(),
      'setManualStartTime': (v) =>
          v.setManualStartTime(const TimeOfDay(hour: 9, minute: 0)),
      'setManualEndTime': (v) =>
          v.setManualEndTime(const TimeOfDay(hour: 10, minute: 0)),
      'clearEndTime': (v) => v.clearEndTime(),
      'updateBreak': (v) => v.updateBreak(frDone.breaks.single),
      'deleteBreak': (v) => v.deleteBreak('b1'),
      'startOrStopTimer': (v) => v.startOrStopTimer(),
      'startNewSession': (v) => v.startNewSession(),
      'startNewSessionKeepBreaks': (v) => v.startNewSessionKeepBreaks(),
    };
    actions.forEach((name, action) {
      scenario('$name auf gestopptem Vortag schreibt nur unter heute',
          DateTime(2026, 10, 2, 18), (h) {
        h.boot();
        h.clock.jumpTo(DateTime(2026, 10, 3, 9));
        h.act(() => action(h.vm));
        expect(h.work.saved.every((e) => e.date == sa), isTrue);
        expect(h.work.store[dayKey(fr)], frDone);
      }, setUp: (h) => h.seed(frDone));
    });

    scenario('laufender Vortags-Eintrag: Pause bleibt am Starttag',
        DateTime(2026, 10, 2, 23), (h) {
      h.boot();
      h.clock.jumpTo(DateTime(2026, 10, 3, 1));
      h.act(h.vm.startOrStopBreak);
      expect(h.work.saved.last.date, fr);
      expect(h.work.saved.last.breaks.single.start, DateTime(2026, 10, 3, 1));
      h.clock.jumpTo(DateTime(2026, 10, 3, 1, 10));
      h.act(h.vm.startOrStopBreak);
      expect(h.work.saved.last.breaks.single.end, DateTime(2026, 10, 3, 1, 10));
      expect(h.work.store.keys, [dayKey(fr)]);
    }, setUp: (h) => h.seed(entryOf(fr, start: DateTime(2026, 10, 2, 22))));

    scenario(
        'laufender Vortags-Eintrag: updateBreak nach Mitternacht behaelt Datum '
        'der Pause und Eintrag am Starttag (#397)',
        DateTime(2026, 10, 2, 23), (h) {
      h.boot();
      h.clock.jumpTo(DateTime(2026, 10, 3, 0, 20));
      // So baut EditBreakModal die Pause: Datum der Pause, nicht "jetzt".
      h.act(() => h.vm.updateBreak(BreakEntity(
            id: 'b1',
            name: 'Pause',
            start: DateTime(2026, 10, 2, 23, 40),
            end: DateTime(2026, 10, 2, 23, 50),
          )));
      final saved = h.work.saved.last;
      expect(saved.date, fr);
      expect(saved.breaks.single.start, DateTime(2026, 10, 2, 23, 40));
      expect(saved.breaks.single.end, DateTime(2026, 10, 2, 23, 50));
      expect(h.work.store.keys, [dayKey(fr)]);
    },
        setUp: (h) =>
            h.seed(entryOf(fr, start: DateTime(2026, 10, 2, 22), breaks: [
              BreakEntity(
                id: 'b1',
                name: 'Pause',
                start: DateTime(2026, 10, 2, 23, 30),
                end: DateTime(2026, 10, 2, 23, 45),
              )
            ])));

    scenario('Stop eines ueber 24 h laufenden Vortags rechnet ohne Fehler',
        DateTime(2026, 10, 2, 9), (h) {
      h.boot();
      h.clock.jumpTo(DateTime(2026, 10, 3, 10));
      h.act(h.vm.startOrStopTimer);
      final saved = h.work.saved.last;
      expect(saved.date, fr);
      expect(saved.workEnd, DateTime(2026, 10, 3, 10));
      expect(h.overtime.savedOvertimes, hasLength(1));
    }, setUp: (h) => h.seed(entryOf(fr, start: DateTime(2026, 10, 2, 8))));

    scenario('Reinit nach Stop eines Vortags-Laufs', DateTime(2026, 10, 2, 23),
        (h) {
      h.boot();
      h.clock.jumpTo(DateTime(2026, 10, 3, 1));
      h.act(h.vm.startOrStopTimer);
      final saveIdx = h.work.log.indexOf('save:${dayKey(fr)}');
      final readIdx = h.work.log.lastIndexOf('read:${dayKey(sa)}');
      expect(saveIdx, isNonNegative);
      expect(readIdx, greaterThan(saveIdx));
      expect(h.work.saved.every((e) => e.date == fr), isTrue);
      expect(h.work.saved.single.workEnd, DateTime(2026, 10, 3, 1));
      final s = h.state;
      expect(s.workEntry.date, sa);
      expect(s.workEntry.workStart, isNull);
      expect(s.initialOvertime, h.overtime.stored);
      expect(s.totalOvertime, h.overtime.stored);
      expect(h.async.periodicTimerCount, 0);
    }, setUp: (h) => h.seed(entryOf(fr, start: DateTime(2026, 10, 2, 22))));

    scenario('Doppeltipp waehrend offenem Reinit: genau ein Lesezugriff',
        DateTime(2026, 10, 2, 10), (h) {
      h.boot();
      final before = h.work.getWorkEntryCalls;
      h.clock.jumpTo(DateTime(2026, 10, 3, 9));
      h.work.holdReads = true;
      unawaited(h.vm.startOrStopTimer());
      unawaited(h.vm.startOrStopTimer());
      h.async.flushMicrotasks();
      expect(h.work.getWorkEntryCalls, before + 1);
      h.work.holdReads = false;
      h.work.pendingReads.single.complete();
      h.async.flushMicrotasks();
      expect(h.work.getWorkEntryCalls, before + 1);
      expect(h.work.saved.every((e) => e.date == sa), isTrue);
    });

    scenario('Offline-Guard: Aktion bricht ab, naechste funktioniert',
        DateTime(2026, 10, 2, 10), (h) {
      h.boot();
      h.clock.jumpTo(DateTime(2026, 10, 3, 9));
      h.work.failReads = true;
      bool? ok;
      h.act(() async => ok = await h.vm.startOrStopTimer());
      // #416: Abbruch meldet false, damit die UI die Snackbar zeigt.
      expect(ok, isFalse);
      expect(h.work.saved, isEmpty);
      expect(h.state.workEntry.date, fr);
      h.work.failReads = false;
      h.act(h.vm.startOrStopTimer);
      expect(h.work.saved.every((e) => e.date == sa), isTrue);
      expect(h.work.saved, isNotEmpty);
    });

    scenario('Fehler beim ersten Laden: Platzhalter wird nie geschrieben',
        DateTime(2026, 10, 2, 10), (h) {
      h.work.failReads = true;
      h.boot();
      expect(h.state.isLoading, isFalse);
      h.act(h.vm.startOrStopTimer);
      expect(h.work.saved, isEmpty);
      h.work.failReads = false;
      h.act(h.vm.startOrStopTimer);
      expect(h.work.saved, isNotEmpty);
      expect(h.work.saved.first.id, dayKey(fr));
    });

    scenario(
        'Retry nach fehlgeschlagenem Erstladen nutzt die normale Basis-Heuristik',
        DateTime(2026, 10, 2, 10), (h) {
      // Laufender Eintrag von heute, Saldo heute schon gespeichert: die Basis
      // ist stored - Tagesanteil (kein Tageswechsel, nur ein Offline-Retry).
      h.seed(entryOf(fr, start: DateTime(2026, 10, 2, 8)));
      h.overtime.stored = const Duration(hours: 1);
      h.overtime.lastUpdate = DateTime(2026, 10, 2, 9);
      h.work.failReads = true;
      h.boot();
      h.work.failReads = false;
      h.act(h.vm.startOrStopTimer);
      // Stop um 10:00: 2 h gearbeitet, Soll 8 h -> Tagesanteil -6 h, Basis 7 h.
      expect(h.overtime.stored, const Duration(hours: 1));
    });
  });
}
