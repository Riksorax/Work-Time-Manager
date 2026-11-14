import { WorkEntryType } from '../models/index';
import {
  addWorkLocation, normalizeWorkLocations, readWorkLocations, suggestWorkLocations,
} from './work-locations.util';

describe('normalizeWorkLocations (#526)', () => {
  it('trimmt, verwirft leere und Duplikate ohne Groß-/Kleinschreibung (der erste bleibt)', () => {
    expect(normalizeWorkLocations(['  Büro ', '', '   ', 'büro', 'Kunde', 'KUNDE'])).toEqual(['Büro', 'Kunde']);
  });

  it('null/undefined -> []', () => {
    expect(normalizeWorkLocations(undefined)).toEqual([]);
    expect(normalizeWorkLocations(null)).toEqual([]);
  });

  it('begrenzt auf 5 Orte (nach Duplikat-Entfernung)', () => {
    expect(normalizeWorkLocations(['a', 'A', 'b', 'c', 'd', 'e', 'f'])).toEqual(['a', 'b', 'c', 'd', 'e']);
  });

  it('kürzt auf 60 Zeichen', () => {
    expect(normalizeWorkLocations(['x'.repeat(80)])[0]).toHaveLength(60);
  });

  it('ignoriert Nicht-Texte', () => {
    expect(normalizeWorkLocations(['Büro', 3, null, {}])).toEqual(['Büro']);
  });
});

describe('readWorkLocations', () => {
  it('fehlend oder kein Array -> []', () => {
    expect(readWorkLocations(undefined)).toEqual([]);
    expect(readWorkLocations('x')).toEqual([]);
  });
  it('filtert Nicht-Texte', () => {
    expect(readWorkLocations(['a', 1])).toEqual(['a']);
  });
});

describe('addWorkLocation', () => {
  it('fügt einen gültigen Ort getrimmt am Ende an', () => {
    expect(addWorkLocation(['Büro'], '  Kunde ')).toEqual({ locations: ['Büro', 'Kunde'] });
  });

  it('leer', () => {
    expect(addWorkLocation(['Büro'], '   ')).toEqual({ locations: ['Büro'], error: 'empty' });
  });

  it('Duplikat ohne Groß-/Kleinschreibung', () => {
    expect(addWorkLocation(['Büro'], 'bÜRo').error).toBe('duplicate');
  });

  it('60 Zeichen sind erlaubt, 61 nicht', () => {
    expect(addWorkLocation([], 'x'.repeat(60)).error).toBeUndefined();
    expect(addWorkLocation([], 'x'.repeat(61)).error).toBe('tooLong');
  });

  it('bei 5 Orten gesperrt', () => {
    const r = addWorkLocation(['1', '2', '3', '4', '5'], '6');
    expect(r.error).toBe('max');
    expect(r.locations).toHaveLength(5);
  });

  it('verändert die übergebene Liste nicht', () => {
    const cur = ['Büro'];
    addWorkLocation(cur, 'Kunde');
    expect(cur).toEqual(['Büro']);
  });
});

describe('suggestWorkLocations', () => {
  const e = (day: number, locs: string[] | undefined, type = WorkEntryType.Work) => ({
    date: new Date(2026, 5, day), type, workLocations: locs,
  });

  it('zuletzt verwendete zuerst, ohne Duplikate', () => {
    const r = suggestWorkLocations([e(1, ['Alt']), e(3, ['Neu', 'Büro']), e(2, ['Büro', 'Mitte'])]);
    expect(r).toEqual(['Neu', 'Büro', 'Mitte', 'Alt']);
  });

  it('ohne schon gewählte (Groß-/Kleinschreibung egal)', () => {
    expect(suggestWorkLocations([e(1, ['Büro', 'Kunde'])], ['büro'])).toEqual(['Kunde']);
  });

  it('höchstens 10', () => {
    const many = Array.from({ length: 15 }, (_, i) => e(i + 1, [`Ort${i}`]));
    const r = suggestWorkLocations(many);
    expect(r).toHaveLength(10);
    expect(r[0]).toBe('Ort14');
  });

  it('nur Arbeitstage zählen', () => {
    expect(suggestWorkLocations([e(1, ['Urlaubsort'], WorkEntryType.Vacation)])).toEqual([]);
  });

  it('Einträge ohne Orte werden übersprungen', () => {
    expect(suggestWorkLocations([e(1, undefined), e(2, [])])).toEqual([]);
  });

  it('Filter nach Teiltext', () => {
    expect(suggestWorkLocations([e(1, ['Büro Nord', 'Kunde'])], [], 10, 'nor')).toEqual(['Büro Nord']);
  });

  it('ordnet unabhängig von der Eingabereihenfolge', () => {
    const list = [e(1, ['A']), e(2, ['B'])];
    expect(suggestWorkLocations(list)).toEqual(suggestWorkLocations([...list].reverse()));
  });
});
