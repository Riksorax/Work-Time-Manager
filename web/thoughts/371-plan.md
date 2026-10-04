# Web-Plan: #371 — Feiertage im Reports-Kalender markieren
Erstellt: 2026-10-04
Research: web/thoughts/371-research.md (inkl. "Entscheidungen zu den offenen Fragen")
UI-Report: entfällt — UI-Details stehen im Abschnitt "UI-Details" unten.

## Ziel
Der Kalender im Reports-Tab "Täglich" markiert gesetzliche Feiertage des in den Einstellungen gewählten Bundeslands (Parität zu Mobile `_CalendarState`): Tageszahl fett, Error-Farbe, nicht-farbiger Indikator, Tooltip mit Namen, `aria-label` mit Feiertagsname. Rein visuell — keine Einträge, kein Einfluss auf Soll/Überstunden.

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Hybrid-Service nötig? | nein | `SettingsService.getSettings()` liefert `bundesland` bereits, inkl. Auth-/Profil-Reaktivität |
| Neuer Domain-Service? | nein | `getGermanHolidayIds` (shared/utils/german-holidays.util.ts) existiert (#279) |
| Premium-Gate? | nein | Täglich-Tab ist frei; Feiertage damit Free-Feature (wie Dashboard-Banner) |
| Routing-Änderung? | nein | |
| Neuer API-Endpunkt? | nein | Backend/Firestore unberührt |
| Neuer Firestore-Pfad? | nein | Keine Rules-Änderung |
| Neue Texte? | ja | `shared.calendarHolidayAria`; Texte `settings.bundesland.hint` / `notSelectedHint` angepasst (de + en, geduzt/neutral wie bestehend) |
| Shared Component? | bereits | `CalendarComponent` ist shared, einziger Verwender Reports |

Abweichungen vom Naheliegenden:
- Input heißt `bundesland` (nicht fertige Map): Calendar kennt `viewDate` selbst, Jahr aus `viewDate().getFullYear()`, nicht aus `selectedDate` (Jahreswechsel Dez→Jan beim Blättern).
- Der Kalender ist nicht fokussierbar (bestehende Lücke, eigenes Folge-Issue) — hier bewusst kein `tabindex`. `aria-label` ist die A11y-Quelle, `matTooltip` nur Zusatz für Maus.
- Wochen-/Monatslisten (`day-row`) und Tagespanel bleiben unverändert.

## Neue / geänderte Dateien

### Domain / Shared Layer
```
web/src/app/shared/models/index.ts            # nur Kommentar an UserSettings.bundesland (Z. ~40): "Feiertage im Dashboard und Kalender"
web/public/i18n/de.json                       # shared.calendarHolidayAria (neu), settings.bundesland.hint + notSelectedHint (geändert)
web/public/i18n/en.json                       # dito
```
Keine neue Domain-Logik, `german-holidays.util.ts` bleibt unverändert.

### Core Layer
Keine Änderung.

### Feature Layer
```
web/src/app/features/reports/reports.service.ts        # + public readonly bundesland = computed(...)
web/src/app/features/reports/reports.service.spec.ts   # + Test(s) für bundesland()
web/src/app/features/reports/reports.html              # + [bundesland]="svc.bundesland()" an <app-calendar>
web/src/app/shared/components/calendar/calendar.ts     # Input, computed Map, Template-/Style-Änderungen, MatTooltipModule-Import
web/src/app/shared/components/calendar/calendar.spec.ts  # NEU (existiert nicht)
web/CLAUDE.md                                          # Doku (siehe Schritt 6)
```

## UI-Details (statt UI-Report)

Template (`calendar.ts`, Inline) pro Tageszelle:
- `@let holiday = holidayFor(day.date);` (liefert `GermanHoliday | null`) und `@let holidayName = holiday ? ('holidays.' + holiday | translate) : '';` — Pipe-Aufruf im Template, damit Sprachwechsel reaktiv ist (anders als das bestehende `weekDays`-Init).
- `[class.holiday]="holiday !== null"`.
- `[attr.aria-label]`: ohne Feiertag unverändert `day.date | date:'d. MMMM yyyy'`; mit Feiertag `'shared.calendarHolidayAria' | translate: { date: (day.date | date:'d. MMMM yyyy'), name: holidayName }` (Ternary im Template, Variable per `@let ariaDate`).
- `[matTooltip]="holidayName"` und `[matTooltipDisabled]="holiday === null"` direkt am Zellen-`div` (kein Overlay-Kind in der Zelle; `document.elementFromPoint(...).closest('[data-date]')` bleibt intakt). `MatTooltipModule` in `imports` ergänzen.
- Kein zusätzliches Kindelement für den Indikator nötig (Unterstrich ist reines CSS, daher nichts für Screenreader doppelt). Falls doch ein Element: `aria-hidden="true"`.

SCSS (im Inline-`styles`, innerhalb `.calendar-day`):
- `&.holiday { font-weight: 700; text-decoration: underline; text-decoration-thickness: 2px; text-underline-offset: 3px; }` — Fett + Unterstrich = nicht-farbiger Indikator (WCAG 1.4.1). Unterstrich liegt am Text, kollidiert nicht mit `.entry-dot` (absolut `bottom: 6px`).
- `&.holiday:not(.selected):not(.multi-selected) { color: var(--mat-sys-error); }` — nach der `.today`-Regel platziert, gleiche Spezifität; Feiertag-Farbe gewinnt über `.today`-Primärfarbe, der Heute-Rahmen (`border`) bleibt.
- `.selected` / `.multi-selected` behalten `--mat-sys-on-primary` / `--mat-sys-on-secondary-container` (Auswahlfarbe hat Vorrang); Fett + Unterstrich + Tooltip/aria bleiben sichtbar.
- Dark Mode/Kontrast: ausschließlich `--mat-sys-*`-Tokens (`--mat-sys-error` wechselt mit `.dark-theme` mit). Erwartet >= 4.5:1 gegen `--mat-sys-surface-container-low` und `-high` (Hover). Im Schritt 5 in Hell + Dunkel manuell prüfen; falls zu schwach, `--mat-sys-error` nicht durch Hardcode ersetzen, sondern Fettdruck/Unterstrich beibehalten und Kontrast melden.
- `.entry-dot` nutzt `currentColor` → bei Feiertag + Eintrag wird der Punkt rot, ok (Parität Mobile).

i18n (de / en):
| Key | de | en |
|---|---|---|
| `shared.calendarHolidayAria` (neu, neben `calendarNextMonthAria`) | `{{date}}, Feiertag: {{name}}` | `{{date}}, public holiday: {{name}}` |
| `settings.bundesland.hint` | `Für Feiertage im Dashboard und Kalender` | `Used for public holidays in the dashboard and calendar` |
| `settings.bundesland.notSelectedHint` | `Nicht ausgewählt – keine Feiertage in Kalender und Dashboard` | `Not selected – no public holidays in the calendar and dashboard` |

Geduzt: Die Texte enthalten keine Anrede; kein "Sie" verwenden. Namen kommen aus bestehenden `holidays.<id>`-Keys (17, de/en vorhanden).

## Implementierungsschritte (TDD-First)

### Schritt 1: i18n-Keys und Kommentar (kein Verhalten, Voraussetzung für Specs)
- [ ] Test-Vorab: `grep` auf Specs, die die alten Hinweistexte asserten (Research: keine Treffer) — bei Treffer Spec zuerst anpassen.
- [ ] `de.json` + `en.json`: Key `shared.calendarHolidayAria` ergänzen, beide Settings-Hinweise ändern.
- [ ] Kommentar `bundesland` in `shared/models/index.ts` anpassen.
- [ ] Prüfen, dass de/en dieselben Key-Sets haben (falls vorhandener i18n-Paritätstest, laufen lassen).

### Schritt 2: ReportsService — öffentliches `bundesland`-Computed
- [ ] Test (`reports.service.spec.ts`): SettingsService-Mock mit `getSettings: () => of({ ...DEFAULT_SETTINGS, bundesland: 'bayern' })` → `svc.bundesland()` ist `'bayern'`; Mock mit `DEFAULT_SETTINGS` → `null`; Mock mit `throwError` → `null` (Fallback `DEFAULT_SETTINGS`). Bestehende Setup-Helfer wiederverwenden; ggf. Provider-Factory parametrisieren.
- [ ] Impl: `readonly bundesland = computed(() => this._settings().bundesland ?? null);` (Typ `Bundesland | null`), nahe `_settings`; Import `Bundesland` nur falls Typannotation nötig.

### Schritt 3: CalendarComponent — Logik (Input + Map)
- [ ] Neu `calendar.spec.ts`. Setup: `TestBed` mit `CalendarComponent`, `provideTranslateService` + `TranslateService.setTranslation('de', {...})` / `('en', {...})` wie `holiday-banner.spec.ts` (Keys `holidays.*` für benötigte IDs, `shared.calendarHolidayAria`, `common.weekdaysShort`, `shared.calendar*Aria`), `provideNoopAnimations` falls für Tooltip/Material nötig. `fixture.componentRef.setInput(...)` für `selectedDate = new Date(2026, 9, 15)`, dann `fixture.detectChanges()`. Helfer `cell(key)` = `fixture.nativeElement.querySelector('[data-date="…"]')`.
- [ ] Tests (alle mit festen Daten; falls `isToday` relevant, `vi.useFakeTimers(); vi.setSystemTime(new Date(2026, 9, 15, 12))`, in `afterEach` `vi.useRealTimers()`; nie `new Date()` ohne Fake-Timer, nie `toISOString`):
  1. `bundesland='bayern'`, Okt 2026: `2026-10-03` hat Klasse `holiday`, aria-label enthält "Tag der Deutschen Einheit"; `2026-10-04` nicht.
  2. `2026-10-31` (Reformationstag): `holiday` bei `brandenburg`, nicht bei `bayern` (Input per `setInput` wechseln).
  3. `bundesland=null` (Default) → keine Zelle mit `holiday`.
  4. Sachsen, Nov 2026: `2026-11-18` (Buß- und Bettag) `holiday`; bei `bayern` nicht (Monat via `changeMonth(1)` oder `selectedDate` im November).
  5. Jahreswechsel: `selectedDate = new Date(2026, 11, 15)`, `bayern`; `changeMonth(1)` + `detectChanges` → `2027-01-01` (Neujahr) `holiday`, `2027-01-06` (Heilige Drei Könige) `holiday` bei `bayern`, nicht bei `berlin`. Beweist Jahr aus `viewDate`, nicht aus `selectedDate`.
  6. Rückwärts: Jan 2027 → `changeMonth(-1)` → Dez 2026 `2026-12-25` `holiday`.
  7. en-Name: `translate.use('en')` → aria-label enthält englischen Namen und "public holiday".
  8. Feiertag + `daysWithEntries=[3]` → `.entry-dot` in `2026-10-03` vorhanden und Klasse `holiday` bleibt (kein Konflikt).
  9. `selectedDate = new Date(2026, 9, 3)`, `bayern`: Zelle hat `selected` UND `holiday` (Klassen); Styling-Vorrang ist CSS — nur Klassenkombination prüfen (computed style in jsdom unzuverlässig).
  10. `matTooltipDisabled`: Nicht-Feiertagszellen haben unverändertes `aria-label` (nur Datum), Feiertagszellen das Aria-Format.
  11. Regression Pointer: `onCardPointerDown` mit gestubbtem `document.elementFromPoint` → Zelle mit Tooltip-Direktive liefert weiter `data-date` (Tap emittiert `dateSelected`).
- [ ] Impl in `calendar.ts`: `readonly bundesland = input<Bundesland | null>(null);` (Import `Bundesland` aus `../../models`, `getGermanHolidayIds`, `GermanHoliday` aus `../../utils/german-holidays.util`);
  `private readonly holidayMap = computed(() => { const b = this.bundesland(); return b ? getGermanHolidayIds(this.viewDate().getFullYear(), b) : EMPTY_MAP; });` (Modul-Konstante `EMPTY_MAP = new Map<string, GermanHoliday>()`); `holidayFor(date: Date): GermanHoliday | null { return this.holidayMap().get(toKey(date)) ?? null; }`. Hinweis: Dezember-Ansicht zeigt nur Dezember-Tage, daher reicht ein Jahr; kein Vor-/Folgejahr nötig.

### Schritt 4: CalendarComponent — Template und Styles
- [ ] Tests aus Schritt 3 (Klassen, aria-label) decken Template ab; ergänzend Test: `matTooltip`-Disabled-Zustand nicht per Overlay testen (Overlay in jsdom fragil) — stattdessen aria/Klasse.
- [ ] Impl: Template-/SCSS-Änderungen gemäß "UI-Details", `MatTooltipModule` in `imports`. Bestehende Selektoren/Pointer-Handler unverändert.

### Schritt 5: Verdrahtung in Reports + visuelle Prüfung
- [ ] Test (`reports.spec.ts`, falls vorhanden und Kalender gerendert; sonst im Calendar-Spec ausreichend): `app-calendar` erhält `bundesland` aus `svc.bundesland()`. Wenn kein Component-Spec existiert, keinen neuen Aufbau erzwingen — Schritt 2 + 3 decken die Datenkette.
- [ ] `reports.html` Z. 17-25: `[bundesland]="svc.bundesland()"` ergänzen (neben `[daysWithEntries]`).
- [ ] Manuell: `npm start`, Bundesland setzen/abwählen (Markierung erscheint/verschwindet ohne Reload), Profilwechsel, Hell/Dunkel, Auswahl auf Feiertag, Feiertag mit Eintrag, Touch-Drag über Feiertage, Monatsblättern über Jahreswechsel. AXE-Check (Browser-Extension) auf Reports.

### Schritt 6: Doku und Gesamtchecks
- [ ] `web/CLAUDE.md`: Zeile `calendar/` im Layer-Baum → "CalendarComponent — Multi-Select + Pointer-Drag, Feiertags-Markierung per `bundesland`-Input (#371)"; Abschnitt "Feiertage (#279)" um Satz ergänzen: Kalender (Reports, Täglich) markiert Feiertage rein visuell (fett, `--mat-sys-error`, Unterstrich, `matTooltip`, `aria-label` via `shared.calendarHolidayAria`); Jahr aus dem angezeigten Monat (`viewDate`); `ReportsService.bundesland` reicht die Einstellung durch; Wochen-/Monatslisten nicht markiert; Auswahlfarbe hat Vorrang. In der Tabelle der Feature-Services keine Änderung.
- [ ] `cd web && TZ=Europe/Berlin npm test -- --watch=false` (wie CI, #364), zusätzlich lokal `TZ=America/Los_Angeles` und `TZ=Pacific/Auckland` für `calendar.spec.ts` + `reports.service.spec.ts`.
- [ ] `npm run build -- --configuration production`.

## Signal-Design

```typescript
// ReportsService (Ergänzung)
readonly bundesland = computed<Bundesland | null>(() => this._settings().bundesland ?? null);

// CalendarComponent (Ergänzung)
readonly bundesland = input<Bundesland | null>(null);
private readonly holidayMap = computed(() => /* bundesland() + viewDate().getFullYear() → Map<'YYYY-MM-DD', GermanHoliday> | EMPTY_MAP */);
holidayFor(date: Date): GermanHoliday | null  // O(1)-Lookup über holidayMap(), Key via toKey (lokale Felder)
```
Abhängigkeiten: `viewDate` (Monat/Jahr, Dez→Jan automatisch), `bundesland` (Settings/Profil/Login via `getSettings()`). Pro Zelle nur Map-Lookup, keine Neuberechnung der Feiertage pro Change Detection. Kein Hybrid-Muster nötig.

## Risiken / Hinweise
- `touch-action: none` / `user-select: none` auf der Card: Long-Press-Tooltip auf Touch evtl. unzuverlässig → `aria-label` bleibt Hauptweg; Tooltip ist Zusatz.
- `isToday` nutzt `new Date()`; Specs mit Feiertag + Today-Rahmen nur mit `vi.setSystemTime`.
- `weekDays` (bestehend) nicht reaktiv auf Sprachwechsel — nicht Teil von #371.
- Backend/Rules/Mobile: keine Arbeit.
