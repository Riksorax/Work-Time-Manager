import { InjectionToken } from '@angular/core';

/**
 * IANA-Zeitzone des Browsers (#537), z. B. `Europe/Berlin`. Als Funktion, damit sie bei jedem Aufruf frisch gelesen wird;
 * Tests ersetzen das Token und hängen so nicht von der Zone des Testprozesses ab.
 */
export const BROWSER_TIME_ZONE = new InjectionToken<() => string>('BROWSER_TIME_ZONE', {
  providedIn: 'root',
  factory: () => () => Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',
});
