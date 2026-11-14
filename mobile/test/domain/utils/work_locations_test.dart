import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/work_locations.dart';

// Reine Hilfsfunktionen für Arbeitsorte (#526), gleiche Regeln wie Web
// `work-locations.util.ts` und Backend `NormalizeWorkLocations`.
void main() {
  group('normalizeWorkLocations', () {
    test('trimmt, verwirft Leere und Duplikate (erster bleibt)', () {
      expect(normalizeWorkLocations([' Büro ', '', '  ', 'büro', 'Kunde']),
          ['Büro', 'Kunde']);
    });

    test('kürzt auf 60 Zeichen und begrenzt auf 5', () {
      final long = 'x' * 70;
      final result = normalizeWorkLocations([long, 'a', 'b', 'c', 'd', 'e']);
      expect(result.first.length, 60);
      expect(result, hasLength(5));
      expect(result.last, 'd');
    });

    test('Nicht-Texte und null', () {
      expect(normalizeWorkLocations([1, 'A', null]), ['A']);
      expect(normalizeWorkLocations(null), isEmpty);
      expect(normalizeWorkLocationsOrNull(null), isNull);
      expect(normalizeWorkLocationsOrNull(const []), isEmpty);
    });
  });

  test('readWorkLocations: fehlend oder keine Liste = leer', () {
    expect(readWorkLocations(null), isEmpty);
    expect(readWorkLocations('Büro'), isEmpty);
    expect(readWorkLocations(['A', 3, 'B']), ['A', 'B']);
  });

  group('addWorkLocation', () {
    test('fügt getrimmt hinzu', () {
      final r = addWorkLocation(['A'], '  B ');
      expect(r.error, isNull);
      expect(r.locations, ['A', 'B']);
    });

    test('Fehlerarten in der Reihenfolge des Web', () {
      expect(addWorkLocation([], '   ').error, AddWorkLocationError.empty);
      expect(addWorkLocation([], 'x' * 61).error, AddWorkLocationError.tooLong);
      expect(addWorkLocation(['x' * 60], 'x' * 60).error,
          AddWorkLocationError.duplicate);
      expect(addWorkLocation(['Büro'], 'BÜRO').error,
          AddWorkLocationError.duplicate);
      expect(addWorkLocation(['a', 'b', 'c', 'd', 'e'], 'f').error,
          AddWorkLocationError.max);
      // Duplikat geht vor „max“.
      expect(addWorkLocation(['a', 'b', 'c', 'd', 'e'], 'A').error,
          AddWorkLocationError.duplicate);
    });

    test('bei Fehler unveränderte Kopie', () {
      final current = ['A'];
      final r = addWorkLocation(current, 'a');
      expect(r.locations, ['A']);
      expect(identical(r.locations, current), isFalse);
    });
  });

  group('suggestWorkLocations', () {
    final days = [
      WorkLocationDay(DateTime(2026, 10, 1), const ['Alt', 'Kunde A']),
      WorkLocationDay(DateTime(2026, 10, 5), const ['Büro', 'kunde a']),
      WorkLocationDay(DateTime(2026, 10, 3), const ['Lager']),
    ];

    test('zuletzt verwendet zuerst, ohne Duplikate', () {
      expect(suggestWorkLocations(days), ['Büro', 'kunde a', 'Lager', 'Alt']);
    });

    test('ohne die schon gewählten, mit Filter', () {
      expect(suggestWorkLocations(days, selected: ['BÜRO']),
          ['kunde a', 'Lager', 'Alt']);
      expect(
          suggestWorkLocations(days, filter: 'a'), ['kunde a', 'Lager', 'Alt']);
    });

    test('höchstens 10', () {
      final many = [
        for (var i = 0; i < 15; i++)
          WorkLocationDay(DateTime(2026, 1, i + 1), ['Ort $i'])
      ];
      final r = suggestWorkLocations(many);
      expect(r, hasLength(maxWorkLocationSuggestions));
      expect(r.first, 'Ort 14');
    });
  });

  test('workLocationsByDay: nur Arbeit, Tag aus der Id', () {
    final map = workLocationsByDay([
      WorkEntryEntity(
          id: '2026-10-05',
          // inkonsistentes date (Vortag): der Tag kommt aus der Id
          date: DateTime(2026, 10, 4),
          workLocations: const ['Büro']),
      WorkEntryEntity(
          id: '2026-10-06',
          date: DateTime(2026, 10, 6),
          type: WorkEntryType.vacation,
          workLocations: const ['Strand']),
      WorkEntryEntity(id: '2026-10-07', date: DateTime(2026, 10, 7)),
    ]);
    expect(map, {
      DateTime(2026, 10, 5): ['Büro']
    });
  });
}
