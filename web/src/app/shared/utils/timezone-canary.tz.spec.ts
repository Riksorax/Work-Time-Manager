/**
 * Canary (#407): Die Zonen-Regressionstests (`*.tz.spec.ts`) laufen in CI auch unter `TZ=America/Los_Angeles` und
 * `TZ=Pacific/Auckland`. Eine unbekannte oder nicht wirksame Zone fällt still auf UTC zurück; dann wären diese
 * Läufe wirkungslos. Der Test prüft deshalb, dass eine gesetzte, bekannte Zone auch greift.
 */
const OFFSET_MINUTES_JANUARY: Record<string, number> = {
  UTC: 0,
  'Europe/Berlin': -60,
  'America/Los_Angeles': 480,
  'Pacific/Auckland': -780, // Januar = Sommerzeit (UTC+13)
};

function tzFromEnv(): string | undefined {
  // `process` ist in der Spec-Konfiguration nicht typisiert (nur vitest/globals).
  return (globalThis as { process?: { env?: Record<string, string | undefined> } }).process?.env?.['TZ'];
}

describe('Zeitzonen-Canary (#407)', () => {
  const tz = tzFromEnv();

  it('eine gesetzte, bekannte Zone ist im Testlauf wirksam (Offset im Januar)', () => {
    if (tz === undefined || !(tz in OFFSET_MINUTES_JANUARY)) return; // keine Behauptung ohne bekannte Zone
    expect(new Date(2026, 0, 15, 12).getTimezoneOffset()).toBe(OFFSET_MINUTES_JANUARY[tz]);
  });

  it('eine gesetzte Zone, die keine UTC-Variante ist, ist nicht still auf UTC zurückgefallen (Tippfehler im Namen)', () => {
    if (tz === undefined || /^(Etc\/)?(UTC|GMT|UCT|Zulu|Universal)$/i.test(tz)) return;
    // Eine unbekannte Zone liefert je nach Laufzeit `undefined` oder `'UTC'`; eine gültige ihren eigenen Namen.
    expect([undefined, 'UTC']).not.toContain(Intl.DateTimeFormat().resolvedOptions().timeZone);
  });

  it('die Zonentabelle des Canary ist in sich stimmig (Sommer/Winter in Berlin und Los Angeles)', () => {
    if (tz !== 'Europe/Berlin' && tz !== 'America/Los_Angeles') return;
    const summer = new Date(2026, 6, 15, 12).getTimezoneOffset();
    expect(summer).toBe(tz === 'Europe/Berlin' ? -120 : 420);
  });
});
