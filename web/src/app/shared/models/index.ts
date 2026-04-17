// shared/models/index.ts
import { Timestamp } from 'firebase/firestore';

export type WorkSessionType = 'work' | 'vacation' | 'sick' | 'holiday';

// ─── User Settings ────────────────────────────────────────────────────────────
export interface UserSettings {
  notificationsEnabled: boolean;
  language: 'de' | 'en';
  theme: 'light' | 'dark' | 'system';
  workStartReminder?: string;       // "HH:mm"
  workEndReminder?: string;         // "HH:mm"
  breakReminder?: boolean;          // Pause-Erinnerung aktiv
  notificationDays?: number[];      // [1,2,3,4,5] = Mo–Fr (ISO weekday)
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
  weeklyTargetHours: number;
  dailyTargetHours: number;
  workDaysPerWeek: number;          // Standard: 5 (Mo–Fr)
  defaultPauseDuration: number;     // Minuten, Standard: 30
  overtimeAdjustmentMinutes: number; // Manueller Überstunden-Ausgleich in Minuten
  activeProfileId?: string;
  settings: UserSettings;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export const DEFAULT_USER_PROFILE: Omit<UserProfile, 'uid' | 'email' | 'createdAt' | 'updatedAt'> = {
  isPremium: false,
  weeklyTargetHours: 40,
  dailyTargetHours: 8,
  workDaysPerWeek: 5,
  defaultPauseDuration: 30,
  overtimeAdjustmentMinutes: 0,
  settings: {
    notificationsEnabled: false,
    language: 'de',
    theme: 'system',
    breakReminder: false,
    notificationDays: [1, 2, 3, 4, 5],
  },
};

// ─── Work Session ─────────────────────────────────────────────────────────────
export interface WorkSession {
  id: string;
  userId: string;
  profileId?: string;
  type: WorkSessionType;            // work | vacation | sick | holiday
  startTime: Timestamp;
  endTime?: Timestamp;
  pauseDuration: number;
  pauseStartTime?: Timestamp;
  note?: string;
  category?: string;
  isRunning: boolean;
  isPaused: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

// ─── Work Profile (Premium) ───────────────────────────────────────────────────
export interface WorkProfile {
  id: string;
  name: string;
  color: string;
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
  type: 'work_start' | 'work_end' | 'break';
  time: string;
  enabled: boolean;
}
