import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/usecases/get_open_past_work_entries.dart';

import '../../support/fake_repositories.dart';

// Feste Daten: Fr 2026-10-02, Sa 2026-10-03, So 2026-10-04.
WorkEntryEntity open(DateTime day,
        {int startHour = 22,
        DateTime? end,
        WorkEntryType type = WorkEntryType.work,
        bool noStart = false}) =>
    WorkEntryEntity(
      id: dayKey(day),
      date: day,
      workStart:
          noStart ? null : DateTime(day.year, day.month, day.day, startHour),
      workEnd: end,
      type: type,
    );

void main() {
  late FakeWorkRepository repo;
  late DateTime now;

  GetOpenPastWorkEntries build() =>
      GetOpenPastWorkEntries(repo, clock: () => now);

  setUp(() {
    repo = FakeWorkRepository();
    now = DateTime(2026, 10, 3, 9);
  });

  void seed(WorkEntryEntity e) => repo.store[dayKey(e.date)] = e;

  test('offener Vortag (Fr 22:00, jetzt Sa 09:00) wird gefunden', () async {
    seed(open(DateTime(2026, 10, 2)));
    final result = await build()();
    expect(result, hasLength(1));
    expect(result.single.date, DateTime(2026, 10, 2));
  });

  test('heutiger offener Eintrag ist kein Treffer', () async {
    seed(open(DateTime(2026, 10, 3), startHour: 8));
    expect(await build()(), isEmpty);
  });

  test('Eintrag mit zukünftigem Datum (Uhrsprung) ist kein Treffer', () async {
    seed(open(DateTime(2026, 10, 4)));
    seed(open(DateTime(2026, 10, 20)));
    expect(await build()(), isEmpty);
  });

  test('abgeschlossener Eintrag ist kein Treffer', () async {
    seed(open(DateTime(2026, 10, 2), end: DateTime(2026, 10, 2, 23)));
    expect(await build()(), isEmpty);
  });

  test('Eintrag ohne Start ist kein Treffer', () async {
    seed(open(DateTime(2026, 10, 2), noStart: true));
    expect(await build()(), isEmpty);
  });

  test('Urlaub/Krank/Feiertag ohne Ende ist kein Treffer', () async {
    seed(open(DateTime(2026, 10, 1), type: WorkEntryType.vacation));
    seed(open(DateTime(2026, 10, 2), type: WorkEntryType.sick));
    seed(open(DateTime(2026, 9, 30), type: WorkEntryType.holiday));
    expect(await build()(), isEmpty);
  });

  test('Monatsgrenze: jetzt 01.11., offen 31.10. wird gefunden', () async {
    now = DateTime(2026, 11, 1, 8);
    seed(open(DateTime(2026, 10, 31)));
    final result = await build()();
    expect(result.map((e) => e.date), [DateTime(2026, 10, 31)]);
    expect(repo.monthReads, containsAll(['2026-11', '2026-10']));
  });

  test('Jahreswechsel: jetzt 05.01. liest Dezember des Vorjahres', () async {
    now = DateTime(2026, 1, 5, 8);
    seed(open(DateTime(2025, 12, 31)));
    final result = await build()();
    expect(result.map((e) => e.date), [DateTime(2025, 12, 31)]);
    expect(repo.monthReads, ['2026-01', '2025-12']);
  });

  test('Vor-Vormonat wird weder gelesen noch gefunden', () async {
    now = DateTime(2026, 11, 3, 8);
    seed(open(DateTime(2026, 9, 15)));
    expect(await build()(), isEmpty);
    expect(repo.monthReads.toSet(), {'2026-11', '2026-10'});
  });

  test('mehrere Treffer: neuester zuerst, auch bei unsortierter Antwort',
      () async {
    now = DateTime(2026, 11, 2, 8);
    seed(open(DateTime(2026, 10, 5)));
    seed(open(DateTime(2026, 11, 1)));
    seed(open(DateTime(2026, 10, 30)));
    seed(open(DateTime(2026, 10, 12)));
    final result = await build()();
    expect(result.map((e) => e.date), [
      DateTime(2026, 11, 1),
      DateTime(2026, 10, 30),
      DateTime(2026, 10, 12),
      DateTime(2026, 10, 5),
    ]);
  });

  test('Kalendertag-Vergleich: Eintrag mit Uhrzeit im Datum, heute 00:30/23:30',
      () async {
    // Datum mit Uhrzeitanteil kurz vor Mitternacht zählt als Vortag.
    seed(WorkEntryEntity(
      id: 'x',
      date: DateTime(2026, 10, 2, 23, 59),
      workStart: DateTime(2026, 10, 2, 23, 0),
    ));
    for (final t in [
      DateTime(2026, 10, 3, 0, 30),
      DateTime(2026, 10, 3, 23, 30),
    ]) {
      now = t;
      expect(await build()(), hasLength(1), reason: '$t');
    }
    // Derselbe Kalendertag zählt nie als "vor heute", egal wie spät/früh.
    repo.store.clear();
    seed(WorkEntryEntity(
      id: 'y',
      date: DateTime(2026, 10, 3, 0, 5),
      workStart: DateTime(2026, 10, 3, 0, 5),
    ));
    for (final t in [
      DateTime(2026, 10, 3, 0, 30),
      DateTime(2026, 10, 3, 23, 30),
    ]) {
      now = t;
      expect(await build()(), isEmpty, reason: '$t');
    }
  });

  test('Lesefehler eines Monats: anderer Monat liefert weiter Treffer',
      () async {
    now = DateTime(2026, 11, 2, 8);
    seed(open(DateTime(2026, 10, 30)));
    repo.failMonths.add('2026-11');
    expect((await build()()).map((e) => e.date), [DateTime(2026, 10, 30)]);

    repo.failMonths
      ..clear()
      ..add('2026-10');
    seed(open(DateTime(2026, 11, 1)));
    expect((await build()()).map((e) => e.date), [DateTime(2026, 11, 1)]);
  });

  test('beide Monate fehlerhaft: leere Liste, kein Crash', () async {
    seed(open(DateTime(2026, 10, 2)));
    repo.failReads = true;
    expect(await build()(), isEmpty);
  });

  test('excludeDate (laufender Dashboard-Eintrag) wird nicht zurückgegeben',
      () async {
    seed(open(DateTime(2026, 10, 2)));
    seed(open(DateTime(2026, 10, 1)));
    final result = await build()(excludeDate: DateTime(2026, 10, 2, 13));
    expect(result.map((e) => e.date), [DateTime(2026, 10, 1)]);
  });

  test('Pausen/Felder des Eintrags bleiben unverändert erhalten', () async {
    final e = open(DateTime(2026, 10, 2)).copyWith(breaks: [
      BreakEntity(
          id: 'b', name: 'P', start: DateTime(2026, 10, 2, 23), end: null),
    ]);
    seed(e);
    expect((await build()()).single, e);
  });
}
