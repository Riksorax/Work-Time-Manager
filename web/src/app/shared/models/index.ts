export type WorkEntryType = 'work' | 'vacation' | 'sick' | 'holiday';

export interface Break {
  id: string;
  name: string;
  start: Date;
  end?: Date;
  isAutomatic: boolean;
}

export interface WorkEntry {
  id: string; // Wird als YYYY-MM-DD formatiert
  date: Date;
  workStart?: Date;
  workEnd?: Date;
  type: WorkEntryType;
  description?: string;
  isManuallyEntered: boolean;
  manualOvertimeMinutes?: number;
  breaks: Break[];
}

export interface WorkMonth {
  id: string; // YYYY-MM
  days: { [day: string]: WorkEntry };
}

export interface OvertimeBalance {
  minutes: number;
  lastUpdated: Date;
}

export interface UserSettings {
  language: 'de' | 'en';
  theme: 'light' | 'dark' | 'system';
  weeklyTargetHours: number;
  dailyTargetHours: number;
}

export interface UserProfile {
  uid: string;
  email: string;
  displayName?: string;
  photoURL?: string;
  isPremium: boolean;
  settings: UserSettings;
}

export const DEFAULT_USER_SETTINGS: UserSettings = {
  language: 'de',
  theme: 'system',
  weeklyTargetHours: 40,
  dailyTargetHours: 8
};

export interface WorkProfile {
  id: string;
  name: string;
  color: string;
  weeklyTargetHours: number;
  dailyTargetHours: number;
  isDefault: boolean;
}

export interface DailyReport {
  date: Date;
  workedMinutes: number;
  targetMinutes: number;
  overtimeMinutes: number;
  type: WorkEntryType;
}

export interface WeeklyReport {
  startDate: Date;
  endDate: Date;
  totalWorkedMinutes: number;
  totalTargetMinutes: number;
  overtimeMinutes: number;
  dailyReports: DailyReport[];
}

export interface MonthlyReport {
  year: number;
  month: number;
  totalWorkedMinutes: number;
  totalTargetMinutes: number;
  overtimeMinutes: number;
}

export interface YearlyReport {
  year: number;
  totalWorkedMinutes: number;
  totalTargetMinutes: number;
  overtimeMinutes: number;
  months: MonthlyReport[];
}

export interface CategoryBreakdown {
  category: string;
  minutes: number;
  percentage: number;
}

export interface NotificationReminder {
  id: string;
  type: 'workStart' | 'workEnd';
  time: string; // "HH:mm"
  enabled: boolean;
}
