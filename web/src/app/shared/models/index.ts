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
}

export interface UserSettings {
  weeklyTargetHours: number;
  workdaysPerWeek: number;
  notificationsEnabled: boolean;
  notificationTime: string; // HH:mm
  notificationDays: number[]; // 1-7
  notifyWorkStart: boolean;
  notifyWorkEnd: boolean;
  notifyBreaks: boolean;
}

export interface UserProfile {
  uid: string;
  email: string;
  displayName?: string;
  photoURL?: string;
  isPremium: boolean;
  settings: UserSettings;
}
