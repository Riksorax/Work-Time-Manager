import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/data/models/work_entry_model.dart';

import '../../../support/api_backed_work_repository.dart';
import '../../../support/timezone_guard.dart';

/// Regression #418: Das Backend liefert `date` als UTC-Mitternacht des
/// Kalendertags. Westlich von UTC wurde daraus beim Lesen der Vortag.
///
/// Die Assertions pruefen Kalendertage und Wochentage und gelten in **jeder**
/// Zone. Vor dem Fix fallen sie nur in bestimmten Zonen durch (Tag-Tests unter
/// `America/Los_Angeles`, Zeitpunkt-Tests E1 bis E3 auch unter Berlin/Auckland);
/// deshalb laufen diese Dateien in CI zusaetzlich unter LA und Auckland.
/// Lokal: `TZ=America/Los_Angeles flutter test <datei>`.
void main() {
  registerTimezoneCanary();

  late ApiBackedWork world;

  setUp(() => world = ApiBackedWork());

  group('Kalendertag aus der Id (Lesegrenze)', () {
    test('getWorkEntry: UTC-Mitternacht mit Z ist der Kalendertag (Montag)',
        () async {
      world.backend.seed('2026-10-05');
      final e = (await world.api.getWorkEntry(2026, 10, 5))!;
      expect(e.date, DateTime(2026, 10, 5));
      expect(e.date.weekday, DateTime.monday);
      expect(e.date.isUtc, isFalse);
    });

    test('getWorkEntry: Schreibweise +00:00 ergibt dasselbe', () async {
      world.backend
          .seed('2026-10-05', dateJson: '2026-10-05T00:00:00.000+00:00');
      final e = (await world.api.getWorkEntry(2026, 10, 5))!;
      expect(e.date, DateTime(2026, 10, 5));
      expect(e.date.weekday, DateTime.monday);
      expect(e.date.isUtc, isFalse);
    });

    test('getWorkEntriesForMonth: beide Schreibweisen, Montag', () async {
      world.backend
        ..seed('2026-10-05')
        ..seed('2026-10-06', dateJson: '2026-10-06T00:00:00+00:00');
      final list = await world.api.getWorkEntriesForMonth(2026, 10);
      expect(list.map((e) => e.date).toSet(),
          {DateTime(2026, 10, 5), DateTime(2026, 10, 6)});
      expect(list.every((e) => !e.date.isUtc), isTrue);
    });

    test('Monatserster 2026-11-01 erscheint im November', () async {
      world.backend.seed('2026-11-01');
      final list = await world.api.getWorkEntriesForMonth(2026, 11);
      expect(list.single.date, DateTime(2026, 11, 1));
      expect(list.single.date.month, 11);
    });

    test('Jahresgrenze 2026-01-01 liegt im Jahr 2026', () async {
      world.backend.seed('2026-01-01');
      final e = (await world.api.getWorkEntry(2026, 1, 1))!;
      expect(e.date, DateTime(2026, 1, 1));
      expect(e.date.year, 2026);
    });

    test('Sonntag 04.10. und Montag 05.10. bleiben getrennte Wochentage',
        () async {
      world.backend
        ..seed('2026-10-04')
        ..seed('2026-10-05');
      final byId = {
        for (final e in await world.api.getWorkEntriesForMonth(2026, 10))
          e.id: e.date
      };
      expect(byId['2026-10-04']!.weekday, DateTime.sunday);
      expect(byId['2026-10-05']!.weekday, DateTime.monday);
    });

    test('Id gewinnt: abweichendes date wird ignoriert (Altdaten)', () async {
      world.backend.seed('2026-10-05', dateJson: '2026-10-04T00:00:00.000Z');
      final e = (await world.api.getWorkEntry(2026, 10, 5))!;
      expect(e.date, DateTime(2026, 10, 5));
    });

    test('Altdaten-Zeitanteil im date (22:00Z) aendert den Tag nicht',
        () async {
      world.backend.seed('2026-10-05', dateJson: '2026-10-04T22:00:00.000Z');
      final e = (await world.api.getWorkEntry(2026, 10, 5))!;
      expect(e.date, DateTime(2026, 10, 5));
    });

    // Ungueltige Id -> Fallback: Kalendertag aus den UTC-Feldern von `date`.
    const invalidIds = {
      '1': '2026-10-01',
      '2026-10-05T12:30:00.000': '2026-10-02',
      '2026-3-2': '2026-10-03',
      '2026-13-45': '2026-10-04',
    };
    for (final c in invalidIds.entries) {
      test('ungueltige Id "${c.key}": Fallback auf die UTC-Felder von date',
          () async {
        world.backend
            .seed(c.key, dateJson: '2026-10-05T00:00:00.000Z', key: c.value);
        final list = await world.api.getWorkEntriesForMonth(2026, 10);
        expect(list.single.date, DateTime(2026, 10, 5));
        expect(list.single.date.isUtc, isFalse);
      });
    }

    test('Profil: zusaetzliches Profil nutzt denselben Mapper', () async {
      final p = ApiBackedWork(profileId: 'p1');
      p.backend.seed('2026-10-05');
      final e = (await p.api.getWorkEntry(2026, 10, 5, profileId: 'p1'))!;
      expect(e.date, DateTime(2026, 10, 5));
      expect(p.backend.requests.last.queryParameters, {'profileId': 'p1'});
      // Und ueber das Repository (WorkRepositoryImpl mit profileId).
      final viaRepo = await p.repository.getWorkEntry(DateTime(2026, 10, 5));
      expect(viaRepo.date, DateTime(2026, 10, 5));
      expect(viaRepo.date.weekday, DateTime.monday);
    });
  });

  group('Schreibpfad bleibt unveraendert (kein Slot-Wechsel)', () {
    test('geladener Eintrag wird als UTC-Mitternacht desselben Tages gesendet',
        () async {
      world.backend.seed('2026-10-05');
      final loaded = (await world.api.getWorkEntry(2026, 10, 5))!;
      await world.api.saveWorkEntry(loaded);

      final body = world.backend.puts.single;
      expect(body['date'], '2026-10-05T00:00:00.000Z');
      expect(body['id'], '2026-10-05');
      // Nur der Slot 2026-10-05 existiert; der Vortag wurde nicht angelegt.
      expect(world.backend.entries.keys, ['2026-10-05']);
    });

    test('Round-Trip ueber das Repository: Slot bleibt, auch mit Profil',
        () async {
      final p = ApiBackedWork(profileId: 'p1');
      p.backend.seed('2026-10-05');
      final loaded = await p.repository.getWorkEntry(DateTime(2026, 10, 5));
      await p.repository.saveWorkEntry(loaded);
      expect(p.backend.puts.single['date'], '2026-10-05T00:00:00.000Z');
      expect(p.backend.entries.keys, ['2026-10-05']);
    });
  });

  // Zeitpunkt-Semantik (E1 bis E3): Nach dem Fix ist `date` die lokale
  // Mitternacht des Kalendertags - auch in Europa. Vorher war es der
  // UTC-Zeitpunkt (Berlin: 02:00 im Sommer, 01:00 im Winter).
  group('Zeitpunkt-Semantik: date ist lokale Mitternacht', () {
    test('E1 Sommer und Winter: genau 00:00 lokal', () async {
      world.backend
        ..seed('2026-07-15')
        ..seed('2026-01-15');
      final summer = (await world.api.getWorkEntry(2026, 7, 15))!;
      final winter = (await world.api.getWorkEntry(2026, 1, 15))!;
      expect(summer.date, DateTime(2026, 7, 15));
      expect(summer.date.hour, 0);
      expect(summer.date.minute, 0);
      expect(winter.date, DateTime(2026, 1, 15));
      expect(winter.date.hour, 0);
      expect(winter.date.minute, 0);
    });

    test('E2 Sommerzeitwechsel-Tage und Nachbartage: lokale Mitternacht',
        () async {
      const days = [
        '2026-03-28',
        '2026-03-29', // 23-h-Tag
        '2026-03-30',
        '2026-10-24',
        '2026-10-25', // 25-h-Tag
        '2026-10-26',
      ];
      for (final id in days) {
        world.backend.seed(id);
      }
      final march = {
        for (final e in await world.api.getWorkEntriesForMonth(2026, 3))
          e.id: e.date
      };
      final october = {
        for (final e in await world.api.getWorkEntriesForMonth(2026, 10))
          e.id: e.date
      };
      final all = {...march, ...october};
      for (final id in days) {
        final p = id.split('-').map(int.parse).toList();
        expect(all[id], DateTime(p[0], p[1], p[2]), reason: id);
        expect(all[id]!.hour, 0, reason: id);
      }
      // Invariante statt Stundenzahl: lokaler Folgetag-Schluessel des Vortags
      // ist gleich dem date des Folgetags.
      expect(DateTime(2026, 3, 28 + 1), all['2026-03-29']);
      expect(DateTime(2026, 3, 29 + 1), all['2026-03-30']);
      expect(DateTime(2026, 10, 24 + 1), all['2026-10-25']);
      expect(DateTime(2026, 10, 25 + 1), all['2026-10-26']);
    });

    test('E3 Equatable: geladener Eintrag == von Hand gebauter Eintrag',
        () async {
      const ids = ['2026-07-15', '2026-01-15', '2026-03-29', '2026-10-25'];
      for (final id in ids) {
        world.backend.seed(id);
      }
      for (final id in ids) {
        final p = id.split('-').map(int.parse).toList();
        final expected =
            WorkEntryModel(id: id, date: DateTime(p[0], p[1], p[2]));
        final single = (await world.api.getWorkEntry(p[0], p[1], p[2]))!;
        final fromMonth = (await world.api.getWorkEntriesForMonth(p[0], p[1]))
            .singleWhere((e) => e.id == id);
        expect(single, expected, reason: id);
        expect(fromMonth, expected, reason: id);
        expect(single, fromMonth, reason: id);
      }
    });
  });
}
