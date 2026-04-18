import { WorkEntry, Break } from '../models';

export function calculateNetDuration(entry: WorkEntry): number {
  if (!entry.workStart) return 0;
  const end = entry.workEnd || new Date();
  const grossMinutes = (end.getTime() - entry.workStart.getTime()) / 60000;
  const totalBreakMinutes = entry.breaks.reduce((total, b) => {
    const bEnd = b.end || new Date();
    return total + (bEnd.getTime() - b.start.getTime()) / 60000;
  }, 0);
  return Math.max(0, grossMinutes - totalBreakMinutes);
}

export function calculateGrossDuration(entry: WorkEntry): number {
  if (!entry.workStart) return 0;
  const end = entry.workEnd || new Date();
  return (end.getTime() - entry.workStart.getTime()) / 60000;
}

export function calculateOvertime(netMinutes: number, targetMinutes: number): number {
  return netMinutes - targetMinutes;
}

export function calculateExpectedEnd(entry: WorkEntry, targetMinutes: number): Date {
  if (!entry.workStart) return new Date();
  const totalBreakMinutes = entry.breaks.reduce((total, b) => {
    const bEnd = b.end || new Date();
    return total + (bEnd.getTime() - b.start.getTime()) / 60000;
  }, 0);
  return new Date(entry.workStart.getTime() + (targetMinutes + totalBreakMinutes) * 60000);
}

export function formatDuration(totalMinutes: number): string {
  const isNegative = totalMinutes < 0;
  const absMinutes = Math.abs(totalMinutes);
  const hours = Math.floor(absMinutes / 60);
  const minutes = Math.floor(absMinutes % 60);
  
  const sign = isNegative ? '-' : '';
  const mStr = minutes.toString().padStart(2, '0');
  
  return `${sign}${hours}h ${mStr}min`;
}

export function formatDurationSeconds(totalMinutes: number): string {
  const absMinutes = Math.abs(totalMinutes);
  const hours = Math.floor(absMinutes / 60);
  const minutes = Math.floor(absMinutes % 60);
  const seconds = Math.floor((absMinutes * 60) % 60);
  
  const hStr = hours.toString().padStart(2, '0');
  const mStr = minutes.toString().padStart(2, '0');
  const sStr = seconds.toString().padStart(2, '0');
  
  return `${hStr}:${mStr}:${sStr}`;
}

export function formatOvertime(totalMinutes: number): string {
  const sign = totalMinutes >= 0 ? '+' : '';
  return `${sign}${formatDuration(totalMinutes)}`;
}
