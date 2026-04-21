export interface DailyStat {
  target: number;
  worked: number;
  overtime: number;
}

export interface WeeklyReportDay {
  date: Date;
  worked: number;
}

export interface WeeklyReport {
  weekNumber: number;
  start: Date;
  end: Date;
  totalWorked: number;
  totalBreaks: number;
  workDays: number;
  avgPerDay: number;
  overtime: number;
  days: WeeklyReportDay[];
}

export interface MonthlyReportWeek {
  weekNumber: number;
  totalWorked: number;
}

export interface MonthlyReportDay {
  date: Date;
  worked: number;
}

export interface MonthlyReport {
  month: Date;
  totalWorked: number;
  totalBreaks: number;
  workDays: number;
  avgPerDay: number;
  avgPerWeek: number;
  monthlyOvertime: number;
  totalOvertime: number;
  weeks: MonthlyReportWeek[];
  days: MonthlyReportDay[];
}
