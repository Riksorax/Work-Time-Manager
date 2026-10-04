import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/services/break_calculator_service.dart';
import 'package:flutter_work_time/domain/usecases/close_open_work_entry.dart';

import '../../support/fake_repositories.dart';

const eight = Duration(hours: 8);

// Fr 2026-10-02 (Soll 8 h), Sa 2026-10-03 (Soll 0).
final friday = DateTime(2026, 10, 2);
final saturday = DateTime(2026, 10, 3);

WorkEntryEntity openEntry(DateTime day,
        {int startHour = 8,
        List<BreakEntity> breaks = const [],
        WorkEntryType type = WorkEntryType.work,
        bool noStart = false}) =>
    WorkEntryEntity(
      id: dayKey(day),
      date: day,
      workStart:
          noStart ? null : DateTime(day.year, day.month, day.day, startHour),
      breaks: breaks,
      type: type,
    );

List<List<Object?>> shape(List<BreakEntity> breaks) => breaks
    .map((b) => [b.name, b.start, b.end, b.isAutomatic])
    .toList(growable: false);

void main() {
  late List<String> log;
  late FakeWorkRepository work;
  late FakeOvertimeRepository overtime;
  late DateTime now;

  CloseOpenWorkEntry build() =>
      CloseOpenWorkEntry(work, overtime, clock: () => now);

  void seed(WorkEntryEntity e) => work.store[dayKey(e.date)] = e;

  setUp(() {
    log = [];
    work = FakeWorkRepository(label: 'A', writeLog: log);
    overtime = FakeOvertimeRepository(label: 'A', writeLog: log);
    now = DateTime(2026, 10, 3, 9); // Sa 09:00
  });

  test('setzt Ende (auf Minute abgeschnitten) und speichert den Eintrag',
      () async {
    final e = openEntry(friday);
    seed(e);
    final result = await build()(
        entry: e, end: DateTime(2026, 10, 2, 16, 0, 40), dailyTarget: eight);
    expect(result, CloseOpenEntryResult.closed);
    expect(work.saved.single.workEnd, DateTime(2026, 10, 2, 16, 0));
    expect(work.saved.single.workStart, e.workStart);
  });

  test('offene Pause endet zum gewählten Ende, geschlossene bleiben', () async {
    final closed = BreakEntity(
        id: 'c',
        name: 'Mittag',
        start: DateTime(2026, 10, 2, 12),
        end: DateTime(2026, 10, 2, 12, 20));
    final running = BreakEntity(
        id: 'r', name: 'Kaffee', start: DateTime(2026, 10, 2, 15), end: null);
    final e = openEntry(friday, breaks: [closed, running]);
    seed(e);
    final end = DateTime(2026, 10, 2, 16);
    final result = await build()(entry: e, end: end, dailyTarget: eight);
    expect(result, CloseOpenEntryResult.closed);
    final breaks = work.saved.single.breaks;
    expect(breaks.firstWhere((b) => b.id == 'c'), closed);
    expect(breaks.firstWhere((b) => b.id == 'r').end, end);
    expect(breaks.every((b) => b.end != null), isTrue);
  });

  test('Auto-Pausen wie im Stop-Pfad (10 h brutto ohne Pause)', () async {
    final e = openEntry(friday);
    seed(e);
    final end = DateTime(2026, 10, 2, 18);
    await build()(entry: e, end: end, dailyTarget: eight);
    final expected =
        BreakCalculatorService.calculateAndApplyBreaks(e.copyWith(workEnd: end))
            .breaks;
    expect(expected, isNotEmpty);
    expect(shape(work.saved.single.breaks), shape(expected));
    expect(work.saved.single.breaks.every((b) => b.isAutomatic), isTrue);
  });

  test('kein Auto-Break bei kurzem Eintrag', () async {
    final e = openEntry(friday);
    seed(e);
    await build()(entry: e, end: DateTime(2026, 10, 2, 11), dailyTarget: eight);
    expect(work.saved.single.breaks, isEmpty);
  });

  test('Saldo: alt + (Netto nach Auto-Pausen - Soll am Eintragsdatum)',
      () async {
    overtime.stored = const Duration(hours: 2);
    final e = openEntry(friday);
    seed(e);
    // 10 h brutto, 45 min Auto-Pause -> 9:15 netto, Soll 8:00 -> +1:15
    await build()(entry: e, end: DateTime(2026, 10, 2, 18), dailyTarget: eight);
    expect(overtime.savedOvertimes.single,
        const Duration(hours: 2) + const Duration(hours: 1, minutes: 15));
  });

  test('Saldo am Zusatztag (Soll 0): volle Netto-Dauer, Pause abgezogen',
      () async {
    overtime.stored = const Duration(minutes: 30);
    final e = openEntry(saturday, startHour: 8, breaks: [
      BreakEntity(
          id: 'c',
          name: 'P',
          start: DateTime(2026, 10, 3, 10),
          end: DateTime(2026, 10, 3, 10, 30)),
    ]);
    seed(e);
    await build()(
        entry: e, end: DateTime(2026, 10, 3, 9, 0), dailyTarget: Duration.zero);
    // Ende 09:00 < Pausenstart 10:00 -> ungültig, nichts geschrieben
    expect(overtime.savedOvertimes, isEmpty);

    now = DateTime(2026, 10, 3, 13);
    await build()(
        entry: e, end: DateTime(2026, 10, 3, 12), dailyTarget: Duration.zero);
    // 4 h brutto - 30 min = 3:30
    expect(overtime.savedOvertimes.single, const Duration(hours: 4));
  });

  test('Soll des Eintragsdatums, nicht des heutigen Tages', () async {
    // Heute Sa (Soll 0 wäre falsch); Eintrag Fr, dailyTarget 8 h
    final e = openEntry(friday);
    seed(e);
    await build()(entry: e, end: DateTime(2026, 10, 2, 12), dailyTarget: eight);
    // 4 h Netto - 8 h = -4 h
    expect(overtime.savedOvertimes.single, const Duration(hours: -4));
  });

  test('setzt lastUpdated nie', () async {
    overtime.lastUpdate = DateTime(2026, 9, 1);
    final e = openEntry(friday);
    seed(e);
    await build()(entry: e, end: DateTime(2026, 10, 2, 16), dailyTarget: eight);
    expect(log.where((l) => l.contains('lastUpdate')), isEmpty);
    expect(overtime.getLastUpdateDate(), DateTime(2026, 9, 1));
  });

  test('übergibt keepLastUpdated: true an das Speichern des Saldos (#406)',
      () async {
    final e = openEntry(friday);
    seed(e);
    await build()(entry: e, end: DateTime(2026, 10, 2, 16), dailyTarget: eight);
    expect(overtime.savedKeepLastUpdated, [true]);
  });

  test('Backend-Simulation: lastUpdated bleibt beim Beenden unverändert (#406)',
      () async {
    final backend = FakeOvertimeRepository(
        label: 'A',
        writeLog: log,
        serverNow: () => DateTime(2026, 10, 3, 9)) // Sa 09:00
      ..lastUpdate = DateTime(2026, 9, 1);
    final e = openEntry(friday);
    seed(e);
    final result = await CloseOpenWorkEntry(work, backend, clock: () => now)(
        entry: e, end: DateTime(2026, 10, 2, 16), dailyTarget: eight);
    expect(result, CloseOpenEntryResult.closed);
    expect(backend.lastUpdate, DateTime(2026, 9, 1));
    expect(log, isNot(contains('A:lastUpdate')));
  });

  test('Reihenfolge: Saldo vor Eintrag', () async {
    final e = openEntry(friday);
    seed(e);
    await build()(entry: e, end: DateTime(2026, 10, 2, 13), dailyTarget: eight);
    expect(log, ['A:overtime:-180', 'A:entry:2026-10-02:08:00-13:00']);
  });

  group('Validierung ohne Writes', () {
    Future<void> expectInvalid(WorkEntryEntity e, DateTime end) async {
      seed(e);
      final result = await build()(entry: e, end: end, dailyTarget: eight);
      expect(result, CloseOpenEntryResult.invalidEnd);
      expect(log, isEmpty);
    }

    test('Ende gleich Start', () async {
      await expectInvalid(openEntry(friday), DateTime(2026, 10, 2, 8));
    });

    test('Ende vor Start', () async {
      await expectInvalid(openEntry(friday), DateTime(2026, 10, 2, 7));
    });

    test('Ende nach jetzt', () async {
      await expectInvalid(openEntry(friday), DateTime(2026, 10, 3, 9, 1));
    });

    test('Ende vor dem Start der letzten Pause', () async {
      final e = openEntry(friday, breaks: [
        BreakEntity(
            id: 'c',
            name: 'P',
            start: DateTime(2026, 10, 2, 12),
            end: DateTime(2026, 10, 2, 12, 30)),
      ]);
      await expectInvalid(e, DateTime(2026, 10, 2, 11));
    });

    test('Ende innerhalb einer geschlossenen Pause', () async {
      final e = openEntry(friday, breaks: [
        BreakEntity(
            id: 'c',
            name: 'P',
            start: DateTime(2026, 10, 2, 12),
            end: DateTime(2026, 10, 2, 12, 30)),
      ]);
      await expectInvalid(e, DateTime(2026, 10, 2, 12, 29));
    });
  });

  test('Soft-Warnung > 16 h blockiert nicht', () async {
    now = DateTime(2026, 10, 5, 9);
    final e = openEntry(friday);
    seed(e);
    final result = await build()(
        entry: e, end: DateTime(2026, 10, 3, 8), dailyTarget: eight);
    expect(result, CloseOpenEntryResult.closed);
  });

  group('frisch lesen', () {
    test('bereits beendet im Repo -> alreadyClosed, keine Writes', () async {
      final stale = openEntry(friday);
      seed(stale.copyWith(workEnd: DateTime(2026, 10, 2, 17)));
      final result = await build()(
          entry: stale, end: DateTime(2026, 10, 2, 16), dailyTarget: eight);
      expect(result, CloseOpenEntryResult.alreadyClosed);
      expect(log, isEmpty);
      expect(overtime.saveOvertimeCalls, 0);
    });

    test('Eintrag im Repo nicht mehr vorhanden -> alreadyClosed', () async {
      final result = await build()(
          entry: openEntry(friday),
          end: DateTime(2026, 10, 2, 16),
          dailyTarget: eight);
      expect(result, CloseOpenEntryResult.alreadyClosed);
      expect(log, isEmpty);
    });

    test('zweiter Aufruf nach Erfolg zählt den Saldo nicht doppelt', () async {
      final e = openEntry(friday);
      seed(e);
      final uc = build();
      expect(
          await uc(
              entry: e, end: DateTime(2026, 10, 2, 18), dailyTarget: eight),
          CloseOpenEntryResult.closed);
      expect(
          await uc(
              entry: e, end: DateTime(2026, 10, 2, 18), dailyTarget: eight),
          CloseOpenEntryResult.alreadyClosed);
      expect(overtime.savedOvertimes, hasLength(1));
      expect(work.saved, hasLength(1));
    });

    test('Pausen aus dem frischen Stand werden verwendet', () async {
      final stale = openEntry(friday);
      final fresh = stale.copyWith(breaks: [
        BreakEntity(
            id: 'c',
            name: 'P',
            start: DateTime(2026, 10, 2, 12),
            end: DateTime(2026, 10, 2, 12, 30)),
      ]);
      seed(fresh);
      await build()(
          entry: stale, end: DateTime(2026, 10, 2, 16), dailyTarget: eight);
      expect(work.saved.single.breaks.single.id, 'c');
      // 8 h brutto - 30 min = 7:30 -> -30 min
      expect(overtime.savedOvertimes.single, const Duration(minutes: -30));
    });
  });

  test('übernimmt Felder des frischen Stands (z. B. Beschreibung)', () async {
    final stale = openEntry(friday);
    seed(stale.copyWith(description: 'am anderen Gerät ergänzt'));
    await build()(
        entry: stale, end: DateTime(2026, 10, 2, 16), dailyTarget: eight);
    expect(work.saved.single.description, 'am anderen Gerät ergänzt');
  });

  test('ungültiges Ende liest nichts und schreibt nichts', () async {
    final e = openEntry(friday);
    seed(e);
    final result = await build()(
        entry: e, end: DateTime(2026, 10, 2, 7), dailyTarget: eight);
    expect(result, CloseOpenEntryResult.invalidEnd);
    expect(work.monthReads, isEmpty);
    expect(log, isEmpty);
  });

  test('Fehlerlog enthält keine Eintragsinhalte (#385)', () async {
    const secret = 'GEHEIM-Notiz';
    final e = openEntry(friday).copyWith(description: secret);
    seed(e);
    overtime.failSaveOvertime = true;
    final logged = <String>[];
    void listener(LogEvent event) => logged.add(
        '${event.message} ${event.error} ${event.stackTrace}'.toLowerCase());
    Logger.addLogListener(listener);
    addTearDown(() => Logger.removeLogListener(listener));
    final result = await build()(
        entry: e, end: DateTime(2026, 10, 2, 16), dailyTarget: eight);
    expect(result, CloseOpenEntryResult.failed);
    expect(logged, isNotEmpty);
    expect(logged.join(), isNot(contains(secret.toLowerCase())));
    expect(logged.join(), isNot(contains('2026-10-02')));
  });

  group('Fehlerpfade', () {
    test('Saldo-Write schlägt fehl: Eintrag bleibt offen, failed', () async {
      final e = openEntry(friday);
      seed(e);
      overtime.failSaveOvertime = true;
      final result = await build()(
          entry: e, end: DateTime(2026, 10, 2, 16), dailyTarget: eight);
      expect(result, CloseOpenEntryResult.failed);
      expect(work.saved, isEmpty);
      expect(work.store[dayKey(friday)]!.workEnd, isNull);
    });

    test('Saldo-Write schlägt fehl: kein Rollback-Versuch, kein Eintrag-Write',
        () async {
      // U5: ohne erfolgreichen Vorwärts-Write gibt es nichts zurückzurollen.
      final e = openEntry(friday);
      seed(e);
      overtime.failSaveOvertime = true;
      final result = await build()(
          entry: e, end: DateTime(2026, 10, 2, 16), dailyTarget: eight);
      expect(result, CloseOpenEntryResult.failed);
      expect(overtime.saveOvertimeCalls, 1);
      expect(work.saved, isEmpty);
    });

    test(
        'Entry-Save schlägt nach Saldo fehl: Saldo wird zurückgeschrieben, '
        'failed, Eintrag bleibt offen', () async {
      // U1 (ersetzt den Test "Rest-Risiko Teilfehler", #410).
      overtime.stored = const Duration(hours: 2);
      final e = openEntry(friday);
      seed(e);
      work.failSaves = true;
      final result = await build()(
          entry: e, end: DateTime(2026, 10, 2, 16), dailyTarget: eight);
      expect(result, CloseOpenEntryResult.failed);
      // 8 h brutto - 30 min Auto-Pause - 8 h Soll = -30 min
      expect(overtime.savedOvertimes, [
        const Duration(hours: 2) - const Duration(minutes: 30),
        const Duration(hours: 2),
      ]);
      expect(overtime.savedKeepLastUpdated, [true, true]);
      expect(overtime.stored, const Duration(hours: 2));
      expect(work.saved, isEmpty);
      expect(work.store[dayKey(friday)]!.workEnd, isNull);
    });

    test('Rollback-Wert ist der gelesene Saldo, nicht der Vorwärtswert',
        () async {
      // U7: Fake mit krummem Saldo, Delta weicht deutlich davon ab.
      overtime.stored = const Duration(minutes: 37);
      final e = openEntry(friday);
      seed(e);
      work.failSaves = true;
      await build()(
          entry: e, end: DateTime(2026, 10, 2, 12), dailyTarget: eight);
      expect(overtime.savedOvertimes.first, const Duration(minutes: 37 - 240));
      expect(overtime.savedOvertimes.last, const Duration(minutes: 37));
    });

    test('Rollback-Wert kommt aus ensureOvertimeLoaded, nicht aus getOvertime',
        () async {
      // Das Firebase-Repo setzt seinen Cache vor dem Netzwerk-Write; ein
      // veralteter synchroner `getOvertime()` darf nie Rollback-Wert werden.
      final stale = _StaleGetOvertime(const Duration(hours: 99))
        ..stored = const Duration(hours: 2);
      final e = openEntry(friday);
      seed(e);
      work.failSaves = true;
      await CloseOpenWorkEntry(work, stale, clock: () => now)(
          entry: e, end: DateTime(2026, 10, 2, 16), dailyTarget: eight);
      expect(stale.savedOvertimes.last, const Duration(hours: 2));
    });

    test('Rollback lässt lastUpdated unverändert (Backend-Simulation)',
        () async {
      // U2
      final backend = FakeOvertimeRepository(
          label: 'A', writeLog: log, serverNow: () => DateTime(2026, 10, 3, 9))
        ..lastUpdate = DateTime(2026, 9, 1);
      final e = openEntry(friday);
      seed(e);
      work.failSaves = true;
      final result = await CloseOpenWorkEntry(work, backend, clock: () => now)(
          entry: e, end: DateTime(2026, 10, 2, 16), dailyTarget: eight);
      expect(result, CloseOpenEntryResult.failed);
      expect(backend.savedOvertimes, hasLength(2));
      expect(backend.lastUpdate, DateTime(2026, 9, 1));
      expect(log, isNot(contains('A:lastUpdate')));
    });

    test('Wiederholen nach gelungenem Rollback zählt das Delta einmal',
        () async {
      // U3
      overtime.stored = const Duration(hours: 2);
      final e = openEntry(friday);
      seed(e);
      final uc = build();
      work.failSaves = true;
      expect(
          await uc(
              entry: e, end: DateTime(2026, 10, 2, 16), dailyTarget: eight),
          CloseOpenEntryResult.failed);
      work.failSaves = false;
      expect(
          await uc(
              entry: e, end: DateTime(2026, 10, 2, 16), dailyTarget: eight),
          CloseOpenEntryResult.closed);
      expect(overtime.stored, const Duration(minutes: 90));
      expect(work.store[dayKey(friday)]!.workEnd, DateTime(2026, 10, 2, 16));
      expect(log, [
        'A:overtime:90',
        'A:overtime:120',
        'A:overtime:90',
        'A:entry:2026-10-02:08:00-16:00',
      ]);
    });

    test('Rollback scheitert: kein Wurf, failed, Fehler ohne Inhalte geloggt',
        () async {
      // U4
      const secret = 'GEHEIM-Notiz';
      overtime.stored = const Duration(hours: 2);
      final e = openEntry(friday).copyWith(description: secret);
      seed(e);
      work.failSaves = true;
      overtime.failSaveOvertimeCalls.add(2);
      final logged = <String>[];
      final messages = <String>[];
      void listener(LogEvent event) {
        messages.add('${event.message}');
        logged.add('${event.message} ${event.error} ${event.stackTrace}'
            .toLowerCase());
      }

      Logger.addLogListener(listener);
      addTearDown(() => Logger.removeLogListener(listener));
      final result = await build()(
          entry: e, end: DateTime(2026, 10, 2, 16), dailyTarget: eight);
      expect(result, CloseOpenEntryResult.failed);
      expect(overtime.saveOvertimeCalls, 2);
      // Bekannte Grenze: Saldo bleibt verschoben.
      expect(overtime.stored, const Duration(minutes: 90));
      expect(messages.where((m) => m.contains('Saldo-Rollback fehlgeschlagen')),
          hasLength(1));
      expect(logged.join(), contains('_exception'));
      expect(logged.join(), isNot(contains(secret.toLowerCase())));
      expect(logged.join(), isNot(contains('2026-10-02')));
    });

    test('Lesefehler beim frischen Lesen: failed ohne Writes', () async {
      final e = openEntry(friday);
      seed(e);
      work.failReads = true;
      final result = await build()(
          entry: e, end: DateTime(2026, 10, 2, 16), dailyTarget: eight);
      expect(result, CloseOpenEntryResult.failed);
      expect(log, isEmpty);
    });

    test('Saldo kann nicht gelesen werden (offline): failed ohne Writes',
        () async {
      final e = openEntry(friday);
      seed(e);
      overtime.failReads = true;
      final result = await build()(
          entry: e, end: DateTime(2026, 10, 2, 16), dailyTarget: eight);
      expect(result, CloseOpenEntryResult.failed);
      expect(log, isEmpty);
    });
  });

  group('invalidEntry', () {
    test('Typ != work', () async {
      final e = openEntry(friday, type: WorkEntryType.vacation);
      seed(e);
      final result = await build()(
          entry: e, end: DateTime(2026, 10, 2, 16), dailyTarget: eight);
      expect(result, CloseOpenEntryResult.invalidEntry);
      expect(log, isEmpty);
    });

    test('workStart == null', () async {
      final e = openEntry(friday, noStart: true);
      seed(e);
      final result = await build()(
          entry: e, end: DateTime(2026, 10, 2, 16), dailyTarget: eight);
      expect(result, CloseOpenEntryResult.invalidEntry);
      expect(log, isEmpty);
    });
  });

  test('Profil-Kapselung: Writes landen nur in den Repos des Konstruktors',
      () async {
    final workB = FakeWorkRepository(label: 'B', writeLog: log);
    final overtimeB = FakeOvertimeRepository(label: 'B', writeLog: log);
    final e = openEntry(friday);
    seed(e);
    workB.store[dayKey(friday)] = e;
    final uc = build();
    // "Profilwechsel": B existiert, der Use Case bleibt an A gebunden.
    await uc(entry: e, end: DateTime(2026, 10, 2, 16), dailyTarget: eight);
    expect(log, isNotEmpty);
    expect(log.every((l) => l.startsWith('A:')), isTrue);
    expect(workB.saved, isEmpty);
    expect(overtimeB.savedOvertimes, isEmpty);
    expect(workB.store[dayKey(friday)]!.workEnd, isNull);
  });
}

/// `getOvertime()` liefert einen veralteten Wert, `ensureOvertimeLoaded()` den
/// gespeicherten (Firebase-Cache nach gescheitertem Write, #410).
class _StaleGetOvertime extends FakeOvertimeRepository {
  _StaleGetOvertime(this.staleValue);
  final Duration staleValue;

  @override
  Duration getOvertime() => staleValue;
}
