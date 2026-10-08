import { DEFAULT_VACATION_DAYS_PER_YEAR, MAX_VACATION_DAYS } from '../models/index';

/** Prüft, ob der Wert ein gültiger Urlaubsanspruch ist (ganze Zahl 0..366). */
export function isValidVacationDays(raw: unknown): raw is number {
  return typeof raw === 'number' && Number.isInteger(raw) && raw >= 0 && raw <= MAX_VACATION_DAYS;
}

/** Liefert den Wert, falls gültig, sonst den Default (30). */
export function normalizeVacationDays(raw: unknown): number {
  return isValidVacationDays(raw) ? raw : DEFAULT_VACATION_DAYS_PER_YEAR;
}
