export function formatDuration(totalMinutes: number): string {
  const isNegative = totalMinutes < 0;
  const absMinutes = Math.abs(totalMinutes);
  const hours = Math.floor(absMinutes / 60);
  const minutes = Math.floor(absMinutes % 60);
  
  const sign = isNegative ? '-' : '';
  const mStr = minutes.toString().padStart(2, '0');
  
  return `${sign}${hours}h ${mStr}min`;
}

export function formatOvertime(totalMinutes: number): string {
  const sign = totalMinutes >= 0 ? '+' : '';
  return `${sign}${formatDuration(totalMinutes)}`;
}
