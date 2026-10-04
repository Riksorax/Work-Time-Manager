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

    test('Entry-Save schlägt nach Saldo fehl: failed (Rest-Risiko Teilfehler)',
        () async {
      final e = openEntry(friday);
      seed(e);
      work.failSaves = true;
      final result = await build()(
          entry: e, end: DateTime(2026, 10, 2, 16), dailyTarget: eight);
      expect(result, CloseOpenEntryResult.failed);
      expect(overtime.savedOvertimes, hasLength(1));
      expect(work.saved, isEmpty);
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
