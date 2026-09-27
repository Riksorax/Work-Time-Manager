/**
 * Formatiert eine Menge von ISO-Wochentagen (1-7) als kurze, sortierte,
 * komma-getrennte Liste (z.B. "Di, Mi, Do, Fr, Sa"). `labels` kommt aus dem
 * 'common.weekdaysShort'-Übersetzungs-Key (siehe #300), damit die Anzeige der
 * App-Sprache folgt statt fest Deutsch zu sein.
 */
export function formatWorkdays(workdays: number[], labels: string[]): string {
  return [...workdays].sort((a, b) => a - b).map(d => labels[d - 1]).join(', ');
}
