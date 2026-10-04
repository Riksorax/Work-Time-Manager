/**
 * Fixture 1:1 aus `mobile/test/domain/utils/german_holidays_fixture.dart`
 * (von Hand eingetragen, nicht aus der Implementierung abgeleitet).
 * Bei Änderungen dort manuell nachziehen.
 */
import { BUNDESLAND_VALUES, Bundesland } from '../models';
import { GermanHoliday, getGermanHolidayIds, getHolidayFor, toDateKey } from './german-holidays.util';

/** Ostersonntage: 2024-03-31, 2025-04-20, 2026-04-05, 2027-03-28. */
const HOLIDAY_DATES_BY_YEAR: Record<number, Record<GermanHoliday, string>> = {
  2024: {
    newYear: '2024-01-01', goodFriday: '2024-03-29', easterMonday: '2024-04-01', labourDay: '2024-05-01',
    ascension: '2024-05-09', whitMonday: '2024-05-20', germanUnityDay: '2024-10-03',
    christmasDay1: '2024-12-25', christmasDay2: '2024-12-26', epiphany: '2024-01-06',
    corpusChristi: '2024-05-30', assumption: '2024-08-15', reformationDay: '2024-10-31',
    allSaints: '2024-11-01', womensDay: '2024-03-08', worldChildrensDay: '2024-09-20',
    repentanceDay: '2024-11-20',
  },
  2025: {
    newYear: '2025-01-01', goodFriday: '2025-04-18', easterMonday: '2025-04-21', labourDay: '2025-05-01',
    ascension: '2025-05-29', whitMonday: '2025-06-09', germanUnityDay: '2025-10-03',
    christmasDay1: '2025-12-25', christmasDay2: '2025-12-26', epiphany: '2025-01-06',
    corpusChristi: '2025-06-19', assumption: '2025-08-15', reformationDay: '2025-10-31',
    allSaints: '2025-11-01', womensDay: '2025-03-08', worldChildrensDay: '2025-09-20',
    repentanceDay: '2025-11-19',
  },
  2026: {
    newYear: '2026-01-01', goodFriday: '2026-04-03', easterMonday: '2026-04-06', labourDay: '2026-05-01',
    ascension: '2026-05-14', whitMonday: '2026-05-25', germanUnityDay: '2026-10-03',
    christmasDay1: '2026-12-25', christmasDay2: '2026-12-26', epiphany: '2026-01-06',
    corpusChristi: '2026-06-04', assumption: '2026-08-15', reformationDay: '2026-10-31',
    allSaints: '2026-11-01', womensDay: '2026-03-08', worldChildrensDay: '2026-09-20',
    repentanceDay: '2026-11-18',
  },
  2027: {
    newYear: '2027-01-01', goodFriday: '2027-03-26', easterMonday: '2027-03-29', labourDay: '2027-05-01',
    ascension: '2027-05-06', whitMonday: '2027-05-17', germanUnityDay: '2027-10-03',
    christmasDay1: '2027-12-25', christmasDay2: '2027-12-26', epiphany: '2027-01-06',
    corpusChristi: '2027-05-27', assumption: '2027-08-15', reformationDay: '2027-10-31',
    allSaints: '2027-11-01', womensDay: '2027-03-08', worldChildrensDay: '2027-09-20',
    repentanceDay: '2027-11-17',
  },
};

const NATIONWIDE: GermanHoliday[] = [
  'newYear', 'goodFriday', 'easterMonday', 'labourDay', 'ascension', 'whitMonday',
  'germanUnityDay', 'christmasDay1', 'christmasDay2',
];

const LAND_SPECIFIC: Record<Bundesland, GermanHoliday[]> = {
  badenWuerttemberg: ['epiphany', 'corpusChristi', 'allSaints'],
  bayern: ['epiphany', 'corpusChristi', 'assumption', 'allSaints'],
  berlin: ['womensDay'],
  brandenburg: ['reformationDay'],
  bremen: ['reformationDay'],
  hamburg: ['reformationDay'],
  hessen: ['corpusChristi'],
  mecklenburgVorpommern: ['womensDay', 'reformationDay'],
  niedersachsen: ['reformationDay'],
  nordrheinWestfalen: ['corpusChristi', 'allSaints'],
  rheinlandPfalz: ['corpusChristi', 'allSaints'],
  saarland: ['corpusChristi', 'assumption', 'allSaints'],
  sachsen: ['reformationDay', 'repentanceDay'],
  sachsenAnhalt: ['epiphany', 'reformationDay'],
  schleswigHolstein: ['reformationDay'],
  thueringen: ['worldChildrensDay', 'reformationDay'],
};

function expectedHolidays(year: number, land: Bundesland): Map<string, GermanHoliday> {
  const dates = HOLIDAY_DATES_BY_YEAR[year];
  return new Map([...NATIONWIDE, ...LAND_SPECIFIC[land]].map(id => [dates[id], id]));
}

const YEARS = [2024, 2025, 2026, 2027];

describe('german-holidays.util', () => {
  describe('getGermanHolidayIds (Mobile-Fixture)', () => {
    const cases = BUNDESLAND_VALUES.flatMap(land => YEARS.map(year => [land, year] as const));

    it.each(cases)('%s %i entspricht der Fixture', (land, year) => {
      const actual = getGermanHolidayIds(year, land);
      const expected = expectedHolidays(year, land);
      expect([...actual.keys()].sort()).toEqual([...expected.keys()].sort());
      expect(Object.fromEntries(actual)).toEqual(Object.fromEntries(expected));
    });

    it.each(cases)('%s %i hat 9 + landesspezifische Feiertage', (land, year) => {
      expect(getGermanHolidayIds(year, land).size).toBe(9 + LAND_SPECIFIC[land].length);
    });

    it('Hamburg = 9 + Reformationstag, Hessen = 9 + Fronleichnam', () => {
      expect(LAND_SPECIFIC.hamburg).toEqual(['reformationDay']);
      expect(LAND_SPECIFIC.hessen).toEqual(['corpusChristi']);
      expect(getGermanHolidayIds(2026, 'hamburg').size).toBe(10);
      expect(getGermanHolidayIds(2026, 'hessen').size).toBe(10);
    });
  });

  describe('Ostern-abhängige Feiertage', () => {
    it.each([
      [2024, '2024-03-29', '2024-04-01', '2024-05-09', '2024-05-20', '2024-05-30'],
      [2025, '2025-04-18', '2025-04-21', '2025-05-29', '2025-06-09', '2025-06-19'],
      [2026, '2026-04-03', '2026-04-06', '2026-05-14', '2026-05-25', '2026-06-04'],
      [2027, '2027-03-26', '2027-03-29', '2027-05-06', '2027-05-17', '2027-05-27'],
    ])('%i', (year, gf, em, asc, wm, cc) => {
      const m = getGermanHolidayIds(year, 'bayern');
      expect(m.get(gf)).toBe('goodFriday');
      expect(m.get(em)).toBe('easterMonday');
      expect(m.get(asc)).toBe('ascension');
      expect(m.get(wm)).toBe('whitMonday');
      expect(m.get(cc)).toBe('corpusChristi');
    });
  });

  describe('Buß- und Bettag (Parität mit Mobile)', () => {
    it.each([[2024, '2024-11-20'], [2025, '2025-11-19'], [2026, '2026-11-18'], [2027, '2027-11-17']])(
      'Sachsen %i',
      (year, key) => {
        expect(getGermanHolidayIds(year, 'sachsen').get(key)).toBe('repentanceDay');
      },
    );

    it('gilt in keinem anderen Land', () => {
      for (const land of BUNDESLAND_VALUES.filter(l => l !== 'sachsen')) {
        for (const year of YEARS) {
          expect([...getGermanHolidayIds(year, land).values()]).not.toContain('repentanceDay');
        }
      }
    });

    it('liegt immer auf einem Mittwoch zwischen 16. und 22.11.', () => {
      for (let year = 2000; year <= 2060; year++) {
        const key = [...getGermanHolidayIds(year, 'sachsen')].find(([, id]) => id === 'repentanceDay')![0];
        const [y, m, d] = key.split('-').map(Number);
        expect(m).toBe(11);
        expect(d).toBeGreaterThanOrEqual(16);
        expect(d).toBeLessThanOrEqual(22);
        expect(new Date(Date.UTC(y, m - 1, d)).getUTCDay()).toBe(3);
      }
    });
  });

  describe('getHolidayFor', () => {
    it('Umstellungstage ohne Feiertag liefern null', () => {
      expect(getHolidayFor(new Date(2025, 2, 30), 'bayern')).toBeNull();
      expect(getHolidayFor(new Date(2025, 9, 26), 'bayern')).toBeNull();
    });

    it('Feiertage nahe der Zeitumstellung (Ostern 2024-03-31)', () => {
      expect(getHolidayFor(new Date(2024, 2, 29), 'bayern')).toBe('goodFriday');
      expect(getHolidayFor(new Date(2024, 3, 1), 'bayern')).toBe('easterMonday');
      expect(getHolidayFor(new Date(2024, 2, 31), 'bayern')).toBeNull();
    });

    it('3.10. 23:30 bleibt Tag der Deutschen Einheit, 4.10. 00:00:01 nicht', () => {
      expect(getHolidayFor(new Date(2026, 9, 3, 23, 30), 'berlin')).toBe('germanUnityDay');
      expect(getHolidayFor(new Date(2026, 9, 4, 0, 0, 1), 'berlin')).toBeNull();
    });

    it('Zeitanteil ändert das Ergebnis nicht', () => {
      expect(getHolidayFor(new Date(2026, 9, 3, 0, 0), 'berlin')).toBe('germanUnityDay');
      expect(getHolidayFor(new Date(2026, 9, 3, 23, 59, 59), 'berlin')).toBe('germanUnityDay');
    });

    it('Jahreswechsel', () => {
      expect(getHolidayFor(new Date(2025, 11, 31, 23, 59), 'berlin')).toBeNull();
      expect(getHolidayFor(new Date(2026, 0, 1), 'berlin')).toBe('newYear');
    });

    it('Länderspezifika', () => {
      expect(getHolidayFor(new Date(2026, 0, 6), 'badenWuerttemberg')).toBe('epiphany');
      expect(getHolidayFor(new Date(2026, 0, 6), 'bayern')).toBe('epiphany');
      expect(getHolidayFor(new Date(2026, 0, 6), 'sachsenAnhalt')).toBe('epiphany');
      expect(getHolidayFor(new Date(2026, 0, 6), 'nordrheinWestfalen')).toBeNull();
      expect(getHolidayFor(new Date(2026, 2, 8), 'berlin')).toBe('womensDay');
      expect(getHolidayFor(new Date(2026, 2, 8), 'mecklenburgVorpommern')).toBe('womensDay');
      expect(getHolidayFor(new Date(2026, 2, 8), 'bayern')).toBeNull();
      expect(getHolidayFor(new Date(2026, 8, 20), 'thueringen')).toBe('worldChildrensDay');
      expect(getHolidayFor(new Date(2026, 8, 20), 'sachsen')).toBeNull();
      expect(getHolidayFor(new Date(2026, 7, 15), 'bayern')).toBe('assumption');
      expect(getHolidayFor(new Date(2026, 7, 15), 'saarland')).toBe('assumption');
      expect(getHolidayFor(new Date(2026, 7, 15), 'berlin')).toBeNull();
      expect(getHolidayFor(new Date(2026, 10, 1), 'nordrheinWestfalen')).toBe('allSaints');
      expect(getHolidayFor(new Date(2026, 10, 1), 'berlin')).toBeNull();
    });

    it('Reformationstag in genau 9 Ländern', () => {
      const lands = BUNDESLAND_VALUES.filter(l => getHolidayFor(new Date(2026, 9, 31), l) === 'reformationDay');
      expect(lands).toHaveLength(9);
      expect(lands).toEqual(expect.arrayContaining(['sachsen', 'thueringen', 'hamburg']));
    });
  });

  describe('toDateKey', () => {
    it('nutzt lokale Felder', () => {
      expect(toDateKey(new Date(2026, 0, 5, 23, 30))).toBe('2026-01-05');
    });
    it('polstert Monat und Tag', () => {
      expect(toDateKey(new Date(2026, 2, 4))).toBe('2026-03-04');
      expect(toDateKey(new Date(2026, 11, 14))).toBe('2026-12-14');
    });
  });
});
