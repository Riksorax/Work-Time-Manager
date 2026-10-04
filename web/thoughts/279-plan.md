# Web-Plan: #279 — Feiertage pro Bundesland im Dashboard
Erstellt: 2026-10-04
Research: web/thoughts/279-research.md
UI-Report: web/thoughts/279-ui-report.md
Koordination: thoughts/279-coordination.md (Backend #367 und Mobile #368 sind in `develop`)

## Ziel
Das Web-Dashboard zeigt oberhalb des Timers "Heute ist Feiertag: {Name}", wenn das lokale Datum laut gewähltem Bundesland ein gesetzlicher Feiertag ist (rein informativ, Soll/Overtime/Einträge unverändert). Das Bundesland wird in den Settings (je Arbeitszeit-Profil) wählbar, über `PUT /settings` synchronisiert (`""` nur bei expliziter Abwahl) und bei Login aus dem lokalen Speicher migriert. Feiertagslogik wird 1:1 von Mobile portiert.

Die UI-Dateien liegen bereits im Working Tree (Banner, Settings-Sektion, Dialog, i18n, Modell-Stubs). Dieser Plan ersetzt nur die Platzhalter durch Logik und ergänzt alle Specs. Kein Rules-Deploy, keine Backend-Änderung.

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Hybrid-Service nötig? | Nein (bestehender `SettingsService` bleibt Hybrid, nur Signatur erweitert) | Auth-Switch existiert; `bundesland` kommt über `mergeSettings` für Firestore und localStorage |
| Neuer Domain-Service? | Nein. Pure Util `shared/utils/german-holidays.util.ts` (+ `shared/utils/bundesland.util.ts`) | Wie `iso-week.util.ts`/`vacation-days.util.ts`; kein inject(). Abweichung vom Naheliegenden: `normalizeBundesland` in eigener Util-Datei statt in `settings.ts`, weil `data-sync.ts` und `settings.ts` es beide brauchen und `mergeSettings` privat ist |
| Premium-Gate? | Nein | Free-Feature |
| Routing-Änderung? | Nein | Nur bestehende Seiten |
| Neuer API-Endpunkt? | Nein | `PUT /settings` kennt `bundesland` (Backend #367); `null` = unangetastet, `""` = löschen |
| Neuer Firestore-Pfad? | Nein | `settings/current` (Root + Profil), `match /settings/{doc}` deckt es ab |
| Neue Texte? | Ja, bereits in `de.json`/`en.json` angelegt | Plan: nur Keys gegen Code prüfen, Parität per `jq`-Diff |
| Shared Component? | Ja, `HolidayBannerComponent` (existiert) | Rein darstellend |
| Löschen-Semantik | `opts.clearBundesland` an `SettingsService.saveSettings` und `ApiClient.saveSettings`; ausschließlich `SettingsPageService.setBundesland(null)` setzt es | `null` im Ganz-Objekt-PUT ist sicher (unangetastet), `""` nie automatisch. `clearBundesland` wirkt nur, wenn `settings.bundesland === null` (defensiv, ein gesetzter Wert gewinnt) |
| Datumsschlüssel | `YYYY-MM-DD`-String; berechnete Feiertage aus UTC-Feldern, "heute" aus lokalen Feldern, nie `toISOString()` | TZ/DST-sicher |
| Uhr | Kein InjectionToken; Tests mit `vi.useFakeTimers()` + `vi.setSystemTime(new Date(y, m, d, h, min))` (lokale Zeit) | Entscheidung Hauptsession |
| Tageswechsel | Nur Chip: `today`-Signal, aktualisiert per `visibilitychange` und `setTimeout` bis lokale Mitternacht; restliches Dashboard bleibt (Folge-Issue) | Entscheidung Hauptsession |
| DataSync | Cloud gewinnt; lokal gültig + Cloud `null` -> übernehmen; nie `""` | Entscheidung Hauptsession |
| Fixture | In `german-holidays.util.spec.ts`, Quellhinweis auf `mobile/test/domain/utils/german_holidays_fixture.dart` | Entscheidung Hauptsession; `tsconfig.app.json` kompiliert keine Specs |

## Neue / geänderte Dateien

Legende: NEU = neu anzulegen, UI = existiert (Stub/UI), Logik folgt, Spec NEU = nur Spec neu.

### Shared / Domain Layer
```
web/src/app/shared/
├── models/index.ts                          # UI (vorhanden): BUNDESLAND_VALUES, Bundesland, UserSettings.bundesland, DEFAULT_SETTINGS.bundesland = null; unverändert lassen
└── utils/
    ├── bundesland.util.ts                   # NEU: isBundesland(raw): raw is Bundesland, normalizeBundesland(raw: unknown): Bundesland | null ("" / Fremdtyp / unbekannt -> null)
    ├── bundesland.util.spec.ts              # NEU
    ├── german-holidays.util.ts              # UI-Stub (GERMAN_HOLIDAY_IDS, GermanHoliday) -> ergänzen:
    │                                        #   getGermanHolidayIds(year, bundesland): Map<string, GermanHoliday>  (Key YYYY-MM-DD)
    │                                        #   getHolidayFor(date: Date, bundesland): GermanHoliday | null  (lokale Felder von date)
    │                                        #   toDateKey(date: Date): string  (lokale Felder, padStart)
    │                                        #   privat: easterSundayUtc, addUtcDays (Date.UTC(y, m, d + n)), repentanceDayUtc, utcKey
    └── german-holidays.util.spec.ts         # NEU, enthält die Fixture
```
Port-Details (gegen `mobile/lib/domain/utils/german_holidays.dart` gelesen): Buß- und Bettag = Mittwoch auf oder vor dem 22.11. (Start 22.11. inklusive, rückwärts bis `getUTCDay() === 3`); Ergebnisse 2024-11-20, 2025-11-19, 2026-11-18, 2027-11-17. Ostern Meeus/Jones/Butcher mit `Math.floor`. Feiertags- und Länderzuordnung exakt wie Koordination 2.5 / Research.

### Core Layer
```
web/src/app/core/services/
├── settings.ts          # mergeSettings: bundesland: normalizeBundesland(raw.bundesland); saveSettings(settings, opts?: { clearBundesland?: boolean }) reicht opts an ApiClient, anonym unverändert _localSave (null bleibt null)
├── settings.spec.ts     # erweitern
├── api-client.ts        # saveSettings(settings, profileId?, opts?) mit Payload-Typ SettingsPayload = Omit<UserSettings,'bundesland'> & { bundesland: Bundesland | '' | null }
├── api-client.spec.ts   # erweitern
├── data-sync.ts         # Settings-Patch um bundesland erweitern
└── data-sync.spec.ts    # erweitern
```

### Feature Layer
```
web/src/app/features/settings/
├── settings.service.ts      # setBundesland(value): null -> saveSettings({...current, bundesland: null}, { clearBundesland: true }); sonst saveSettings({...current, bundesland: value}); wirft bei Fehler
├── settings.service.spec.ts # erweitern
├── settings.ts              # UI vorhanden (openEditBundeslandDialog, Snackbars); nur prüfen/ggf. Feinschliff
├── settings.spec.ts         # erweitern (Component, overrideComponent template '')
└── components/edit-bundesland-dialog/
    ├── edit-bundesland-dialog.ts        # UI vorhanden; cdkFocusInitial auf aktuelle Auswahl (siehe Schritt 7)
    └── edit-bundesland-dialog.spec.ts   # NEU (Muster edit-vacation-days-dialog.spec.ts)

web/src/app/shared/components/holiday-banner/
└── holiday-banner.spec.ts               # NEU

web/src/app/features/dashboard/
├── dashboard.service.ts     # Platzhalter holidayToday ersetzen
├── dashboard.service.spec.ts# NEU (Fake-Timer, Soll unverändert)
├── dashboard.html / .scss / .ts  # UI vorhanden, unverändert
└── dashboard.spec.ts        # erweitern: Banner gerendert / nicht gerendert
```

### Doku
```
web/CLAUDE.md   # Layer-Übersicht und Feature-Service-Tabelle ergänzen (Schritt 9)
```

## Implementierungsschritte (TDD-First, Layer-Reihenfolge, jeder Schritt beginnt mit dem Test)

Vorab: Baseline `npm test -- --watch=false` (grün) bestätigen. Alle Datums-Specs bauen Daten mit lokalen Konstruktoren (`new Date(2026, 9, 3, 23, 30)`) oder fixen Strings, nie mit `new Date()`; Specs mit Uhr nutzen `vi.useFakeTimers()` + `vi.setSystemTime(...)` und `afterEach(() => vi.useRealTimers())`.

### Schritt 1: `bundesland.util` (Shared)
- [x] Test `bundesland.util.spec.ts`: alle 16 Werte aus `BUNDESLAND_VALUES` -> identisch; `''`, `'NRW'`, `null`, `undefined`, `42`, `{}`, `'Bayern'` (falsche Schreibweise) -> `null`; `isBundesland` Typguard-Fälle.
- [x] Impl `bundesland.util.ts` (pure, `BUNDESLAND_VALUES.includes`).

### Schritt 2: `german-holidays.util` (Shared)
- [x] Test `german-holidays.util.spec.ts`. Kopf-Kommentar: "Fixture 1:1 aus `mobile/test/domain/utils/german_holidays_fixture.dart`; bei Änderungen dort manuell nachziehen". Dart-Enum-Namen = TS-IDs. Fixture: `HOLIDAY_DATES_BY_YEAR: Record<number, Record<GermanHoliday, string>>` (2024-2027, 17 IDs von Hand), `NATIONWIDE`, `LAND_SPECIFIC: Record<Bundesland, GermanHoliday[]>`, `expectedHolidays(year, land)` (Dart-Fixture beim Übernehmen gegenlesen, nicht aus der Util ableiten).
  1. Fixture-Test: `it.each` über 16 Länder x 4 Jahre; `getGermanHolidayIds(year, land)` ist exakt gleich `expectedHolidays` (gleiche Key-Menge, gleiche Werte).
  2. Anzahl je Land: 9 + `LAND_SPECIFIC[land].length`; Hamburg = 9 + reformationDay, Hessen = 9 + corpusChristi.
  3. Ostern-Randfälle 2024 (31.3.), 2025, 2026, 2027: Karfreitag, Ostermontag, Himmelfahrt, Pfingstmontag, Fronleichnam (Land mit Fronleichnam, z. B. `bayern`).
  4. Buß- und Bettag nur für `sachsen`, 2024-2027 (20.11./19.11./18.11./17.11.), in keinem anderen Land.
  5. `getHolidayFor`: lokale Mitternacht `new Date(2025, 2, 30)` und `new Date(2025, 9, 26)` (Umstellungstage) sowie ein Feiertag nahe Umstellung (Ostern 2024-03-31 -> `easterMonday` am 1.4., `goodFriday` am 29.3.); `new Date(2026, 9, 3, 23, 30)` -> `germanUnityDay` (3.10., kein Verrutschen); `new Date(2026, 9, 4, 0, 0, 1)` -> `null`; Datum mit Zeitanteil 00:00 und 23:59:59 liefert dasselbe Ergebnis; Jahreswechsel `new Date(2025, 11, 31, 23, 59)` -> `null`, `new Date(2026, 0, 1)` -> `newYear`.
  6. `toDateKey`: `new Date(2026, 0, 5, 23, 30)` -> `'2026-01-05'`; einstellige Monate/Tage gepolstert; Dokumentationstest, dass nur lokale Felder zählen (kein `Date.UTC`-Eingabetest als Assertion auf Verhalten).
  7. Länderspezifika stichprobenartig mit Datum: `epiphany` (BW/BY/ST ja, NW nein), `womensDay` (BE/MV), `worldChildrensDay` (TH), `assumption` (BY/SL), `allSaints`, `reformationDay` (9 Länder).
- [x] Impl `german-holidays.util.ts` (Stub `GERMAN_HOLIDAY_IDS`/`GermanHoliday` beibehalten), Berechnung ausschließlich über UTC-Felder; `getHolidayFor` = `getGermanHolidayIds(date.getFullYear(), land).get(toDateKey(date)) ?? null`.
- [x] Läufe: `npm test -- --watch=false`, `TZ=Europe/Berlin ...`, lokal zusätzlich `TZ=America/New_York` und `TZ=UTC`.

### Schritt 3: Core `SettingsService.mergeSettings` + `saveSettings`
- [x] Test `settings.spec.ts` (erweitern; vorhandene Mocks: `ApiClient { saveSettings: vi.fn() }`):
  - Lesen anonym: localStorage `user_settings` mit `bundesland: 'bayern'` -> `getSettings()` liefert `'bayern'`; `''`, `'xyz'`, `123`, fehlend -> `null`.
  - Lesen eingeloggt (falls Firestore dort schon gemockt wird, sonst nur über `_localGet`): Rohwert `""` -> `null`.
  - Anonym `saveSettings({...s, bundesland: 'hessen'})` -> localStorage enthält `hessen`; danach `saveSettings({...s, bundesland: null}, { clearBundesland: true })` -> localStorage `null`, kein API-Aufruf.
  - Eingeloggt: `saveSettings(s)` -> `api.saveSettings` mit `(s, activeProfileIdForApi, undefined)` oder passendem opts-Objekt; mit `clearBundesland` wird `opts` durchgereicht.
- [x] Impl: `mergeSettings` um `bundesland: normalizeBundesland(raw.bundesland)`; `saveSettings(settings, opts?)`.

### Schritt 4: Core `ApiClient.saveSettings`
- [x] Test `api-client.spec.ts` (Muster der vorhandenen `saveSettings`-Tests, HttpTestingController; vorab Ist-Test lesen):
  - Wert gesetzt (`'bayern'`) -> Body `bundesland: 'bayern'`.
  - `null` ohne Opt -> Body `bundesland: null` (explizit: **nie `""`**, `body.bundesland !== ''`).
  - `null` + `clearBundesland: true` -> `bundesland: ''`.
  - Gesetzter Wert + `clearBundesland: true` -> Wert bleibt (defensiv, kein `""`).
  - Übrige Felder (`weeklyTargetHours`, `workdays`, `vacationDaysPerYear`, ...) unverändert im Body; `profileId` als Query-Param wie bisher (`?profileId=...`, `default` -> kein/default-Verhalten wie bestehender Test).
- [x] Impl: Payload-Typ und Mapping `bundesland: opts?.clearBundesland && settings.bundesland === null ? '' : settings.bundesland`.

### Schritt 5: Feature-Service `SettingsPageService.setBundesland`
- [x] Test `settings.service.spec.ts` (Mock `saveSettings`; `getSettings: () => of(DEFAULT_SETTINGS)` kann auf variablen Wert erweitert werden, z. B. `of({...DEFAULT_SETTINGS, bundesland: 'bayern', weeklyTargetHours: 35})`):
  - `setBundesland('sachsen')` -> `saveSettings` mit `{...current, bundesland: 'sachsen'}` und **ohne** `clearBundesland` (zweites Argument `undefined` bzw. nicht gesetzt).
  - `setBundesland(null)` -> `saveSettings({...current, bundesland: null}, { clearBundesland: true })`.
  - Regression "nie `""` außer Abwahl": `setTargetHours`, `setVacationDays`, `setWorkdays` und `saveSettings` senden bei vorhandenem Bundesland `{...current}` (Bundesland `'bayern'` bleibt erhalten) und **ohne** `clearBundesland`; bei `bundesland: null` ebenfalls ohne `clearBundesland`.
  - Fehler: `saveSettings` rejects -> `setBundesland` rejects (Komponente fängt).
- [x] Impl: Platzhalter ersetzen; `SettingsPageService.saveSettings` bleibt ohne opts.

### Schritt 6: `DataSyncService`
- [x] Test `data-sync.spec.ts` (Basis: `current = DEFAULT_SETTINGS` mit `bundesland: null`; localStorage-Fixture wie vorhandene Tests):
  - lokal `bundesland: 'bayern'`, Cloud `null` -> `saveSettings` mit `{...current, bundesland: 'bayern'}`, ohne `clearBundesland`, `settingsSynced: true`.
  - lokal `'bayern'`, Cloud `'hessen'` -> kein Overwrite: `saveSettings` nicht aufgerufen (wenn sonst kein Patch) bzw. aufgerufen mit `bundesland: 'hessen'`, falls andere Felder im Patch (Test mit `weeklyTargetHours` zusätzlich).
  - lokal ungültig (`'xyz'`, `''`, `null`, `5`) -> kein Save wegen Bundesland; Aufruf-Argumente enthalten nie `bundesland: ''`.
  - Kombination mit anderen Feldern: ein Aufruf mit allen Patches.
  - Cloud-Fehler beim Speichern -> `result.errors` wie bestehender Fehlerfall.
- [x] Impl: im Settings-Block `const localBl = normalizeBundesland(local['bundesland'])`; Cloud-Wert erst lesen, wenn `localBl` gesetzt; Patch nur bei `current.bundesland === null`. Dafür `current` bei Bedarf einmal vorab per `firstValueFrom(getSettings())` laden (nur einmal, wiederverwenden). Bestehende Whitelist/Vacation-Logik unverändert. Kommentar "Cloud gewinnt, nie `""`".

### Schritt 7: Dialog + Settings-Component
- [x] Test `edit-bundesland-dialog.spec.ts`: Muster `edit-vacation-days-dialog.spec.ts` (MAT_DIALOG_DATA + MatDialogRef-Mock `close: vi.fn()`, TranslateService-Stub). Fälle: 17 Optionen (1 + 16) und Reihenfolge ("Nicht ausgewählt" zuerst); `control` initial = `data.current` (`null` bzw. `'bayern'`); `submit()` -> `close({ bundesland: 'bayern' })`; Auswahl "Nicht ausgewählt" -> `close({ bundesland: null })`; Abbrechen schließt ohne Ergebnis (Button `mat-dialog-close`); `cdkFocusInitial` steht bei `current = null` auf "Nicht ausgewählt", bei `current = 'bayern'` ausschließlich auf der Option `bayern` (nie zwei Elemente mit `cdkFocusInitial`).
- [x] Impl Dialog: `cdkFocusInitial` dynamisch auf die aktuelle Auswahl. In Angular kein bedingtes Attribut direkt: stattdessen pro `mat-radio-button` zwei Varianten per `@if (b === data.current) { ... cdkFocusInitial } @else { ... }` oder Alternative `cdkTrapFocus`-freier Ansatz: Fokus beim Öffnen per `MatDialogConfig.autoFocus: '.mat-mdc-radio-checked input'` in `openEditBundeslandDialog` (Selektor-String wird von `autoFocus` unterstützt) mit Fallback auf die erste Option; bei Wahl der Variante "autoFocus-Selektor" entfällt `cdkFocusInitial` im Dialog-Template. Implementierung entscheidet nach Test; Spec prüft das tatsächliche Verhalten (fokussiertes Element nach `fixture.detectChanges()`/Dialog-Open) und deckt den Fallback ab, falls kein Radio gecheckt ist ("Nicht ausgewählt" ist `null`-Wert und zählt als gecheckt).
- [x] Test `settings.spec.ts` (Component, `overrideComponent` Template leer, wie bestehend): `openEditBundeslandDialog` öffnet Dialog mit `data: { current: 'bayern' }` (bzw. `null`); `afterClosed` -> `{ bundesland: 'sachsen' }` -> `svc.setBundesland('sachsen')` + Snackbar `settings.bundesland.saved`; `{ bundesland: null }` -> `setBundesland(null)`; `undefined` (Abbrechen) -> kein `setBundesland`, keine Snackbar; `setBundesland` rejects -> Snackbar `settings.bundesland.saveError` (Duration 4000), keine Erfolgs-Snackbar, Komponente wirft nicht. Vorhandene Component-Tests (Vacation) bleiben grün.
- [x] Impl: `settings.ts` im Wesentlichen vorhanden; Anpassungen aus den Tests (z. B. autoFocus). `settings.html` unverändert, außer wenn die Tests Lücken zeigen.

### Schritt 8: Dashboard (`HolidayBanner` + `DashboardService.holidayToday`)
- [x] Test `holiday-banner.spec.ts`: Input `holiday = 'germanUnityDay'` -> Text enthält übersetzten Namen und Banner-Satz (TranslateService mit `TranslateTestingModule`/Stub-Loader und Mini-Dictionaries de/en inkl. `{{name}}`-Interpolation); `role="status"` gesetzt; Icon `aria-hidden="true"`; EN-Variante (langer Name "Repentance and Prayer Day") rendert vollständig; Wechsel des Inputs aktualisiert Text (OnPush via `fixture.componentRef.setInput`).
- [x] Test `dashboard.service.spec.ts` (NEU; Mocks für `WorkEntryService`, `OvertimeService`, `SettingsService` (`getSettings` über `BehaviorSubject<UserSettings>`), `AuthService`; Fake-Timer):
  - `vi.useFakeTimers()` + `vi.setSystemTime(new Date(2026, 9, 3, 12, 0))`, Settings `bundesland: 'nordrheinWestfalen'` -> `holidayToday() === 'germanUnityDay'`.
  - `bundesland: null` -> `null` auch an einem Feiertag (kein Nagging).
  - Normaler Tag (z. B. `new Date(2026, 9, 5, 12)`) -> `null`.
  - Reaktiv: Settings-Emission mit anderem Bundesland ändert das Ergebnis (Beleg an einem Landes-Feiertag: 2026-10-31 `reformationDay` für `sachsen` ja, `bayern` nein; 2026-01-06 `epiphany`).
  - Mitternacht: Start `new Date(2026, 9, 2, 23, 59, 30)` (kein Feiertag) -> `null`; `vi.advanceTimersByTime(31_000)` (oder `advanceTimersByTimeAsync`) -> `'germanUnityDay'`; danach nächster Timer geplant (Folgetag 4.10. -> `null`, Aufruf nach weiteren 24 h verändert Wert); Timer-Verzögerung mindestens 1 s.
  - DST-Tag: Start `new Date(2026, 2, 28, 23, 0)` (Vortag der Umstellung 29.3.2026) -> Timer feuert zur lokalen Mitternacht, `today` = `'2026-03-29'` (Test nur auf Key-Wirkung, über `holidayToday` mit fiktivem Feiertag nicht möglich; stattdessen `Date`-/Timer-Dauer mit `vi.getTimerCount()`/Verlauf prüfen; unter `TZ=Europe/Berlin` aussagekräftig, in UTC trivial, deshalb nur auf Konsistenz asserten, nicht auf 23 h oder 25 h hart kodieren).
  - `visibilitychange`: Systemzeit per `vi.setSystemTime(new Date(2026, 9, 3, 8))` hochsetzen, `Object.defineProperty(document, 'visibilityState', { value: 'visible', configurable: true })` + `document.dispatchEvent(new Event('visibilitychange'))` -> `holidayToday` aktualisiert; bei `hidden` keine Änderung.
  - Aufräumen: `TestBed`-Destroy (`TestBed.resetTestingModule()`) räumt Timer und `visibilitychange`-Listener ab: nach Destroy `vi.getTimerCount()` für den Mitternachts-Timer = 0 bzw. kein weiterer Treffer nach `advanceTimersByTime`; `removeEventListener` per Spy auf `document` geprüft.
  - Rein informativ: bei Feiertag + vorhandenem Eintrag aller Typen (`work` mit Zeiten, `vacation`, `sick`, `holiday`) bleiben `workEntry()`, `totalOvertime()`, `dailyOvertime()`, `expectedEndTime()` identisch zu einem Lauf ohne Bundesland (Vergleich zweier Services mit gleichen Mocks, Bundesland an/aus); kein zusätzlicher Aufruf an `workSvc.saveEntry`/Schreib-Methoden (`expect(...).not.toHaveBeenCalled()`).
- [x] Impl `DashboardService`: Platzhalter ersetzen (Import `GermanHoliday` und `DEFAULT_SETTINGS`, `toSignal` aus `@angular/core/rxjs-interop`). Bestehendes `getSettings()`-Subscription/`_settingsCache` unberührt.
- [x] Test `dashboard.spec.ts` (erweitern; bisher nur `goToSettings`): bei gemocktem `svc.holidayToday = signal('germanUnityDay')` und `isLoading = signal(false)` rendert `app-holiday-banner` oberhalb von `.dashboard-content`; bei `null` kein Banner; bei `isLoading = true` kein Banner (Spinner). Falls das Template im bestehenden Test per `overrideComponent` geleert wird, für diesen Fall ein eigener `describe` mit echtem Template und gestubbten Kindkomponenten.

### Schritt 9: Doku, i18n-Check, Gesamt-Checks
- [x] `web/CLAUDE.md`: Layer-Baum um `shared/utils/german-holidays.util.ts`, `shared/utils/bundesland.util.ts`, `shared/components/holiday-banner/` ergänzen; `settings.ts`-Zeile: Bundesland-Feld, Lösch-Semantik (`""` nur über `clearBundesland`); `data-sync.ts`: Settings-Migration inkl. Bundesland (Cloud gewinnt); Feature-Service-Tabelle unverändert (keine neuen Abhängigkeiten). Kurzer Absatz "Feiertage (#279)" mit Rechenregel (UTC-Felder, Schlüssel `YYYY-MM-DD`, Parität mit Mobile-Fixture).
- [x] i18n: de/en-Key-Parität per `diff <(jq -r 'paths(scalars)|join(".")' public/i18n/de.json|sort) <(... en.json|sort)`; alle im Code verwendeten Keys (`holidays.*` x17, `dashboard.holidayToday`, `settings.bundesland.*`, 16 `state.*`) vorhanden; Anrede duzen; Kalender-Wortlaut nicht enthalten.
- [x] Checks aus `web/`: `npm test -- --watch=false && TZ=Europe/Berlin npm test -- --watch=false && npm run build -- --configuration production`; lokal zusätzlich `TZ=America/New_York npm test -- --watch=false -- src/app/shared/utils/german-holidays.util.spec.ts` (bzw. passender Filter) und `TZ=UTC`.
- [x] Offene Sichtprüfung laut UI-Report (hell/dunkel, 360 px/Desktop, DE/EN, AXE-Kontrast) im Review; nicht Teil der Tests.

## Signal-Design

```typescript
// DashboardService (Ergänzung, kein Refactoring des Bestands)
private readonly settings = toSignal(this.settingsSvc.getSettings(), { initialValue: DEFAULT_SETTINGS });
private readonly _today   = signal<string>(toDateKey(new Date()));      // 'YYYY-MM-DD', lokale Felder

readonly holidayToday = computed<GermanHoliday | null>(() => {
  const land = this.settings().bundesland;
  if (!land) return null;
  const key = this._today();
  return getGermanHolidayIds(Number(key.slice(0, 4)), land).get(key) ?? null;
});

// Tageswechsel (im Konstruktor, über DestroyRef aufgeräumt)
// refreshToday(): _today.set(toDateKey(new Date()))   // signal ist bei gleichem String idempotent
// scheduleMidnight(): clearTimeout(handle); delay = max(1000, new Date(y, m, d + 1).getTime() - Date.now());
//                     handle = setTimeout(() => { refreshToday(); scheduleMidnight(); }, delay)
// visibilitychange (bestehender Listener erweitern ODER zweiter benannter Listener):
//   bei 'visible' -> refreshToday() + scheduleMidnight() neu planen (Browser-Throttling); Bestandslogik (Timer-Recalc) unverändert
// destroyRef.onDestroy: clearTimeout(handle) + document.removeEventListener('visibilitychange', handler)
```
Hinweis: Der bestehende Listener ist eine anonyme Funktion ohne Remove; für das Aufräumen den Chip-Teil als eigenen benannten Listener anlegen (Bestandsverhalten nicht anfassen). `initialValue: DEFAULT_SETTINGS` -> `bundesland: null`, kein Chip vor dem ersten Snapshot (kurzer Sprung eingeloggt akzeptiert).

```typescript
// SettingsService (core) — Signatur
saveSettings(settings: UserSettings, opts?: { clearBundesland?: boolean }): Promise<void>

// SettingsPageService
async setBundesland(value: Bundesland | null): Promise<void> {
  const current = this.settings();
  if (value === null) await this.coreSettings.saveSettings({ ...current, bundesland: null }, { clearBundesland: true });
  else                await this.coreSettings.saveSettings({ ...current, bundesland: value });
}
```
Component-Muster unverändert (OnPush, `protected readonly svc = inject(...)`, kein `standalone: true`).

## Risiken und Hinweise für die Implementierung
- Ganz-Objekt-PUT: `""` darf nie außerhalb `setBundesland(null)` entstehen; Absicherung durch die Tests in Schritt 4 bis 6.
- `iso-week.util.addCalendarDays` liefert lokale Daten und darf nicht für Feiertagsschlüssel verwendet werden.
- Fake-Timer plus `toSignal`/`effect`/RxJS: `vi.useFakeTimers({ toFake: ['setTimeout', 'clearTimeout', 'Date'] })` verwenden, falls `interval`/Microtasks des restlichen Dashboards stören; sonst Standard.
- Bestehender `DashboardService`-Konstruktor ruft `effect(() => this._init())` auf: in der neuen Spec `getTodayEntry`, `getOvertime`, `getLastUpdateDate`, `getSettings` vollständig mocken, sonst Unhandled Rejections.
- Tageswechsel des restlichen Dashboards (Eintrag, Soll) bleibt außerhalb des Scopes: im Review-Hinweis/PR als Folge-Issue vermerken, ebenso Kalender-Markierung im Web-Reports-Kalender.
- Fixture muss bei Änderungen der Mobile-Fixture manuell nachgezogen werden (Hinweis im Spec-Kopf).
