export type DefaultBreakNameKind = 'plain' | 'numbered' | 'automatic' | 'lunch' | 'short';

export interface DefaultBreakName {
  kind: DefaultBreakNameKind;
  /** Laufende Nummer, nur bei `numbered`. */
  number?: number;
}

/** "Pause 2" / "Pause #2" (Mobile, Dashboard) und "Break 2" (englischer Bearbeiten-Dialog). */
const NUMBERED_BREAK_NAME = /^(?:Pause|Break) #?(\d+)$/;

/**
 * Erkennt die gespeicherten Standard-Pausennamen aller Plattformen (siehe #346).
 * Frei vergebene Namen liefern `null` und müssen unverändert angezeigt werden.
 *
 * Die Namen bleiben bewusst als Datenwert gespeichert, damit bestehende Einträge
 * und die anderen Plattformen kompatibel bleiben; übersetzt wird erst bei der Anzeige.
 */
export function parseDefaultBreakName(name: string): DefaultBreakName | null {
  switch (name) {
    case 'Pause':              return { kind: 'plain' };
    case 'Automatische Pause': return { kind: 'automatic' };
    case 'Mittagspause':       return { kind: 'lunch' };
    case 'Kurzpause':          return { kind: 'short' };
  }
  const match = NUMBERED_BREAK_NAME.exec(name);
  return match ? { kind: 'numbered', number: Number(match[1]) } : null;
}

const KEYS: Record<DefaultBreakNameKind, string> = {
  plain:     'shared.breakPlainName',
  numbered:  'shared.breakDefaultName',
  automatic: 'shared.breakAutomaticName',
  lunch:     'shared.breakLunchName',
  short:     'shared.breakShortName',
};

/**
 * Anzeigename einer Pause. `translate` ist z. B. `TranslateService.instant`;
 * Standardnamen werden übersetzt, frei vergebene Namen bleiben unverändert.
 */
export function localizedBreakName(
  name: string,
  translate: (key: string, params?: Record<string, unknown>) => string,
): string {
  const parsed = parseDefaultBreakName(name);
  if (!parsed) return name;
  return translate(KEYS[parsed.kind], parsed.kind === 'numbered' ? { number: parsed.number } : undefined);
}

/**
 * Name, der gespeichert werden soll: Ein unverändert gelassener Anzeigename wird
 * nicht als übersetzter Freitext gespeichert, sondern der Originalname behalten.
 */
export function breakNameToStore(
  editedName: string,
  originalName: string,
  translate: (key: string, params?: Record<string, unknown>) => string,
): string {
  return editedName === localizedBreakName(originalName, translate) ? originalName : editedName;
}
