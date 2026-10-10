import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/data/models/work_entry_model.dart';

import '../../support/timezone_guard.dart';

/// Regression #418 fuer die Firestore-Lesegrenze (`WorkEntryModel.fromMap`):
/// `toMap` schreibt `date` als UTC-Mitternacht des lokalen Kalendertags,
/// `fromMap` muss daraus wieder dieselbe lokale Mitternacht machen (nicht den
/// UTC-Zeitpunkt, der westlich von UTC auf dem Vortag liegt).
///
/// Zonenabhaengig fehlschlagend nur vor dem Fix; die Assertions selbst gelten in
/// jeder Zone. Lokal: `TZ=America/Los_Angeles flutter test <datei>`.
void main() {
  registerTimezoneCanary();

  Map<String, dynamic> mapFor(DateTime utcMidnight) => {
        'date': Timestamp.fromDate(utcMidnight),
        'type': 'work',
      };

  group('fromMap', () {
    test('UTC-Mitternacht ist der Kalendertag (Montag), lokal, ohne Zeitanteil',
        () {
      final m = WorkEntryModel.fromMap(mapFor(DateTime.utc(2026, 10, 5)));
      expect(m.date, DateTime(2026, 10, 5));
      expect(m.date.weekday, DateTime.monday);
      expect(m.date.isUtc, isFalse);
      expect(m.date.hour, 0);
    });

    test('Monatserster und Jahresgrenze', () {
      expect(WorkEntryModel.fromMap(mapFor(DateTime.utc(2026, 11, 1))).date,
          DateTime(2026, 11, 1));
      expect(WorkEntryModel.fromMap(mapFor(DateTime.utc(2026, 1, 1))).date,
          DateTime(2026, 1, 1));
    });
  });

  // `fromDayMap` ist die Lesegrenze der Firestore-Datasource: der Tages-Key des
  // Monatsdokuments (`days["5"]`) gewinnt immer gegen das gespeicherte `date`.
  group('fromDayMap: Tages-Key gewinnt', () {
    test('id und date kommen aus dem Tag, nicht aus dem Timestamp', () {
      // Altdaten: lokale Mitternacht Berlin (04.10. 22:00Z) unter Key 5.
      final m = WorkEntryModel.fromDayMap(
          mapFor(DateTime.utc(2026, 10, 4, 22)), DateTime(2026, 10, 5));
      expect(m.id, '2026-10-05');
      expect(m.date, DateTime(2026, 10, 5));
      expect(m.date.isUtc, isFalse);
    });

    test('abweichender UTC-Tag im Timestamp aendert den Tag nicht', () {
      final m = WorkEntryModel.fromDayMap(
          mapFor(DateTime.utc(2026, 10, 4)), DateTime(2026, 10, 5));
      expect(m.id, '2026-10-05');
      expect(m.date, DateTime(2026, 10, 5));
    });

    test('ein Zeitanteil im uebergebenen Tag wird verworfen', () {
      final m = WorkEntryModel.fromDayMap(
          mapFor(DateTime.utc(2026, 10, 5)), DateTime(2026, 10, 5, 13, 30));
      expect(m.id, '2026-10-05');
      expect(m.date, DateTime(2026, 10, 5));
    });

    test('uebrige Felder kommen unveraendert aus der Map', () {
      final m = WorkEntryModel.fromDayMap({
        ...mapFor(DateTime.utc(2026, 11, 1)),
        'type': 'vacation',
        'description': 'Urlaub',
      }, DateTime(2026, 11, 1));
      expect(m.type.name, 'vacation');
      expect(m.description, 'Urlaub');
      expect(m.date, DateTime(2026, 11, 1));
    });
  });

  group('E5 Round-Trip toMap/fromMap (Firestore-Pfad)', () {
    final days = <String, DateTime>{
      'Montag 05.10.': DateTime(2026, 10, 5),
      'Monatserster 01.11.': DateTime(2026, 11, 1),
      'Jahresgrenze 01.01.': DateTime(2026, 1, 1),
      'Sommer 15.07.': DateTime(2026, 7, 15),
      'Winter 15.01.': DateTime(2026, 1, 15),
      'Winterzeit-Wechsel 25.10.': DateTime(2026, 10, 25),
      'Sommerzeit-Wechsel 29.03.': DateTime(2026, 3, 29),
    };
    for (final c in days.entries) {
      test('${c.key}: dieselbe lokale Mitternacht', () {
        final d = c.value;
        final written =
            WorkEntryModel(id: WorkEntryModel.generateId(d), date: d).toMap();
        final read = WorkEntryModel.fromMap(written);
        expect(read.date, d);
        expect(read.date.hour, 0);
        expect(read.date.minute, 0);
        // Das Schreibformat bleibt UTC-Mitternacht des Kalendertags.
        final ts = (written['date'] as Timestamp).toDate().toUtc();
        expect(ts, DateTime.utc(d.year, d.month, d.day));
      });
    }
  });
}
