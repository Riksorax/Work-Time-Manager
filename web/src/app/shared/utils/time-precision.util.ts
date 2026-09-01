/**
 * Zentrale Helfer für die minutengenaue Zeiterfassung.
 *
 * Die App erfasst, speichert und rechnet ausschließlich minutengenau.
 * Erfasste Zeitstempel (Start, Ende, Pausen) werden dafür auf die volle
 * Minute abgeschnitten statt gerundet — eine Uhrzeit darf nie in der
 * Zukunft liegen (relativ zum tatsächlichen Moment der Erfassung), sonst
 * wirkt es, als würde die App die Zeit manipulieren. Dauern (z. B. für den
 * Gleitzeit-Saldo) werden dagegen weiterhin kaufmännisch gerundet, siehe
 * {@link toStoredMinutes}.
 */

const MS_PER_MINUTE = 60_000;

/**
 * Schneidet einen Zeitstempel auf die volle Minute ab (Sekunden und
 * Millisekunden werden verworfen, nicht gerundet).
 * `08:00:29` → `08:00`, `08:00:59` → `08:00`.
 */
export function roundToMinute(date: Date): Date {
  return new Date(Math.floor(date.getTime() / MS_PER_MINUTE) * MS_PER_MINUTE);
}

/** Wie {@link roundToMinute}, akzeptiert aber `undefined`/`null`. */
export function roundToMinuteOrUndefined(date: Date | null | undefined): Date | undefined {
  return date ? roundToMinute(date) : undefined;
}

/**
 * Der aktuelle Zeitpunkt, auf die volle Minute abgeschnitten.
 * Einzige Quelle für automatisch erfasste Zeitstempel (Arbeits-/Pausenzeiten).
 */
export function nowToMinute(): Date {
  return roundToMinute(new Date());
}

/**
 * Rundet eine Dauer in Millisekunden kaufmännisch auf volle Minuten
 * und gibt sie wieder in Millisekunden zurück.
 */
export function roundMsToMinute(ms: number): number {
  return toStoredMinutes(ms) * MS_PER_MINUTE;
}

/**
 * Eine Dauer in Millisekunden als volle Minuten für die Persistenz.
 *
 * Rundet symmetrisch von der Null weg (`+30s` → `+1min`, `-30s` → `-1min`),
 * damit eine Gleitzeit-Bilanz im Minus nicht anders driftet als im Plus.
 * `Math.round` allein würde `-0.5` auf `-0` runden.
 */
export function toStoredMinutes(ms: number): number {
  const minutes = ms / MS_PER_MINUTE;
  return minutes < 0 ? -Math.round(-minutes) : Math.round(minutes);
}
