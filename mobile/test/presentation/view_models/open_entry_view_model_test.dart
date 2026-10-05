import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/today_provider.dart';
import 'package:flutter_work_time/domain/usecases/close_open_work_entry.dart';
import 'package:flutter_work_time/presentation/view_models/open_entry_view_model.dart';

import '../../support/dashboard_harness.dart';
import '../../support/fake_repositories.dart';

// Fr 2026-10-02, Sa 2026-10-03, So 2026-10-04, Mo 2026-10-05.
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  final thu = DateTime(2026, 10, 1);
  final fri = DateTime(2026, 10, 2);
  final sat = DateTime(2026, 10, 3);
  final sun = DateTime(2026, 10, 4);

  final saturdayMorning = DateTime(2026, 10, 3, 9);

  OpenEntryState openState(Harness h) =>
      h.container.read(openEntryViewModelProvider);
  OpenEntryViewModel openVm(Harness h) =>
      h.container.read(openEntryViewModelProvider.notifier);

  void boot(Harness h) {
    h.boot();
    h.container.listen(openEntryViewModelProvider, (_, __) {});
    openVm(h);
    h.async.flushMicrotasks();
  }

  List<DateTime> dates(Harness h) =>
      openState(h).entries.map((e) => e.date).toList();

  void seedOpen(FakeWorkRepository r, DateTime day, {int startHour = 8}) {
    r.store[dayKey(day)] =
        entryOf(day, start: DateTime(day.year, day.month, day.day, startHour));
  }

  group('Zustand und Reihenfolge', () {
    scenario(
        'Start mit offenem Vortag: neuester zuerst, moreCount', saturdayMorning,
        (h) {
      boot(h);
      expect(dates(h), [fri, thu]);
      expect(openState(h).current!.date, fri);
      expect(openState(h).moreCount, 1);
      expect(openState(h).busy, isFalse);
      expect(openState(h).saveError, isFalse);
    }, setUp: (h) {
      seedOpen(h.work, thu);
      seedOpen(h.work, fri);
    }, profiles: true);

    scenario('kein offener Vortag: leerer Zustand', saturdayMorning, (h) {
      boot(h);
      expect(openState(h).entries, isEmpty);
      expect(openState(h).current, isNull);
      expect(openState(h).moreCount, 0);
    }, profiles: true);

    scenario('Lesefehler der Suche: kein Banner, kein Crash', saturdayMorning,
        (h) {
      h.work.failReads = true;
      boot(h);
      expect(openState(h).entries, isEmpty);
    }, setUp: (h) {
      seedOpen(h.work, fri);
    }, profiles: true);
  });

  group('Später', () {
    scenario('blendet den ganzen Banner für die Sitzung aus', saturdayMorning,
        (h) {
      boot(h);
      expect(dates(h), [fri, thu]);
      openVm(h).later();
      h.async.flushMicrotasks();
      expect(openState(h).entries, isEmpty);
    }, setUp: (h) {
      seedOpen(h.work, thu);
      seedOpen(h.work, fri);
    }, profiles: true);

    scenario('gilt je Profil + Eintrag: A->B->A bleibt, B unabhängig',
        saturdayMorning, (h) {
      boot(h);
      openVm(h).later();
      h.async.flushMicrotasks();
      expect(openState(h).entries, isEmpty);

      h.switchProfile('b');
      expect(dates(h), [fri], reason: 'B ist unabhängig von A');

      h.switchProfile(null);
      expect(openState(h).entries, isEmpty,
          reason: 'A bleibt nach Rückwechsel ausgeblendet');
    }, setUp: (h) {
      seedOpen(h.work, fri);
      seedOpen(h.workB, fri);
    }, profiles: true);

    scenario(
        'nach Neustart (neuer Container) erscheint er wieder', saturdayMorning,
        (h) {
      boot(h);
      openVm(h).later();
      h.async.flushMicrotasks();
      expect(openState(h).entries, isEmpty);

      final restarted = Harness(h.async, saturdayMorning, profiles: true);
      seedOpen(restarted.work, fri);
      boot(restarted);
      expect(dates(restarted), [fri]);
      restarted.dispose();
    }, setUp: (h) {
      seedOpen(h.work, fri);
    }, profiles: true);

    scenario('Tageswechsel: Später bleibt, neuer Kandidat erscheint',
        saturdayMorning, (h) {
      boot(h);
      openVm(h).later();
      h.async.flushMicrotasks();
      expect(openState(h).entries, isEmpty);

      // Ein anderes Gerät hat Sa gestartet und offen gelassen (das Dashboard
      // zeigt den leeren Sa), danach wechselt der Tag auf So.
      h.work.store[dayKey(sat)] = entryOf(sat, start: DateTime(2026, 10, 3, 8));
      h.clock.jumpTo(DateTime(2026, 10, 4, 9));
      h.container.read(todayProvider.notifier).refresh();
      h.async.flushMicrotasks();
      expect(dates(h), [sat], reason: 'Sa neu, Fr bleibt ausgeblendet');
    }, setUp: (h) {
      seedOpen(h.work, fri);
    }, profiles: true);
  });

  group('Profilwechsel', () {
    scenario('sucht im Repo des neuen Profils, verwirft den alten Zustand',
        saturdayMorning, (h) {
      boot(h);
      expect(dates(h), [fri]);
      final readsA = h.work.monthReads.length;

      h.switchProfile('b');
      expect(openState(h).entries, isEmpty, reason: 'B hat keine offenen');
      expect(h.workB.monthReads, isNotEmpty);
      expect(h.work.monthReads.length, readsA, reason: 'A nicht mehr gelesen');
    }, setUp: (h) {
      seedOpen(h.work, fri);
    }, profiles: true);

    scenario(
        'spätes Ergebnis des alten Profils überschreibt nicht', saturdayMorning,
        (h) {
      h.work.holdReads = true;
      boot(h);
      expect(openState(h).entries, isEmpty, reason: 'A-Lesen hängt');

      h.switchProfile('b');
      expect(dates(h), [thu], reason: 'B geladen');

      h.work.holdReads = false;
      for (final c in h.work.pendingReads) {
        c.complete();
      }
      h.async.flushMicrotasks();
      expect(dates(h), [thu], reason: 'A-Ergebnis (Fr) wird verworfen');
    }, setUp: (h) {
      seedOpen(h.work, fri);
      seedOpen(h.workB, thu);
    }, profiles: true);
  });

  group('Tageswechsel', () {
    scenario('sucht neu (Listener, kein Verlust des Zustands)', saturdayMorning,
        (h) {
      boot(h);
      expect(dates(h), [fri]);
      final reads = h.work.monthReads.length;

      h.work.store[dayKey(sat)] = entryOf(sat, start: DateTime(2026, 10, 3, 8));
      h.clock.jumpTo(DateTime(2026, 10, 4, 0, 30));
      h.container.read(todayProvider.notifier).refresh();
      h.async.flushMicrotasks();
      expect(h.work.monthReads.length, greaterThan(reads));
      expect(dates(h), [sat, fri]);
      expect(sun, isNotNull);
    }, setUp: (h) {
      seedOpen(h.work, fri);
    }, profiles: true);
  });

  group('laufender Dashboard-Eintrag', () {
    scenario('läuft über Mitternacht: kein Banner, nach Stop auch nicht',
        DateTime(2026, 10, 2, 22), (h) {
      boot(h);
      h.act(h.vm.startOrStopTimer);
      expect(h.state.workEntry.workEnd, isNull);
      expect(openState(h).entries, isEmpty);

      h.clock.jumpTo(DateTime(2026, 10, 3, 9));
      h.tick();
      expect(h.state.workEntry.date, fri, reason: 'Dashboard läuft am Vortag');
      expect(h.work.store[dayKey(fri)]!.workEnd, isNull,
          reason: 'im Repo noch offen');
      expect(openState(h).entries, isEmpty,
          reason: 'laufender Eintrag erzeugt keinen Banner');

      h.act(h.vm.startOrStopTimer);
      expect(h.work.store[dayKey(fri)]!.workEnd, isNotNull);
      expect(openState(h).entries, isEmpty,
          reason: 'nach Stop ist er abgeschlossen');
    }, profiles: true);
  });

  group('endEntry', () {
    scenario('Erfolg: Soll am Eintragsdatum, Re-Check, Dashboard-Reload',
        saturdayMorning, (h) {
      boot(h);
      expect(dates(h), [fri, thu]);
      final todayReads = h.work.getWorkEntryCalls;

      h.act(() => openVm(h).endEntry(DateTime(2026, 10, 2, 16)));

      // 8 h brutto -> 30 min Auto-Pause -> 7:30 Netto, Soll Fr 8 h -> -30 min
      expect(h.writeLog, [
        'A:overtime:-30',
        'A:entry:2026-10-02:08:00-16:00',
      ]);
      expect(dates(h), [thu], reason: 'nächster offener wird sichtbar');
      expect(openState(h).busy, isFalse);
      expect(openState(h).saveError, isFalse);
      expect(h.work.getWorkEntryCalls, greaterThan(todayReads),
          reason: 'Dashboard wurde neu geladen');
      expect(h.state.initialOvertime, const Duration(minutes: -30));
    }, setUp: (h) {
      seedOpen(h.work, thu);
      seedOpen(h.work, fri);
    }, profiles: true);

    scenario('Soll des Eintragsdatums (Samstag: 0), nicht des heutigen Tages',
        DateTime(2026, 10, 5, 9), (h) {
      boot(h);
      h.act(() => openVm(h).endEntry(DateTime(2026, 10, 3, 12)));
      // Sa 08:00-12:00 = 4 h, Soll 0 (heute Montag hätte 8 h)
      expect(h.writeLog.first, 'A:overtime:240');
    }, setUp: (h) {
      seedOpen(h.work, sat);
    }, profiles: true);

    scenario('Fehler: Banner bleibt, saveError gesetzt, kein Reload',
        saturdayMorning, (h) {
      boot(h);
      final todayReads = h.work.getWorkEntryCalls;
      h.overtime.failSaveOvertime = true;
      h.act(() => openVm(h).endEntry(DateTime(2026, 10, 2, 16)));

      expect(dates(h), [fri]);
      expect(openState(h).saveError, isTrue);
      expect(openState(h).busy, isFalse);
      expect(h.work.getWorkEntryCalls, todayReads, reason: 'kein Reload');
      expect(h.writeLog, isEmpty);

      // Wiederholbar: nächster Versuch setzt den Fehler zurück und gelingt.
      h.overtime.failSaveOvertime = false;
      h.act(() => openVm(h).endEntry(DateTime(2026, 10, 2, 16)));
      expect(openState(h).saveError, isFalse);
      expect(openState(h).entries, isEmpty);
    }, setUp: (h) {
      seedOpen(h.work, fri);
    }, profiles: true);

    scenario(
        'Eintrag-Fehler nach Saldo-Write: Saldo zurückgerollt, Banner bleibt, '
        'Wiederholen zählt einmal',
        saturdayMorning, (h) {
      boot(h);
      final todayReads = h.work.getWorkEntryCalls;
      h.work.failSaves = true;
      h.act(() => openVm(h).endEntry(DateTime(2026, 10, 2, 16)));

      expect(dates(h), [fri]);
      expect(openState(h).saveError, isTrue);
      expect(openState(h).busy, isFalse);
      expect(h.overtime.stored, const Duration(hours: 1));
      expect(h.writeLog, ['A:overtime:30', 'A:overtime:60']);
      expect(h.work.getWorkEntryCalls, todayReads, reason: 'kein Reload');

      h.work.failSaves = false;
      h.writeLog.clear();
      h.act(() => openVm(h).endEntry(DateTime(2026, 10, 2, 16)));
      expect(h.writeLog, [
        'A:overtime:30',
        'A:entry:2026-10-02:08:00-16:00',
      ]);
      expect(h.overtime.stored, const Duration(minutes: 30));
      expect(openState(h).saveError, isFalse);
      expect(openState(h).entries, isEmpty);
    }, setUp: (h) {
      h.overtime.stored = const Duration(hours: 1);
      seedOpen(h.work, fri);
    }, profiles: true);

    scenario(
        'Profilwechsel im Schreibfenster + Eintrag-Fehler: Rollback landet im '
        'Profil des Beginns',
        saturdayMorning, (h) {
      boot(h);
      h.work.holdSaves = true;
      h.act(() => openVm(h).endEntry(DateTime(2026, 10, 2, 16)));
      expect(h.work.pendingSaves, hasLength(1));

      h.switchProfile('b');
      h.work.failSaves = true;
      h.work.pendingSaves.single.complete();
      h.async.flushMicrotasks();

      expect(h.writeLog, ['A:overtime:30', 'A:overtime:60']);
      expect(h.overtime.stored, const Duration(hours: 1));
      expect(h.overtimeB.savedOvertimes, isEmpty);
      expect(h.workB.saved, isEmpty);
    }, setUp: (h) {
      h.overtime.stored = const Duration(hours: 1);
      seedOpen(h.work, fri);
    }, profiles: true);

    scenario('Doppeltippen: zweiter Aufruf während der Aktion wird ignoriert',
        saturdayMorning, (h) {
      boot(h);
      h.overtime.holdSaveOvertime = true;
      h.act(() => openVm(h).endEntry(DateTime(2026, 10, 2, 16)));
      expect(openState(h).busy, isTrue);
      h.act(() => openVm(h).endEntry(DateTime(2026, 10, 2, 16)));
      expect(h.overtime.pendingOvertimeSaves, hasLength(1));

      h.overtime.pendingOvertimeSaves.single.complete();
      h.async.flushMicrotasks();
      expect(h.work.saved, hasLength(1));
      expect(h.overtime.savedOvertimes, hasLength(1));
      expect(openState(h).busy, isFalse);
    }, setUp: (h) {
      seedOpen(h.work, fri);
    }, profiles: true);

    scenario(
        'Profilwechsel mitten in der Aktion: Writes im Profil des '
        'Beginns, neues Profil unverändert, kein Reload',
        saturdayMorning, (h) {
      boot(h);
      h.overtime.holdSaveOvertime = true;
      h.act(() => openVm(h).endEntry(DateTime(2026, 10, 2, 16)));
      expect(h.overtime.pendingOvertimeSaves, hasLength(1));

      h.switchProfile('b');
      final stateB = openState(h);
      final readsB = h.workB.getWorkEntryCalls;
      expect(dates(h), isEmpty);

      h.overtime.pendingOvertimeSaves.single.complete();
      h.async.flushMicrotasks();

      expect(h.writeLog, [
        'A:overtime:-30',
        'A:entry:2026-10-02:08:00-16:00',
      ]);
      expect(openState(h), stateB, reason: 'State von B unverändert');
      expect(openState(h).busy, isFalse);
      expect(h.workB.getWorkEntryCalls, readsB, reason: 'kein Reload von B');
    }, setUp: (h) {
      seedOpen(h.work, fri);
    }, profiles: true);

    scenario('Ergebnis alreadyClosed: Banner verschwindet ohne Saldo-Write',
        saturdayMorning, (h) {
      boot(h);
      // Anderes Gerät hat den Eintrag inzwischen beendet.
      h.work.store[dayKey(fri)] = entryOf(fri,
          start: DateTime(2026, 10, 2, 8), end: DateTime(2026, 10, 2, 17));
      h.act(() => openVm(h).endEntry(DateTime(2026, 10, 2, 16)));
      expect(h.writeLog, isEmpty);
      expect(openState(h).entries, isEmpty);
      expect(openState(h).saveError, isFalse);
    }, setUp: (h) {
      seedOpen(h.work, fri);
    }, profiles: true);

    scenario('Ergebnis wird zurückgegeben', saturdayMorning, (h) {
      boot(h);
      CloseOpenEntryResult? r;
      h.act(() async {
        r = await openVm(h).endEntry(DateTime(2026, 10, 2, 16));
      });
      expect(r, CloseOpenEntryResult.closed);
    }, setUp: (h) {
      seedOpen(h.work, fri);
    }, profiles: true);
  });

  group('canResume und resume() (#385 PR 1b)', () {
    bool? resumeResult;

    Future<void> doResume(Harness h) async {
      resumeResult = await openVm(h).resume();
    }

    setUp(() => resumeResult = null);

    scenario('Vortag offen, heute leer, <= 24 h: canResume', saturdayMorning,
        (h) {
      boot(h);
      expect(openState(h).canResume, isTrue);
    }, setUp: (h) => seedOpen(h.work, fri, startHour: 22), profiles: true);

    scenario('> 24 h: kein canResume, Beenden bleibt (Eintrag sichtbar)',
        saturdayMorning, (h) {
      boot(h);
      expect(dates(h), [fri]);
      expect(openState(h).canResume, isFalse);
    }, setUp: (h) => seedOpen(h.work, fri), profiles: true);

    scenario('heute nicht leer: kein canResume', saturdayMorning, (h) {
      boot(h);
      expect(dates(h), [fri]);
      expect(h.state.workEntry.workStart, isNotNull);
      expect(openState(h).canResume, isFalse);
    }, setUp: (h) {
      seedOpen(h.work, fri, startHour: 22);
      seedOpen(h.work, sat);
    }, profiles: true);

    scenario('Dashboard lädt noch: kein canResume, danach ja', saturdayMorning,
        (h) {
      final hold = Completer<void>();
      h.overtime.holdOvertimeLoad = hold;
      boot(h);
      expect(h.state.isLoading, isTrue);
      expect(dates(h), [fri]);
      expect(openState(h).canResume, isFalse);

      hold.complete();
      h.async.flushMicrotasks();
      expect(h.state.isLoading, isFalse);
      expect(openState(h).canResume, isTrue);
    }, setUp: (h) => seedOpen(h.work, fri, startHour: 22), profiles: true);

    scenario('Start heute blendet canResume aus, Stop heute lässt es aus',
        saturdayMorning, (h) {
      boot(h);
      expect(openState(h).canResume, isTrue);

      h.act(h.vm.startOrStopTimer);
      expect(h.state.workEntry.workStart, isNotNull);
      expect(openState(h).canResume, isFalse);
      expect(dates(h), [fri], reason: 'Beenden bleibt');

      h.tick(const Duration(minutes: 1));
      h.act(h.vm.startOrStopTimer);
      expect(h.state.workEntry.workEnd, isNotNull);
      expect(openState(h).canResume, isFalse, reason: 'heute nicht leer');
    }, setUp: (h) => seedOpen(h.work, fri, startHour: 22), profiles: true);

    scenario('Tageswechsel über die 24-h-Grenze: canResume wird false',
        saturdayMorning, (h) {
      boot(h);
      expect(openState(h).canResume, isTrue);

      h.clock.jumpTo(DateTime(2026, 10, 4, 0, 30)); // Fr 22:00 + 26,5 h
      h.container.read(todayProvider.notifier).refresh();
      h.async.flushMicrotasks();
      expect(dates(h), contains(fri));
      expect(openState(h).canResume, isFalse);
    }, setUp: (h) => seedOpen(h.work, fri, startHour: 22), profiles: true);

    scenario(
        'mehrere Kandidaten: canResume gilt für den neuesten', saturdayMorning,
        (h) {
      boot(h);
      expect(dates(h), [fri, thu]);
      expect(openState(h).canResume, isTrue);
    }, setUp: (h) {
      seedOpen(h.work, thu, startHour: 22);
      seedOpen(h.work, fri, startHour: 22);
    }, profiles: true);

    scenario(
        'mehrere Kandidaten, neuester > 24 h: kein canResume', saturdayMorning,
        (h) {
      boot(h);
      expect(dates(h), [fri, thu]);
      expect(openState(h).canResume, isFalse);
    }, setUp: (h) {
      seedOpen(h.work, thu, startHour: 22);
      seedOpen(h.work, fri, startHour: 8);
    }, profiles: true);

    scenario(
        'resume() Erfolg: Dashboard pinnt, Banner weg, keine Zusatz-Reads, '
        'Später-Schlüssel unverändert',
        saturdayMorning, (h) {
      boot(h);
      final monthReads = h.work.monthReads.length;
      final dismissed = h.container.read(openEntryDismissedProvider);

      h.act(() => doResume(h));

      expect(resumeResult, isTrue);
      expect(h.state.workEntry.date, fri);
      expect(h.vm.isTimerRunning, isTrue);
      expect(openState(h).busy, isFalse);
      expect(openState(h).saveError, isFalse);
      expect(dates(h), [thu], reason: 'nur der ältere bleibt Kandidat');
      expect(openState(h).canResume, isFalse,
          reason: 'Dashboard zeigt Vortag, heute nicht leer');
      expect(h.work.monthReads.length, monthReads);
      expect(h.container.read(openEntryDismissedProvider), dismissed);
      expect(h.writeLog, isEmpty);
    }, setUp: (h) {
      seedOpen(h.work, thu, startHour: 22);
      seedOpen(h.work, fri, startHour: 22);
    }, profiles: true);

    scenario(
        'nach Stop im Dashboard: Eintrag nicht mehr Kandidat', saturdayMorning,
        (h) {
      boot(h);
      h.act(() => doResume(h));
      expect(dates(h), isEmpty);

      h.tick(const Duration(minutes: 1));
      h.act(h.vm.startOrStopTimer);
      expect(h.state.workEntry.date, sat, reason: 'Reinit auf heute');
      expect(dates(h), isEmpty, reason: 'beendeter Eintrag kommt nicht zurück');
    }, setUp: (h) => seedOpen(h.work, fri, startHour: 22), profiles: true);

    scenario(
        'nach Stop wird der ältere Kandidat sichtbar, ohne Fortsetzen (> 24 h)',
        saturdayMorning, (h) {
      boot(h);
      h.act(() => doResume(h));
      expect(dates(h), [thu]);
      h.tick(const Duration(minutes: 1));
      h.act(h.vm.startOrStopTimer);
      expect(dates(h), [thu]);
      expect(openState(h).canResume, isFalse);
    }, setUp: (h) {
      seedOpen(h.work, thu, startHour: 22);
      seedOpen(h.work, fri, startHour: 22);
    }, profiles: true);

    scenario(
        'resume() abgelehnt (anderes Gerät beendet): Banner bleibt, kein Fehler',
        saturdayMorning, (h) {
      boot(h);
      h.work.store[dayKey(fri)] = entryOf(fri,
          start: DateTime(2026, 10, 2, 22), end: DateTime(2026, 10, 2, 23));
      h.act(() => doResume(h));

      expect(resumeResult, isFalse);
      expect(openState(h).busy, isFalse);
      expect(openState(h).saveError, isFalse);
      expect(dates(h), [fri], reason: 'Banner bleibt (stiller Fehlschlag)');
      expect(h.state.workEntry.date, sat);
      expect(h.vm.isTimerRunning, isFalse);
      expect(h.writeLog, isEmpty);
    }, setUp: (h) => seedOpen(h.work, fri, startHour: 22), profiles: true);

    scenario('resume() prüft zum Tap-Zeitpunkt erneut (24 h überschritten)',
        saturdayMorning, (h) {
      boot(h);
      expect(openState(h).canResume, isTrue);
      final reads = h.work.getWorkEntryCalls;
      // Uhr läuft über die Grenze, ohne dass ein Ereignis neu veröffentlicht.
      h.clock.jumpTo(DateTime(2026, 10, 3, 22, 1));
      h.act(() => doResume(h));

      expect(resumeResult, isFalse);
      expect(h.work.getWorkEntryCalls, reads,
          reason: 'Dashboard nicht gefragt');
      expect(openState(h).busy, isFalse);
      expect(openState(h).canResume, isFalse, reason: 'neu berechnet');
      expect(dates(h), [fri]);
    }, setUp: (h) => seedOpen(h.work, fri, startHour: 22), profiles: true);

    scenario('resume() ohne Kandidat: false', saturdayMorning, (h) {
      boot(h);
      expect(openState(h).current, isNull);
      h.act(() => doResume(h));
      expect(resumeResult, isFalse);
      expect(openState(h).busy, isFalse);
    }, profiles: true);

    scenario('Doppeltippen: zweiter Aufruf ignoriert, ein Pin', saturdayMorning,
        (h) {
      boot(h);
      final reads = h.work.getWorkEntryCalls;
      h.work.holdReads = true;
      final results = <bool>[];
      h.act(() async => results.add(await openVm(h).resume()));
      expect(openState(h).busy, isTrue);
      h.act(() async => results.add(await openVm(h).resume()));
      expect(results, [false], reason: 'zweiter Aufruf sofort abgewiesen');

      h.work.holdReads = false;
      for (final c in h.work.pendingReads.toList()) {
        c.complete();
      }
      h.async.flushMicrotasks();
      expect(results, [false, true]);
      expect(h.work.getWorkEntryCalls - reads, 1, reason: 'genau ein Pin-Read');
      expect(openState(h).busy, isFalse);
    }, setUp: (h) => seedOpen(h.work, fri, startHour: 22), profiles: true);

    scenario(
        'Profilwechsel mitten im resume(): kein State-Schreiben im neuen Profil',
        saturdayMorning, (h) {
      boot(h);
      h.work.holdReads = true;
      var emissions = 0;
      h.act(() => doResume(h));
      expect(openState(h).busy, isTrue);

      h.switchProfile('b');
      expect(dates(h), isEmpty, reason: 'Profil B ohne offene Einträge');
      h.container.listen(openEntryViewModelProvider, (_, __) => emissions++);

      h.work.holdReads = false;
      for (final c in h.work.pendingReads.toList()) {
        c.complete();
      }
      h.async.flushMicrotasks();

      expect(resumeResult, isFalse);
      expect(emissions, 0, reason: 'nach dem Wechsel nichts mehr publiziert');
      expect(openState(h).busy, isFalse);
      expect(openState(h).saveError, isFalse);
      expect(h.state.workEntry.workStart, isNull);
      expect(h.writeLog, isEmpty);
    }, setUp: (h) => seedOpen(h.work, fri, startHour: 22), profiles: true);

    scenario('Später, dann resume(): kein Kandidat, false', saturdayMorning,
        (h) {
      boot(h);
      openVm(h).later();
      h.async.flushMicrotasks();
      expect(openState(h).entries, isEmpty);
      h.act(() => doResume(h));
      expect(resumeResult, isFalse);
      expect(h.state.workEntry.date, sat);
    }, setUp: (h) => seedOpen(h.work, fri, startHour: 22), profiles: true);
  });
}
