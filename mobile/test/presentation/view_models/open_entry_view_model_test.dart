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
}
