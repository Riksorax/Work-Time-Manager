export enum WorkEntryType {
  Work = 'work',
  Vacation = 'vacation',
  Sick = 'sick',
  Holiday = 'holiday',
}

export interface Break {
  id: string;
  name: string;
  start: Date;
  end?: Date;
  isAutomatic: boolean;
}

export interface WorkEntry {
  id: string;
  date: Date;
  workStart?: Date;
  workEnd?: Date;
  breaks: Break[];
  manualOvertimeMinutes?: number;
  isManuallyEntered: boolean;
  description?: string;
  type: WorkEntryType;
  /**
   * Home-Office-Tag (#277). Beim Lesen fehlend = `false`, nur bei Typ Arbeit relevant. Beim Schreiben bedeutet
   * `undefined` "unangetastet" (bestehendes Flag bleibt), `false` löscht es explizit.
   */
  isHomeOffice?: boolean;
  /**
   * Arbeitsorte des Tages (#526), geordnet, höchstens 5 à höchstens 60 Zeichen, nur bei Typ Arbeit relevant.
   * Beim Lesen fehlend = `[]`. Beim Schreiben bedeutet `undefined` "unangetastet" (gespeicherte Orte bleiben),
   * `[]` löscht das Feld, eine Liste ersetzt die gespeicherte. Der Client bereinigt vor dem Schreiben selbst
   * (`normalizeWorkLocations`), das Backend tut es ebenso.
   */
  workLocations?: string[];
}

export interface UserSettings {
  weeklyTargetHours: number;
  /** Konkrete Arbeitstage als ISO-Wochentage (1 = Montag, 7 = Sonntag). Siehe #217. */
  workdays: number[];
  notificationsEnabled: boolean;
  notificationTime: string; // HH:mm
  notificationDays: number[]; // 1-7
  notifyWorkStart: boolean;
  notifyWorkEnd: boolean;
  notifyBreaks: boolean;
  /** Jahres-Urlaubsanspruch in Tagen (ganze Zahl 0-366, Default 30). Siehe #278. */
  vacationDaysPerYear: number;
  /** Bundesland für Feiertage im Dashboard und Kalender (null = nicht gewählt). Siehe #279. */
  bundesland: Bundesland | null;
  /** Arbeitsort im Dashboard anzeigen (Standard aus). Wirkt nur auf das Dashboard. Siehe #526. */
  showWorkLocationOnDashboard: boolean;
  /** Home-Office im Dashboard anzeigen (Standard an). Wirkt nur auf das Dashboard. Siehe #526. */
  showHomeOfficeOnDashboard: boolean;
}

/** Die 16 Bundesländer (Werte = Flutter-Enum-Namen, i18n-Key `settings.bundesland.state.<wert>`). Siehe #279. */
export const BUNDESLAND_VALUES = [
  'badenWuerttemberg', 'bayern', 'berlin', 'brandenburg', 'bremen', 'hamburg', 'hessen',
  'mecklenburgVorpommern', 'niedersachsen', 'nordrheinWestfalen', 'rheinlandPfalz', 'saarland',
  'sachsen', 'sachsenAnhalt', 'schleswigHolstein', 'thueringen',
] as const;
export type Bundesland = (typeof BUNDESLAND_VALUES)[number];

export const DEFAULT_VACATION_DAYS_PER_YEAR = 30;
export const MAX_VACATION_DAYS = 366;

export const DEFAULT_SETTINGS: UserSettings = {
  weeklyTargetHours: 40,
  workdays: [1, 2, 3, 4, 5],
  notificationsEnabled: false,
  notificationTime: '08:00',
  notificationDays: [1, 2, 3, 4, 5],
  notifyWorkStart: false,
  notifyWorkEnd: false,
  notifyBreaks: false,
  vacationDaysPerYear: DEFAULT_VACATION_DAYS_PER_YEAR,
  bundesland: null,
  showWorkLocationOnDashboard: false,
  showHomeOfficeOnDashboard: true,
};

export interface UserProfile {
  uid: string;
  email: string;
  displayName?: string;
  photoURL?: string;
  isPremium: boolean;
  settings: UserSettings;
}

/** Ein zusätzliches Arbeitszeit-Profil (siehe #138/#239/#244). */
export interface WorkProfile {
  id: string;
  name: string;
}

/** ID des immer vorhandenen Standard-Profils - bildet die bestehenden,
 * nicht migrierten Firestore-Pfade ab (kein Datenverlust-Risiko). */
export const DEFAULT_WORK_PROFILE_ID = 'default';
