import { Bundesland } from '../models';

/** Kennungen der 17 gesetzlichen Feiertage (i18n-Key `holidays.<id>`). Siehe #279.
 *  Port von `mobile/lib/domain/utils/german_holidays.dart`; Berechnung ausschließlich über UTC-Felder (TZ/DST-sicher). */
export const GERMAN_HOLIDAY_IDS = [
  'newYear', 'goodFriday', 'easterMonday', 'labourDay', 'ascension', 'whitMonday', 'germanUnityDay',
  'christmasDay1', 'christmasDay2', 'epiphany', 'corpusChristi', 'assumption', 'reformationDay',
  'allSaints', 'womensDay', 'worldChildrensDay', 'repentanceDay',
] as const;
export type GermanHoliday = (typeof GERMAN_HOLIDAY_IDS)[number];

function pad(n: number, len = 2): string { return String(n).padStart(len, '0'); }

function utcKey(d: Date): string {
  return `${pad(d.getUTCFullYear(), 4)}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
}

function addUtcDays(d: Date, n: number): Date {
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() + n));
}

/** Ostersonntag (Meeus/Jones/Butcher, gregorianisch) als UTC-Datum. */
function easterSundayUtc(year: number): Date {
  const a = year % 19;
  const b = Math.floor(year / 100);
  const c = year % 100;
  const d = Math.floor(b / 4);
  const e = b % 4;
  const f = Math.floor((b + 8) / 25);
  const g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4);
  const k = c % 4;
  const l = (32 + 2 * e + 2 * i - h - k) % 7;
  const m = Math.floor((a + 11 * h + 22 * l) / 451);
  const month = Math.floor((h + l - 7 * m + 114) / 31);
  const day = ((h + l - 7 * m + 114) % 31) + 1;
  return new Date(Date.UTC(year, month - 1, day));
}

/** Buß- und Bettag: Mittwoch auf oder vor dem 22.11. (nur Sachsen). */
function repentanceDayUtc(year: number): Date {
  let date = new Date(Date.UTC(year, 10, 22));
  while (date.getUTCDay() !== 3) date = addUtcDays(date, -1);
  return date;
}

/** `YYYY-MM-DD` aus den lokalen Feldern von `date` (nie `toISOString()`). */
export function toDateKey(date: Date): string {
  return `${pad(date.getFullYear(), 4)}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

/** Feiertage eines Jahres/Bundeslands: Schlüssel `YYYY-MM-DD`. Parität mit Mobile `getGermanHolidayIds`. */
export function getGermanHolidayIds(year: number, bundesland: Bundesland): Map<string, GermanHoliday> {
  const easter = easterSundayUtc(year);
  const fixed = (month: number, day: number) => utcKey(new Date(Date.UTC(year, month - 1, day)));
  const rel = (n: number) => utcKey(addUtcDays(easter, n));

  const holidays = new Map<string, GermanHoliday>([
    [fixed(1, 1), 'newYear'],
    [rel(-2), 'goodFriday'],
    [rel(1), 'easterMonday'],
    [fixed(5, 1), 'labourDay'],
    [rel(39), 'ascension'],
    [rel(50), 'whitMonday'],
    [fixed(10, 3), 'germanUnityDay'],
    [fixed(12, 25), 'christmasDay1'],
    [fixed(12, 26), 'christmasDay2'],
  ]);

  const epiphany = () => holidays.set(fixed(1, 6), 'epiphany');
  const corpusChristi = () => holidays.set(rel(60), 'corpusChristi');
  const assumption = () => holidays.set(fixed(8, 15), 'assumption');
  const reformationDay = () => holidays.set(fixed(10, 31), 'reformationDay');
  const allSaints = () => holidays.set(fixed(11, 1), 'allSaints');
  const womensDay = () => holidays.set(fixed(3, 8), 'womensDay');

  switch (bundesland) {
    case 'badenWuerttemberg': epiphany(); corpusChristi(); allSaints(); break;
    case 'bayern': epiphany(); corpusChristi(); assumption(); allSaints(); break;
    case 'berlin': womensDay(); break;
    case 'brandenburg':
    case 'bremen':
    case 'hamburg':
    case 'niedersachsen':
    case 'schleswigHolstein': reformationDay(); break;
    case 'hessen': corpusChristi(); break;
    case 'mecklenburgVorpommern': womensDay(); reformationDay(); break;
    case 'nordrheinWestfalen':
    case 'rheinlandPfalz': corpusChristi(); allSaints(); break;
    case 'saarland': corpusChristi(); assumption(); allSaints(); break;
    case 'sachsen':
      reformationDay();
      holidays.set(utcKey(repentanceDayUtc(year)), 'repentanceDay');
      break;
    case 'sachsenAnhalt': epiphany(); reformationDay(); break;
    case 'thueringen':
      holidays.set(fixed(9, 20), 'worldChildrensDay');
      reformationDay();
      break;
  }
  return holidays;
}

/** Feiertag für das lokale Datum von `date` (Zeitanteil irrelevant) oder `null`. */
export function getHolidayFor(date: Date, bundesland: Bundesland): GermanHoliday | null {
  return getGermanHolidayIds(date.getFullYear(), bundesland).get(toDateKey(date)) ?? null;
}
