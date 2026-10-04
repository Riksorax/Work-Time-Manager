import { BUNDESLAND_VALUES, Bundesland } from '../models';

/** Typguard: ist der Rohwert eines der 16 Bundesland-Kürzel? */
export function isBundesland(raw: unknown): raw is Bundesland {
  return typeof raw === 'string' && (BUNDESLAND_VALUES as readonly string[]).includes(raw);
}

/** Normalisiert Rohwerte (Firestore/localStorage) – `""`, Fremdtypen und unbekannte Werte werden zu `null`. */
export function normalizeBundesland(raw: unknown): Bundesland | null {
  return isBundesland(raw) ? raw : null;
}
