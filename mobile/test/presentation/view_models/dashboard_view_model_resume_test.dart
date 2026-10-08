import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';

import '../../support/dashboard_harness.dart';
import '../../support/fake_repositories.dart' show dayKey;

// Fr 2026-10-02 (Soll 8 h), Sa 2026-10-03 (Soll 0), So 2026-10-04.
// Fortsetzen eines offenen Vortags ("Pinning", #385 PR 1b).
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  final fri = DateTime(2026, 10, 2);
  final sat = DateTime(2026, 10, 3);
  final friStart = DateTime(2026, 10, 2, 22);
  final satMorning = DateTime(2026, 10, 3, 9);

  WorkEntryEntity friOpen() => entryOf(fri, start: friStart);

  // Ergebnis der letzten resumePastEntry-Aufrufe (je Szenario neu).
  bool? resume(Harness h, WorkEntryEntity e, {List<bool>? results}) {
    bool? out;
    h.act(() async {
      out = await h.vm.resumePastEntry(e);
      results?.add(out!);
    });
    return out;
  }

  group('Happy Path', () {
    scenario(
        'pinnt den Vortag: Timer läuft ab Fr 22:00, Soll vom Starttag (Fr)',
        satMorning, (h) {
      h.boot();
      expect(h.state.workEntry.date, sat);
      final r = resume(h, friOpen());
      expect(r, isTrue);
      expect(h.state.workEntry.date, fri);
      expect(h.state.workEntry.workStart, friStart);
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.vm.isTimerRunning, isTrue);
      expect(h.state.isLoading, isFalse);
      expect(h.async.periodicTimerCount, 1);
      expect(h.writeLog, isEmpty, reason: 'Fortsetzen schreibt nichts');
      expect(h.state.elapsedTime, const Duration(hours: 11));
      expect(h.state.isExtraDay, isFalse);
      expect(h.state.dailyOvertime, const Duration(hours: 3)); // 11 h - 8 h
      h.tick(const Duration(minutes: 1));
      expect(h.state.elapsedTime, const Duration(hours: 11, minutes: 1));
    }, setUp: (h) => h.seed(friOpen()), profiles: true);

    scenario('Zusatztag: Sa-Start läuft So weiter mit Soll 0',
        DateTime(2026, 10, 4, 9), (h) {
      h.boot();
      final r = resume(h, entryOf(sat, start: DateTime(2026, 10, 3, 22)));
      expect(r, isTrue);
      expect(h.state.workEntry.date, sat);
      expect(h.state.isExtraDay, isTrue);
      expect(h.state.dailyOvertime, const Duration(hours: 11));
    }, setUp: (h) {
      h.seed(entryOf(sat, start: DateTime(2026, 10, 3, 22)));
    }, profiles: true);
  });

  group('Saldo-Basis', () {
    scenario('Basis = gespeicherter Saldo, auch wenn lastUpdated == heute',
        satMorning, (h) {
      h.boot();
      resume(h, friOpen());
      expect(h.state.initialOvertime, const Duration(hours: 2));
      expect(h.state.totalOvertime, const Duration(hours: 5));
    }, setUp: (h) {
      h.seed(friOpen());
      h.overtime.stored = const Duration(hours: 2);
      h.overtime.lastUpdate = DateTime(2026, 10, 3, 7);
    }, profiles: true);
  });

  group('Pause und Mitternacht', () {
    scenario('offene Pause bleibt offen und wächst mit der Uhr', satMorning,
        (h) {
      h.boot();
      expect(resume(h, h.work.store[dayKey(fri)]!), isTrue);
      expect(h.state.workEntry.breaks.single.end, isNull);
      expect(h.state.elapsedTime, const Duration(hours: 1));
      final gross = h.state.grossWorkDuration!;
      h.tick(const Duration(minutes: 5));
      expect(h.state.workEntry.breaks.single.end, isNull);
      expect(h.state.grossWorkDuration! - gross, const Duration(minutes: 5));
      expect(h.state.elapsedTime, const Duration(hours: 1));
    }, setUp: (h) {
      h.seed(entryOf(fri, start: friStart, breaks: [
        BreakEntity(id: 'b1', name: 'Pause', start: DateTime(2026, 10, 2, 23))
      ]));
    }, profiles: true);

    scenario('läuft über Mitternacht weiter: kein Reinit (Regression #379)',
        satMorning, (h) {
      h.boot();
      resume(h, friOpen());
      final reads = h.work.getWorkEntryCalls;
      h.clock.jumpTo(DateTime(2026, 10, 4, 0, 30));
      h.tick();
      expect(h.state.workEntry.date, fri);
      expect(h.vm.isTimerRunning, isTrue);
      expect(h.work.getWorkEntryCalls, reads, reason: 'kein Nachladen');
      expect(h.async.periodicTimerCount, 1);
    }, setUp: (h) => h.seed(friOpen()), profiles: true);
  });

  group('Autosave und Stop', () {
    scenario('Autosave speichert den Freitags-Eintrag', satMorning, (h) {
      h.boot();
      resume(h, friOpen());
      expect(h.writeLog, isEmpty);
      h.tick(const Duration(seconds: 30));
      expect(h.work.saved.last.date, fri);
      expect(h.writeLog.last, 'A:entry:2026-10-02:22:00--');
      expect(h.writeLog.where((l) => l.contains('2026-10-03')), isEmpty);
    }, setUp: (h) => h.seed(friOpen()), profiles: true);

    scenario(
        'Stop: Saldo = Basis + Tagesanteil, Eintrag am Freitag, Reinit auf heute',
        satMorning, (h) {
      h.boot();
      resume(h, friOpen());
      h.tick(const Duration(minutes: 1)); // 09:01
      h.act(h.vm.startOrStopTimer);

      final saved = h.work.saved.last;
      expect(saved.date, fri);
      expect(saved.workStart, friStart);
      expect(saved.workEnd, DateTime(2026, 10, 3, 9, 1));
      final net = saved.workEnd!.difference(saved.workStart!) -
          saved.breaks.fold<Duration>(
              Duration.zero, (s, b) => s + b.end!.difference(b.start));
      expect(h.overtime.savedOvertimes.last,
          const Duration(hours: 1) + net - eightHours);

      // Reinit auf heute: leerer Samstag, Basis = neuer gespeicherter Saldo.
      expect(h.state.workEntry.date, sat);
      expect(h.state.workEntry.workStart, isNull);
      expect(h.state.initialOvertime, h.overtime.savedOvertimes.last);
      expect(h.vm.isTimerRunning, isFalse);
      expect(h.async.periodicTimerCount, 0);
    }, setUp: (h) {
      h.seed(friOpen());
      h.overtime.stored = const Duration(hours: 1);
    }, profiles: true);

    scenario('Folge reloadAfterRetroClose: nur Saldo-Basis wird erneuert',
        satMorning, (h) {
      h.boot();
      resume(h, friOpen());
      h.overtime.stored = const Duration(minutes: -30);
      h.act(h.vm.reloadAfterRetroClose);
      expect(h.state.workEntry.date, fri);
      expect(h.state.initialOvertime, const Duration(minutes: -30));
      expect(h.vm.isTimerRunning, isTrue);
    }, setUp: (h) => h.seed(friOpen()), profiles: true);
  });

  group('Ablehnung ohne Zustandsänderung', () {
    void expectUntouched(Harness h, Object? before) {
      expect(h.state.workEntry, before);
      expect(h.state.isLoading, isFalse);
      expect(h.async.periodicTimerCount, h.vm.isTimerRunning ? 1 : 0);
      expect(h.writeLog, isEmpty);
    }

    scenario('heute schon gestartet', satMorning, (h) {
      h.boot();
      final before = h.state.workEntry;
      expect(h.state.workEntry.workStart, isNotNull);
      expect(resume(h, friOpen()), isFalse);
      expectUntouched(h, before);
      expect(h.state.workEntry.date, sat);
    }, setUp: (h) {
      h.seed(friOpen());
      h.seed(entryOf(sat, start: DateTime(2026, 10, 3, 8)));
    }, profiles: true);

    scenario('heute Urlaub (type != work) zählt nicht als leer', satMorning,
        (h) {
      h.boot();
      final before = h.state.workEntry;
      expect(before.type, WorkEntryType.vacation);
      expect(resume(h, friOpen()), isFalse);
      expectUntouched(h, before);
    }, setUp: (h) {
      h.seed(friOpen());
      h.work.store[dayKey(sat)] = WorkEntryEntity(
          id: dayKey(sat), date: sat, type: WorkEntryType.vacation);
    }, profiles: true);

    scenario('Eintrag 24 h + 1 min alt', DateTime(2026, 10, 3, 22, 1), (h) {
      h.boot();
      final before = h.state.workEntry;
      expect(resume(h, friOpen()), isFalse);
      expectUntouched(h, before);
    }, setUp: (h) => h.seed(friOpen()), profiles: true);

    scenario('Eintrag genau 24 h alt wird gepinnt', DateTime(2026, 10, 3, 22),
        (h) {
      h.boot();
      expect(resume(h, friOpen()), isTrue);
      expect(h.state.workEntry.date, fri);
    }, setUp: (h) => h.seed(friOpen()), profiles: true);

    scenario('Dashboard nicht erfolgreich geladen', satMorning, (h) {
      h.work.failReads = true;
      h.boot();
      final before = h.state.workEntry;
      final readsBefore = h.work.getWorkEntryCalls;
      expect(resume(h, friOpen()), isFalse);
      expectUntouched(h, before);
      expect(h.work.getWorkEntryCalls, readsBefore);
    }, setUp: (h) => h.seed(friOpen()), profiles: true);

    scenario('Eintrag nicht offen (workEnd gesetzt) laut Aufrufer', satMorning,
        (h) {
      h.boot();
      final before = h.state.workEntry;
      expect(
          resume(
              h, entryOf(fri, start: friStart, end: DateTime(2026, 10, 2, 23))),
          isFalse);
      expectUntouched(h, before);
    }, profiles: true);
  });

  group('Frisch lesen und Fehler', () {
    scenario('anderes Gerät hat beendet: nicht gepinnt, Dashboard zeigt heute',
        satMorning, (h) {
      h.boot();
      // Der Aufrufer kennt den alten (offenen) Stand, das Repo den beendeten.
      final stale = friOpen();
      h.seed(entryOf(fri, start: friStart, end: DateTime(2026, 10, 2, 23)));
      expect(resume(h, stale), isFalse);
      expect(h.state.workEntry.date, sat);
      expect(h.state.workEntry.workStart, isNull);
      expect(h.state.isLoading, isFalse);
      expect(h.vm.isTimerRunning, isFalse);
      expect(h.writeLog, isEmpty);
    }, setUp: (h) => h.seed(friOpen()), profiles: true);

    scenario(
        'Lesefehler beim Pinnen: false, bedienbar, nächste Aktion lädt nach',
        satMorning, (h) {
      h.boot();
      h.work.failReads = true;
      expect(resume(h, friOpen()), isFalse);
      expect(h.state.isLoading, isFalse);
      expect(h.state.workEntry.date, sat);
      expect(h.vm.isTimerRunning, isFalse);
      expect(h.writeLog, isEmpty);

      h.work.failReads = false;
      h.act(h.vm.startOrStopTimer);
      expect(h.state.workEntry.date, sat);
      expect(h.state.workEntry.workStart, isNotNull);
      expect(h.work.saved.last.date, sat);
    }, setUp: (h) => h.seed(friOpen()), profiles: true);
  });

  group('Ladelauf, Profilwechsel, Doppelaufruf', () {
    scenario('wartet auf laufenden Ladelauf, prüft danach', satMorning, (h) {
      h.work.holdReads = true;
      h.boot();
      final results = <bool>[];
      h.act(() async => results.add(await h.vm.resumePastEntry(friOpen())));
      expect(results, isEmpty, reason: 'wartet auf den Ladelauf');

      h.work.holdReads = false;
      for (final c in h.work.pendingReads.toList()) {
        c.complete();
      }
      h.async.flushMicrotasks();
      expect(results, [true]);
      expect(h.state.workEntry.date, fri);
    }, setUp: (h) => h.seed(friOpen()), profiles: true);

    scenario(
        'wartet auf Ladelauf, heute inzwischen nicht mehr leer', satMorning,
        (h) {
      h.work.holdReads = true;
      h.boot();
      final results = <bool>[];
      h.act(() async => results.add(await h.vm.resumePastEntry(friOpen())));
      h.work.holdReads = false;
      for (final c in h.work.pendingReads.toList()) {
        c.complete();
      }
      h.async.flushMicrotasks();
      expect(results, [false]);
      expect(h.state.workEntry.date, sat);
    }, setUp: (h) {
      h.seed(friOpen());
      h.seed(entryOf(sat, start: DateTime(2026, 10, 3, 8)));
    }, profiles: true);

    scenario('Profilwechsel mitten im Pinnen: Ergebnis verworfen', satMorning,
        (h) {
      h.boot();
      h.work.holdReads = true;
      final results = <bool>[];
      h.act(() async => results.add(await h.vm.resumePastEntry(friOpen())));
      expect(h.work.pendingReads, hasLength(1));
      expect(h.state.isLoading, isTrue);

      h.switchProfile('b');
      h.work.holdReads = false;
      for (final c in h.work.pendingReads.toList()) {
        c.complete();
      }
      h.async.flushMicrotasks();

      expect(results, [false]);
      expect(h.state.workEntry.date, sat, reason: 'Profil B, leerer Tag');
      expect(h.state.workEntry.workStart, isNull);
      expect(h.vm.isTimerRunning, isFalse);
      expect(h.async.periodicTimerCount, 0);
      expect(h.writeLog, isEmpty);
    }, setUp: (h) => h.seed(friOpen()), profiles: true);

    scenario('doppelter Aufruf: zweiter liefert false, ein Timer', satMorning,
        (h) {
      h.boot();
      final results = <bool>[];
      resume(h, friOpen(), results: results);
      resume(h, friOpen(), results: results);
      expect(results, [true, false]);
      expect(h.async.periodicTimerCount, 1);
      expect(h.state.workEntry.date, fri);
    }, setUp: (h) => h.seed(friOpen()), profiles: true);

    scenario(
        'gleichzeitiger Doppelaufruf ohne Zwischenschritt: ein Pin, ein Timer',
        satMorning, (h) {
      h.boot();
      final results = <bool>[];
      h.act(() async {
        final a = h.vm.resumePastEntry(friOpen());
        final b = h.vm.resumePastEntry(friOpen());
        results.addAll([await a, await b]);
      });
      expect(results.where((r) => r).length, 1);
      expect(h.async.periodicTimerCount, 1);
    }, setUp: (h) => h.seed(friOpen()), profiles: true);
  });

  group('Fortsetzen und Reentranz-Sperre (#413)', () {
    void releaseReads(Harness h) {
      h.work.holdReads = false;
      for (final c in h.work.pendingReads.toList()) {
        if (!c.isCompleted) c.complete();
      }
      h.async.flushMicrotasks();
    }

    scenario('B13a laeuft ein Start-Tap in der Ladeluecke: false ohne Pin-Read',
        satMorning, (h) {
      h.work.holdReads = true;
      h.boot();
      h.act(h.vm.startOrStopTimer);
      expect(h.state.isSaving, isTrue);
      final readsBefore = h.work.pendingReads.length;

      bool? out;
      h.act(() async => out = await h.vm.resumePastEntry(friOpen()));
      expect(out, isFalse, reason: 'sofort, vor der Freigabe der Reads');
      expect(h.work.pendingReads, hasLength(readsBefore));

      releaseReads(h);
      expect(h.state.workEntry.date, sat);
      expect(h.state.workEntry.workStart, isNotNull);
      expect(h.work.saved.where((e) => e.date == fri), isEmpty);
    }, setUp: (h) => h.seed(friOpen()), profiles: true);

    scenario('B13b Start-Tap im Wartefenster von resumePastEntry: false, kein Pin',
        satMorning, (h) {
      h.work.holdReads = true;
      h.boot();
      bool? out;
      h.act(() async => out = await h.vm.resumePastEntry(friOpen()));
      expect(out, isNull, reason: 'wartet auf den Ladelauf');
      h.act(h.vm.startOrStopTimer);

      releaseReads(h);
      expect(out, isFalse);
      expect(h.state.workEntry.date, sat);
      expect(h.state.workEntry.workStart, isNotNull);
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.work.saved, hasLength(1));
      expect(h.work.saved.single.date, sat);
      expect(h.async.periodicTimerCount, 1);
    }, setUp: (h) => h.seed(friOpen()), profiles: true);
  });

  group('Start/Stop-Tap während des Pinnens', () {
    // Befund (Plan Schritt 2): `dashboard_screen.dart` sperrt Start/Stop NICHT
    // über `state.isLoading` (kein Treffer im Screen). `isLoading` während des
    // Pinnens schützt daher nur Konsumenten, die es auswerten. Ein Tap in der
    // Ladelücke wartet in `_ensureCurrentDay` auf den Pin-Lauf, sieht dann einen
    // laufenden Vortag und stoppt ihn über den normalen Stop-Pfad. Dieses
    // Verhalten wird hier festgeschrieben (Fenster = eine Repo-Leseoperation).
    scenario('Tap in der Ladelücke wartet auf den Pin und stoppt dann den Lauf',
        satMorning, (h) {
      h.boot();
      h.work.holdReads = true;
      h.act(() async {
        await h.vm.resumePastEntry(friOpen());
      });
      expect(h.state.isLoading, isTrue);
      h.act(h.vm.startOrStopTimer);
      expect(h.work.saved, isEmpty, reason: 'Tap wartet auf den Ladelauf');

      h.work.holdReads = false;
      for (final c in h.work.pendingReads.toList()) {
        c.complete();
      }
      h.async.flushMicrotasks();
      expect(h.work.saved.last.date, fri);
      expect(h.work.saved.last.workEnd, isNotNull,
          reason: 'dokumentiertes Verhalten: der gepinnte Lauf wird gestoppt');
    }, setUp: (h) => h.seed(friOpen()), profiles: true);
  });
}
