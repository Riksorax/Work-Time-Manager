import 'dart:async';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/core/services/notification_service.dart';
import 'package:flutter_work_time/domain/usecases/toggle_break.dart';
import 'package:flutter_work_time/domain/utils/overtime_warning_utils.dart';

import 'package:mockito/mockito.dart';
import 'package:flutter_work_time/domain/entities/work_profile_entity.dart';
import 'package:flutter_work_time/presentation/view_models/work_profile_view_model.dart';

import '../../support/dashboard_harness.dart';
import '../../support/fake_repositories.dart';
import 'work_profile_view_model_test.mocks.dart';

// Profilwechsel im Dashboard (#388). Feste Daten: Mo 2026-10-05. Profil A =
// Standard (Soll Mo-Fr 8 h, Saldo 120 min), Profil B: Di-Do, 24 h/Woche, also
// ist Montag dort ein Zusatztag (Soll 0), Saldo 30 min. Wechsel immer ueber
// `Harness.switchProfile`.
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  final mo = DateTime(2026, 10, 5);
  final moKey = dayKey(mo);
  DateTime at(int h, [int m = 0, int s = 0]) => DateTime(2026, 10, 5, h, m, s);

  final entryA = entryOf(mo, start: at(8));
  final entryB = entryOf(mo, start: at(9), end: at(12));
  final finishedA = entryOf(mo, start: at(8), end: at(17));
  const saldoA = Duration(minutes: 120);
  const saldoB = Duration(minutes: 30);

  /// Profil A: Eintrag [a] (Default: laufend ab 08:00), Saldo 120 min.
  /// Profil B: Eintrag [b] (Default: fertig 09:00-12:00), Saldo 30 min,
  /// `lastUpdate` 12:00 (Saldo enthaelt den Tag).
  void Function(Harness) prep({WorkEntryEntity? a, WorkEntryEntity? b}) => (h) {
        h.seed(a ?? entryA);
        h.overtime.stored = saldoA;
        h.settingsB
          ..workdays = [2, 3, 4]
          ..weeklyHours = 24;
        h.workB.store[moKey] = b ?? entryB;
        h.overtimeB
          ..stored = saldoB
          ..lastUpdate = at(12);
      };

  int count(Harness h, String prefix) =>
      h.writeLog.where((e) => e.startsWith(prefix)).length;

  /// Stop in A mit haengendem Saldo-Write, Wechsel auf B im Fenster, Freigabe.
  void releaseSaldo(Harness h) {
    h.overtime.holdSaveOvertime = false;
    h.overtime.pendingOvertimeSaves.single.complete();
    h.async.flushMicrotasks();
  }

  group('Harness Profilmodus', () {
    scenario('nach switchProfile(B) liest das VM Profil B', at(17), (h) {
      h.boot();
      expect(h.state.workEntry, entryA);
      h.switchProfile('B');
      expect(h.state.workEntry, entryB);
      expect(h.state.isLoading, isFalse);
      expect(h.state.isExtraDay, isTrue);
      h.switchProfile(null);
      expect(h.state.workEntry, entryA);
    }, setUp: prep(), profiles: true);
  });

  group('T1/T2 Wechsel im Saldo-Fenster einer Schreibaktion', () {
    scenario(
        'T1 Stop in A, Wechsel auf B: Eintrag und Saldo landen in A', at(17),
        (h) {
      h.boot();
      h.overtime.holdSaveOvertime = true;
      h.act(h.vm.startOrStopTimer);
      expect(h.overtime.pendingOvertimeSaves, hasLength(1));

      h.switchProfile('B');
      releaseSaldo(h);

      expect(h.writeLog, [
        'A:overtime:135',
        'A:lastUpdate',
        'A:entry:$moKey:08:00-17:00',
      ]);
      expect(h.workB.store[moKey], entryB);
      expect(h.workB.saved, isEmpty);
      expect(h.overtimeB.stored, saldoB);
      expect(h.state.workEntry, entryB);
      expect(h.state.totalOvertime, saldoB);
      expect(h.state.isLoading, isFalse);
      expect(h.async.periodicTimerCount, 0);
    }, setUp: prep(), profiles: true);

    final finished = entryOf(mo, start: at(8), end: at(17));
    final breakB1 =
        BreakEntity(id: 'b1', name: 'Pause 1', start: at(12), end: at(12, 30));
    final finishedWithBreak =
        entryOf(mo, start: at(8), end: at(17), breaks: [breakB1]);

    final actions =
        <String, ({WorkEntryEntity seed, Future<void> Function(Harness) run})>{
      'startOrStopTimer': (seed: entryA, run: (h) => h.vm.startOrStopTimer()),
      'setManualEndTime': (
        seed: entryA,
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
      scenario('T2 ${e.key}: alle Writes im Profil des Aktionsbeginns', at(17),
          (h) {
        h.boot();
        h.overtime.holdSaveOvertime = true;
        h.act(() => e.value.run(h));
        expect(h.overtime.pendingOvertimeSaves, hasLength(1));

        h.switchProfile('B');
        releaseSaldo(h);

        expect(count(h, 'B:'), 0, reason: h.writeLog.toString());
        expect(count(h, 'A:overtime'), 1);
        expect(count(h, 'A:entry'), 1);
        expect(h.workB.store[moKey], entryB);
        expect(h.overtimeB.stored, saldoB);
        expect(h.state.workEntry, entryB);
        expect(h.state.totalOvertime, saldoB);
      }, setUp: (h) => prep(a: e.value.seed)(h), profiles: true);
    }

    // `toggleBreak.call` ist im Betrieb nur ein Microtask-Sprung; hier haelt
    // ein Test-UseCase ihn offen, damit der Wechsel in dieses Fenster faellt.
    // Geprueft wird nur, in welches Profil geschrieben wird: den Saldo-Wert
    // nicht, denn Basis und Soll liest `_recalculateStateAndSave` nach dem
    // `await` aus dem Zustand/den Settings von B. Im Betrieb ist das Fenster
    // unerreichbar (ein Profilwechsel braucht einen eigenen Scheduler-Task).
    final gates = <Completer<void>>[];
    scenario(
        'T2 startOrStopBreak: Wechsel waehrend toggleBreak, Saldo bleibt in A',
        at(17), (h) {
      h.boot();
      h.act(h.vm.startOrStopBreak);
      expect(gates, hasLength(1));

      h.switchProfile('B');
      gates.single.complete();
      h.async.flushMicrotasks();

      expect(count(h, 'B:'), 0, reason: h.writeLog.toString());
      expect(count(h, 'A:overtime'), 1);
      expect(count(h, 'A:entry'), 1);
      expect(h.workB.store[moKey], entryB);
      expect(h.state.workEntry, entryB);
    }, setUp: (h) => prep(a: finished)(h), profiles: true, overrides: [
      toggleBreakUseCaseProvider.overrideWith((ref) {
        return _HeldToggleBreak(gates, ref.watch(clockProvider));
      }),
    ]);
  });

  group('T3-T5, T9 Einfrieren, Rueckwechsel, Autosave', () {
    scenario('T3 Einfrieren: nach dem Wechsel keine Writes mehr', at(10), (h) {
      h.boot();
      h.tick(const Duration(seconds: 65));
      expect(count(h, 'A:entry'), 2, reason: 'Autosaves bei 30/60 s');
      final before = h.writeLog.length;
      expect(h.state.isExtraDay, isFalse);

      h.switchProfile('B');
      h.tick(const Duration(minutes: 5));

      expect(h.writeLog.length, before);
      expect(h.work.store[moKey], entryA);
      expect(h.async.periodicTimerCount, 0, reason: 'B laeuft nicht');
      expect(h.state.workEntry, entryB);
      expect(h.state.initialOvertime, saldoB - const Duration(hours: 3));
      expect(h.state.totalOvertime, saldoB);
      expect(h.state.isExtraDay, isTrue);
    }, setUp: prep(), profiles: true);

    scenario('T4 Rueckwechsel setzt A fort (inkl. Zeit in B)', at(10), (h) {
      h.boot();
      h.tick(const Duration(seconds: 65));
      h.switchProfile('B');
      h.tick(const Duration(minutes: 5));
      final before = h.writeLog.length;

      h.switchProfile(null);

      expect(h.writeLog.length, before, reason: 'kein Write beim Wechsel');
      expect(h.work.store[moKey], entryA);
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.state.workEntry.workStart, at(8));
      expect(h.async.periodicTimerCount, 1);
      expect(h.state.grossWorkDuration, h.clock().difference(at(8)));
      expect(h.state.grossWorkDuration! > const Duration(hours: 2), isTrue);
    }, setUp: prep(), profiles: true);

    scenario('T5 Autosave nach dem Wechsel: nichts aus A landet in B', at(10),
        (h) {
      h.boot();
      h.switchProfile('B');
      h.tick(const Duration(seconds: 31));
      expect(h.workB.saved, isEmpty);
      expect(h.work.saved, isEmpty);
      expect(h.writeLog, isEmpty);
    }, setUp: prep(), profiles: true);

    scenario(
        'T5 Parallelbetrieb: A eingefroren, Autosave schreibt nur B', at(10),
        (h) {
      h.boot();
      h.switchProfile('B');
      expect(h.async.periodicTimerCount, 1);
      h.tick(const Duration(seconds: 31));
      expect(h.writeLog, ['B:entry:$moKey:09:00--']);
      expect(h.work.saved, isEmpty);
    }, setUp: prep(b: entryOf(mo, start: at(9))), profiles: true);

    scenario('T9 Cleanup: Dispose raeumt B-Timer, A bleibt eingefroren', at(10),
        (h) {
      h.boot();
      h.switchProfile('B');
      expect(h.async.periodicTimerCount, 1);
      h.dispose();
      expect(h.async.periodicTimerCount, 0);
      expect(h.async.nonPeriodicTimerCount, 0);
      expect(h.work.store[moKey], entryA);
    }, setUp: prep(b: entryOf(mo, start: at(9))), profiles: true);
  });

  group('T6 Wechsel im Eintrag-Fenster', () {
    scenario('T6 beide Writes in A, kein Timer-Neustart fuer B', at(17), (h) {
      h.boot();
      h.work.holdSaves = true;
      h.act(h.vm.startOrStopTimer);
      expect(h.work.pendingSaves, hasLength(1));
      expect(h.writeLog, ['A:overtime:135', 'A:lastUpdate']);

      h.switchProfile('B');
      expect(h.async.periodicTimerCount, 1);
      h.tick(const Duration(seconds: 20));
      h.work.holdSaves = false;
      h.work.pendingSaves.single.complete();
      h.async.flushMicrotasks();

      expect(h.writeLog.last, 'A:entry:$moKey:08:00-17:00');
      expect(count(h, 'B:'), 0);
      expect(h.state.workEntry.workStart, at(9));
      expect(h.async.periodicTimerCount, 1);
      // Der B-Timer wurde nicht neu gestartet: sein Autosave kommt 30 s nach
      // dem Wechsel (20 s + 10 s), nicht 30 s nach der Freigabe.
      h.tick(const Duration(seconds: 10));
      expect(count(h, 'B:entry'), 1);
    }, setUp: prep(b: entryOf(mo, start: at(9))), profiles: true);
  });

  group('T7 ueberholte Ladelaeufe', () {
    scenario('A -> B -> A mit haengendem B-Lesen: Endzustand A, kein B-Timer',
        at(17), (h) {
      h.boot();
      h.workB.holdReads = true;
      h.switchProfile('B');
      expect(h.workB.pendingReads, hasLength(1));
      h.switchProfile(null);
      expect(h.state.workEntry, entryA);
      expect(h.async.periodicTimerCount, 1);

      h.workB.pendingReads.single.complete();
      h.async.flushMicrotasks();

      expect(h.state.workEntry, entryA);
      expect(h.state.isExtraDay, isFalse);
      expect(h.async.periodicTimerCount, 1);
      expect(h.writeLog, isEmpty);
    }, setUp: prep(b: entryOf(mo, start: at(9))), profiles: true);

    scenario(
        'Wechsel waehrend haengendem Saldo-Laden: A-Ergebnis verworfen', at(17),
        (h) {
      final hold = Completer<void>();
      h.overtime.holdOvertimeLoad = hold;
      h.boot();
      h.switchProfile('B');
      expect(h.state.workEntry, entryB);

      hold.complete();
      h.async.flushMicrotasks();

      expect(h.state.workEntry, entryB);
      expect(h.state.totalOvertime, saldoB);
      expect(h.async.periodicTimerCount, 0, reason: 'kein A-Timer');
    }, setUp: prep(), profiles: true);
  });

  group('T8 Tageswechsel x Profilwechsel', () {
    final di = DateTime(2026, 10, 6);
    final runningA = entryOf(mo, start: at(22));
    scenario('Profilwechsel nutzt lastUpdate-Heuristik, Mitternacht danach',
        at(23, 59, 50), (h) {
      h.boot();
      h.switchProfile('B');
      // Heuristik (gleicher Tag wie lastUpdate): Basis = Saldo - Tagesanteil.
      expect(h.state.workEntry, entryB);
      expect(h.state.initialOvertime, saldoB - const Duration(hours: 3));

      h.tick(const Duration(seconds: 20));

      expect(h.state.workEntry.date, di);
      expect(h.state.isLoading, isFalse);
      expect(h.state.initialOvertime, saldoB);
      expect(h.writeLog, isEmpty);
      expect(h.async.periodicTimerCount, 0);
      expect(h.work.store[moKey], runningA);
    }, setUp: (h) {
      prep(a: runningA)(h);
      h.overtimeB.lastUpdate = at(8);
    }, profiles: true);
  });

  group('O1 Dispose mitten in der Aktion', () {
    // Nur eine ueberholte Aktion schluckt Fehler; sonst geht er wie vor #388
    // an den Aufrufer (hier setManualEndTime, nicht der Stop-Pfad, dessen
    // Fehlerbehandlung ein eigenes Thema ist).
    scenario(
        'ohne Ueberholung: Saldo-Fehler wird weitergereicht, nichts geschrieben',
        at(17), (h) {
      h.boot();
      h.overtime.failSaveOvertime = true;
      Object? error;
      unawaited(h.vm
          .setManualEndTime(const TimeOfDay(hour: 16, minute: 30))
          .then<void>((_) {}, onError: (Object e) => error = e));
      h.async.flushMicrotasks();

      expect(error, isA<Exception>());
      expect(h.writeLog, isEmpty);
      expect(h.work.saved, isEmpty);
    }, setUp: prep(a: finishedA), profiles: true);

    scenario('Logout/Dispose: begonnene Aktion schreibt zu Ende', at(17), (h) {
      h.boot();
      h.overtime.holdSaveOvertime = true;
      h.act(h.vm.startOrStopTimer);

      h.dispose();
      releaseSaldo(h);

      expect(h.writeLog, [
        'A:overtime:135',
        'A:lastUpdate',
        'A:entry:$moKey:08:00-17:00',
      ]);
    }, setUp: prep(), profiles: true);

    scenario('Dispose: scheiternder Write wird geschluckt, keine Folgeschritte',
        at(17), (h) {
      h.boot();
      h.overtime.holdSaveOvertime = true;
      h.act(h.vm.startOrStopTimer);

      h.dispose();
      h.overtime.failSaveOvertime = true;
      releaseSaldo(h);

      expect(h.writeLog, isEmpty);
      expect(h.work.saved, isEmpty);
    }, setUp: prep(), profiles: true);
  });

  // O4: die Ueberstunden-Warnung nutzt Flags und Schwellen des Profils der
  // Aktion (festgehaltenes Settings-Repo), nicht die des neuen Profils.
  group('O4 Ueberstunden-Warnung je Profil', () {
    final warnings = <OvertimeWarningType>[];
    final overrides = [
      notificationServiceProvider
          .overrideWithValue(_FakeNotifications(warnings))
    ];

    // Stop in A ergibt Saldo 135 min (2,25 h); Wechsel auf B im Saldo-Fenster.
    void stopWithSwitch(Harness h) {
      warnings.clear();
      h.boot();
      h.overtime.holdSaveOvertime = true;
      h.act(h.vm.startOrStopTimer);
      h.switchProfile('B');
      releaseSaldo(h);
      expect(h.writeLog, contains('A:overtime:135'));
    }

    scenario(
        'A warnt (2 h), B nicht: Warnung kommt trotz Wechsel auf B', at(17),
        (h) {
      stopWithSwitch(h);
      expect(warnings, [OvertimeWarningType.overtime]);
    }, setUp: (h) {
      prep()(h);
      h.settings
        ..warnOnOvertime = true
        ..overtimeThresholdHours = 2;
    }, profiles: true, overrides: overrides);

    scenario('A warnt nicht, B wuerde warnen: keine Warnung nach dem Wechsel',
        at(17), (h) {
      stopWithSwitch(h);
      expect(warnings, isEmpty);
    }, setUp: (h) {
      prep()(h);
      h.settingsB
        ..warnOnOvertime = true
        ..overtimeThresholdHours = 1;
    }, profiles: true, overrides: overrides);

    scenario('Schwelle aus A (3 h, nicht erreicht) gilt, nicht die aus B (1 h)',
        at(17), (h) {
      stopWithSwitch(h);
      expect(warnings, isEmpty);
    }, setUp: (h) {
      prep()(h);
      h.settings
        ..warnOnOvertime = true
        ..overtimeThresholdHours = 3;
      h.settingsB
        ..warnOnOvertime = true
        ..overtimeThresholdHours = 1;
    }, profiles: true, overrides: overrides);
  });

  group('T10 WorkProfileViewModel x laufendes Dashboard', () {
    final mock = MockWorkProfileRepository();

    scenario('T10d addProfile wechselt automatisch und friert A ein', at(10),
        (h) {
      when(mock.addProfile('Neu')).thenAnswer(
          (_) async => const WorkProfileEntity(id: 'p1', name: 'Neu'));
      h.boot();
      h.tick(const Duration(seconds: 31));
      expect(count(h, 'A:entry'), 1, reason: 'Autosave in A');

      h.act(() =>
          h.container.read(workProfileViewModelProvider).addProfile('Neu'));
      h.switchProfile('p1');
      final before = h.writeLog.length;
      h.tick(const Duration(seconds: 31));

      expect(h.writeLog.length, before);
      expect(h.state.workEntry, entryB);
      expect(h.work.store[moKey], entryA);
    },
        setUp: prep(),
        profiles: true,
        overrides: [workProfileRepositoryProvider.overrideWithValue(mock)]);

    scenario(
        'T10e deleteProfile(aktiv) schreibt nichts mehr ins geloeschte', at(10),
        (h) {
      final hold = Completer<void>();
      when(mock.deleteProfile('p1')).thenAnswer((_) => hold.future);
      h.boot();
      h.switchProfile('p1');
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.async.periodicTimerCount, 1, reason: 'B laeuft');

      h.act(() =>
          h.container.read(workProfileViewModelProvider).deleteProfile('p1'));
      h.tick(const Duration(seconds: 31));

      expect(count(h, 'B:'), 0, reason: h.writeLog.toString());
      hold.complete();
      h.async.flushMicrotasks();
      expect(h.state.workEntry, finishedA);
    },
        setUp: (h) => prep(a: finishedA, b: entryOf(mo, start: at(9)))(h),
        profiles: true,
        overrides: [workProfileRepositoryProvider.overrideWithValue(mock)]);
  });
}

class _HeldToggleBreak extends ToggleBreak {
  _HeldToggleBreak(this._gates, DateTime Function() clock)
      : super(clock: clock);

  /// Der Completer entsteht erst im Aufruf (also in der fakeAsync-Zone).
  final List<Completer<void>> _gates;

  @override
  Future<WorkEntryEntity> call(WorkEntryEntity currentEntry) async {
    final gate = Completer<void>();
    _gates.add(gate);
    await gate.future;
    return super.call(currentEntry);
  }
}

class _FakeNotifications implements NotificationService {
  _FakeNotifications(this.warnings);

  final List<OvertimeWarningType> warnings;

  @override
  Future<void> showOvertimeWarning({
    required OvertimeWarningType type,
    required Duration totalOvertime,
    required AppLocalizations l10n,
  }) async {
    warnings.add(type);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
