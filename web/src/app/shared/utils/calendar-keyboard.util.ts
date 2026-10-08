/** Pure Tastenlogik des Kalenders (#377): kein Angular, keine Zeitzonen-/Millisekunden-Arithmetik. */

export type CalendarNavKey =
  | 'ArrowLeft' | 'ArrowRight' | 'ArrowUp' | 'ArrowDown'
  | 'Home' | 'End' | 'PageUp' | 'PageDown';

const DAY_DELTAS: Readonly<Record<string, number>> = {
  ArrowLeft: -1,
  ArrowRight: 1,
  ArrowUp: -7,
  ArrowDown: 7,
};

const NAV_KEYS: readonly string[] = [
  'ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Home', 'End', 'PageUp', 'PageDown',
];

export function isCalendarNavKey(key: string): key is CalendarNavKey {
  return NAV_KEYS.includes(key);
}

/**
 * Nächster Fokus-Tag (lokale Mitternacht, immer neue Instanz, `from` bleibt unverändert).
 * Pfeile: ±1/±7 Tage; Home/End: Mo/So der Woche (auf den Monat geklemmt), mit `ctrl`
 * Monatsanfang/-ende; PageUp/PageDown: ±1 Monat, Tag auf den Monatsletzten geklemmt.
 */
export function nextFocusDate(key: CalendarNavKey, from: Date, ctrl: boolean): Date {
  const y = from.getFullYear();
  const m = from.getMonth();
  const d = from.getDate();

  const delta = DAY_DELTAS[key];
  if (delta !== undefined) return new Date(y, m, d + delta);

  const lastOfMonth = new Date(y, m + 1, 0).getDate();
  switch (key) {
    case 'Home': {
      if (ctrl) return new Date(y, m, 1);
      const sinceMonday = (from.getDay() + 6) % 7;
      return new Date(y, m, Math.max(1, d - sinceMonday));
    }
    case 'End': {
      if (ctrl) return new Date(y, m, lastOfMonth);
      const untilSunday = (7 - from.getDay()) % 7;
      return new Date(y, m, Math.min(lastOfMonth, d + untilSunday));
    }
    default: {
      const target = m + (key === 'PageDown' ? 1 : -1);
      const lastOfTarget = new Date(y, target + 1, 0).getDate();
      return new Date(y, target, Math.min(d, lastOfTarget));
    }
  }
}

function toKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/**
 * Geordnete Tages-Keys (`yyyy-MM-dd`) von min bis max, beide inklusive, richtungsunabhängig.
 * Schritt über `new Date(y, m, d + i)` (lokale Mitternacht, DST-sicher); Eingaben bleiben unverändert.
 */
export function rangeKeys(anchor: Date, target: Date): string[] {
  const a = new Date(anchor.getFullYear(), anchor.getMonth(), anchor.getDate());
  const b = new Date(target.getFullYear(), target.getMonth(), target.getDate());
  const [start, end] = a <= b ? [a, b] : [b, a];
  const keys: string[] = [];
  for (let i = 0; ; i++) {
    const cur = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
    if (cur > end) return keys;
    keys.push(toKey(cur));
  }
}

/**
 * Änderung der Auswahl bei einem Bereichsschritt: `add` = neuer Bereich (idempotent additiv),
 * `remove` = vorher gemeldete, nun nicht mehr enthaltene Tage, ohne die vorher bereits gewählten (`base`).
 */
export function rangeDiff(
  oldRange: ReadonlySet<string>,
  newRange: ReadonlySet<string>,
  base: ReadonlySet<string>,
): { add: string[]; remove: string[] } {
  return {
    add: [...newRange],
    remove: [...oldRange].filter(k => !newRange.has(k) && !base.has(k)),
  };
}
