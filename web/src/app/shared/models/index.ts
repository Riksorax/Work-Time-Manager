// shared/models/index.ts
// Alle Datenmodelle - 1:1 aus Flutter-Analyse abgeleitet (AGENT-00)

import { Timestamp } from 'firebase/firestore';

// ─── User Settings ────────────────────────────────────────────────────────────
export interface UserSettings {
  notificationsEnabled: boolean;
  language: 'de' | 'en';
  theme: 'light' | 'dark' | 'system';
  workStartReminder?: string;  // "HH:mm", z.B. "08:00"
  workEndReminder?: string;    // "HH:mm", z.B. "17:00"
  fcmToken?: string;
}

// ─── User Profile ─────────────────────────────────────────────────────────────
export interface UserProfile {
  uid: string;
  email: string;
  displayName?: string;
  photoURL?: string;
  isPremium: boolean;
  premiumExpiresAt?: Timestamp;
  weeklyTargetHours: number;       // Standard: 40
  dailyTargetHours: number;        // Standard: 8
  defaultPauseDuration: number;    // Minuten, Standard: 30
  activeProfileId?: string;        // Multi-Profile (Premium)
  settings: UserSettings;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export const DEFAULT_USER_PROFILE: Omit<UserProfile, 'uid' | 'email' | 'createdAt' | 'updatedAt'> = {
  isPremium: false,
  weeklyTargetHours: 40,
  dailyTargetHours: 8,
  defaultPauseDuration: 30,
  settings: {
    notificationsEnabled: false,
    language: 'de',
    theme: 'system',
  },
};

// ─── Work Session ─────────────────────────────────────────────────────────────
export interface WorkSession {
  id: string;
  userId: string;
  profileId?: string;          // Multi-Profile (Premium)
  startTime: Timestamp;        // Pflichtfeld
  endTime?: Timestamp;         // undefined wenn Session läuft
  pauseDuration: number;       // Gesamte akkumulierte Pausenzeit in Minuten
  pauseStartTime?: Timestamp;  // gesetzt wenn gerade pausiert
  note?: string;
  category?: string;
  isRunning: boolean;          // true = Timer läuft (auch wenn pausiert)
  isPaused: boolean;           // true = Timer aktuell pausiert
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

// ─── Work Profile (Premium: Multi-Arbeitgeber) ────────────────────────────────
export interface WorkProfile {
  id: string;
  name: string;               // z.B. "Hauptarbeitgeber", "Nebenjob"
  color: string;              // Hex-Farbe, z.B. "#4CAF50"
  weeklyTargetHours: number;
  dailyTargetHours: number;
  isDefault: boolean;
  createdAt: Timestamp;
}

// ─── Report Models ────────────────────────────────────────────────────────────
export interface DailyReport {
  date: Date;
  sessions: WorkSession[];
  totalMinutes: number;
  targetMinutes: number;
  overtimeMinutes: number;
}

export interface WeeklyReport {
  weekStart: Date;
  weekEnd: Date;
  dailyReports: DailyReport[];
  totalMinutes: number;
  targetMinutes: number;
  overtimeMinutes: number;
}

export interface MonthlyReport {
  month: Date;
  weeklyReports: WeeklyReport[];
  totalMinutes: number;
  targetMinutes: number;
  overtimeMinutes: number;
}

export interface YearlyReport {
  year: number;
  monthlyReports: MonthlyReport[];
  totalMinutes: number;
  targetMinutes: number;
  overtimeMinutes: number;
}

export interface CategoryBreakdown {
  category: string;
  totalMinutes: number;
  sessionCount: number;
  percentage: number;
}

// ─── Premium ──────────────────────────────────────────────────────────────────
export interface PremiumStatus {
  isActive: boolean;
  entitlementId: string;
  expiresAt?: Date;
  productIdentifier?: string;
}

// ─── Notification ─────────────────────────────────────────────────────────────
export interface NotificationReminder {
  type: 'work_start' | 'work_end';
  time: string; // "HH:mm"
  enabled: boolean;
}
