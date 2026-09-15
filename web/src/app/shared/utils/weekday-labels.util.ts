export const GERMAN_WEEKDAY_SHORT_LABELS = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

export function formatWorkdays(workdays: number[]): string {
  return [...workdays].sort((a, b) => a - b).map(d => GERMAN_WEEKDAY_SHORT_LABELS[d - 1]).join(', ');
}
