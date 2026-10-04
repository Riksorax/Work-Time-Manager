# Web-Research: #371 — Feiertage im Reports-Kalender markieren
Datum: 2026-10-04
Feature-Ordner: web/src/app/shared/components/calendar/ (Component) + web/src/app/features/reports/ (Datenversorgung)

## Flutter-Quelle
Dateien: `mobile/lib/presentation/screens/reports_page.dart` (`_CalendarState`, ca. Z. 1965-2215), ARB `bundeslandNotSelected` (de: "... in Kalender und Dashboard"), `holidaySemanticSuffix` (de: ", Feiertag: {name}"), `holiday_name_localizer.dart`.
Screens/ViewModels: Reports-Kalender (Tab "Täglich").

## Feature-Verständnis
Mobile: `getGermanHolidayIds(selectedDate.year, bundesland)` -> Map; Tageszahl rot + fett, Tooltip mit lokalisiertem Namen, Semantics-Label `<Datum>, Feiertag: <Name>`. Rein visuell, keine `WorkEntryType.holiday`-Einträge, keine Auswirkung auf Soll/Überstunden. Ohne Bundesland keine Markierung. Auswahlfarbe (weiß) hat Vorrang vor Rot.

## Ist-Stand Web
- Kalender: eigene Komponente `CalendarComponent` (`shared/components/calendar/calendar.ts`, Inline-Template + Inline-Styles, kein Material Datepicker, kein `dateClass`). Eigenes CSS-Grid (7 Spalten), `div.calendar-day[role=gridcell][data-date]`, runde Zellen, Klasse `selected/today/has-entry/multi-selected`, Eintragspunkt `.entry-dot`. Pointer-Events auf Card-Ebene (Tap + Drag-Multiselect über `document.elementFromPoint` + `[data-date]`) — ein natives `title`/Tooltip-Element in der Zelle stört das nicht, solange es kein eigenes Pointer-Handling braucht. Es gibt KEIN `calendar.spec.ts`.
- Gerendert in `features/reports/reports.html` (Tab "Täglich", `<app-calendar ...>`), einziger Verwender. Monat hält die Komponente selbst (`viewDate`), meldet `monthChanged` an `ReportsService.onMonthChanged` (lädt Einträge neu). `daysWithEntries` ist nur `number[]` von Tagesnummern.
- Gating: Täglich-Tab ist weder Premium- noch Auth-gated (anonym: localStorage). Wöchentlich/Monatlich sind Premium+Login, Jahr frei. Feiertage im Kalender sind also automatisch ein Free-Feature, solange nur die Daten ins Kalender-Input kommen. Die Wochen-/Monats-Day-Listen (`day-row`) sind NICHT Teil des Issues (nur "Monatsansicht" des Kalenders).
- Einstellungen: `ReportsService._settings` (privat, `toSignal(settingsService.getSettings())`, Fallback `DEFAULT_SETTINGS`) enthält bereits `bundesland`. `SettingsService.getSettings()` ist `combineLatest([auth.user$, workProfile.activeProfileId$])` -> reagiert automatisch auf Login und Profilwechsel (Profil-Scoping gratis). `ReportsService` hat dafür aber noch kein öffentliches Signal.
- Hinweistext: `settings.bundesland.hint` ("Für Feiertage im Dashboard") und `notSelectedHint` ("Nicht ausgewählt – keine Feiertage im Dashboard") in `public/i18n/de.json` Z. 251-252 und `en.json` Z. 251-252, gerendert in `settings.html` Z. 126-127. Auch der Kommentar am Feld in `shared/models/index.ts` Z. 40 ("Feiertage im Dashboard") nachziehen.
- `holidays.<id>` (17 Keys) existiert in de/en. Kein Äquivalent zu Mobile `holidaySemanticSuffix` -> neuer Key nötig.
- TZ: CI führt `TZ=Europe/Berlin npm test -- --watch=false` bereits aus (`ci.yml` Z. 104).

## Domain-Mapping
| Flutter | Angular | Datei |
|---|---|---|
| `getGermanHolidayIds` | vorhanden | shared/utils/german-holidays.util.ts |
| `holidayIds` im `_CalendarState` | neuer Input `holidays: Map<string, GermanHoliday>` (Key `YYYY-MM-DD`) oder `bundesland` + computed im Calendar | calendar.ts |
| Settings-Zugriff | `ReportsService.bundesland` computed (aus `_settings`) | reports.service.ts |
| `holidayName.localizedName(l10n)` | `translate.instant('holidays.' + id)` bzw. Pipe | calendar.ts |

## Designempfehlung
- Input-Design (empfohlen): `CalendarComponent` bekommt `bundesland = input<Bundesland | null>(null)` und berechnet intern `computed(() => bundesland ? getGermanHolidayIds(viewDate().getFullYear(), bundesland) : empty)`. Grund: Die Komponente kennt den angezeigten Monat/das Jahr selbst (`viewDate`); `ReportsService` müsste sonst Jahr-Tracking duplizieren. Das Jahr kommt aus `viewDate`, nicht aus `selectedDate` (Mobile nutzt `selectedDate.year`, was beim Blättern über Jahreswechsel nur stimmt, weil dort selectedDate mitwandert). Pro Zelle `holidayFor(day.date)` = `map.get(dayKey(date))` (Zellen-Key via vorhandenes `toKey`/`toDateKey`, lokale Felder).
- Reports: `ReportsService.bundesland = computed(() => this._settings().bundesland ?? null)` (readonly), im Template `[bundesland]="svc.bundesland()"`.
- Jahr-/Monatswechsel: durch `viewDate`-Signal automatisch (Dez->Jan = neues Jahr). Profilwechsel: durch `getSettings()` automatisch; Kalender-`viewDate` bleibt.
- Darstellung (nicht nur Farbe, WCAG AA):
  - Tageszahl fett + `color: var(--mat-sys-error)` (analog Mobile rot; M3-Token, Dark-Mode-fest) ODER `tertiary` (wie Holiday-Banner `--mat-sys-tertiary-container`) — Empfehlung: Banner-Konsistenz nutzen: kleiner Indikator statt nur Farbe, z. B. Unterstrich/Punkt in `--mat-sys-tertiary` oder `--mat-sys-error`. Kontrast gegen `--mat-sys-surface-container-low` prüfen (Light + Dark). Mobile ist rot; Parität-Entscheidung siehe Frage 2.
  - Bei `.selected` (`--mat-sys-primary` Hintergrund) und `.multi-selected` behält die Zahl `--mat-sys-on-primary` / `on-secondary-container` (wie Mobile: Auswahl schlägt Rot), Feiertag bleibt über Fettdruck + Tooltip/aria erkennbar.
  - Kollision mit `.entry-dot` (Punkt unten, 4px): Feiertag-Indikator nicht an derselben Stelle (z. B. fett + Farbe + kleiner Punkt/Ring oben oder `text-decoration: underline dotted`).
  - Tooltip: `[attr.title]="name"` ist einfachste, tastatur-/touch-schwache Lösung; `matTooltip` (MatTooltipModule, `[matTooltip]`, `matTooltipDisabled` wenn kein Feiertag) ist konsistenter, aber Zellen sind keine Fokus-Elemente (div gridcell, ohne tabindex). Siehe Risiko Tastatur.
  - A11y: `aria-label` der Zelle = `date | 'd. MMMM yyyy'` + bei Feiertag `shared.calendarHolidayAria` (z. B. "{{date}}, Feiertag: {{name}}"). Neuer i18n-Key (de/en), kein ", Feiertag:" hart kodieren. Nicht-Farbe-Indikator zusätzlich `aria-hidden`.
- Interaktion Eintragstyp `holiday` (`WorkEntryType.Holiday`, manueller Eintrag; zählt in Report-Calculator wie Urlaub/Krank als Nicht-Arbeit, `entry.type !== Work`): Bundesland-Feiertag ist rein visuell (wie Mobile) — keine Einträge erzeugt, keine Soll-/Überstundenänderung, kein Konflikt: Zelle kann gleichzeitig Feiertag (Markierung) und `has-entry` (Punkt) sein; Tagesliste zeigt Eintragstyp-Badge "Feiertag", Kalender zeigt Namen. Kein Dedup nötig. Optional: im Tagespanel (day-header) den Feiertagsnamen anzeigen (Mobile macht das nicht -> außerhalb Scope). Risiko: Nutzer könnte denken, der Feiertag zähle automatisch als frei; Hinweis im Settings-Text unnötig, Verhalten identisch zu Mobile.

## UI-States
| State | Flutter | Angular |
|---|---|---|
| Loading | Reports lädt | `svc.isLoading()` -> Spinner (Kalender nicht gerendert) |
| Bundesland nicht gewählt | keine Markierung | Input `null` -> keine Markierung |
| Feiertag | rot+fett, Tooltip, Semantics | Klasse `holiday`, Tooltip, aria-label |
| Feiertag + selected | weiß | `on-primary` + fett |
| Feiertag + Eintrag | roter Text + Punkt | Klasse `holiday` + `.entry-dot` |
| Settings-Fehler | Fallback | `DEFAULT_SETTINGS` (bundesland null) |

## i18n-Änderungen (de + en)
- `settings.bundesland.hint`: "Für Feiertage im Dashboard und Kalender" / "Used for public holidays in the dashboard and calendar".
- `settings.bundesland.notSelectedHint`: "Nicht ausgewählt – keine Feiertage in Kalender und Dashboard" (exakt wie Mobile `bundeslandNotSelected`) / "Not selected – no public holidays in the calendar and dashboard".
- Neu `shared.calendarHolidayAria` (de: "{{date}}, Feiertag: {{name}}", en: "{{date}}, public holiday: {{name}}").
- Kommentar `UserSettings.bundesland` in models/index.ts ("im Dashboard und Kalender").
- Prüfen, ob Settings-Spec die alten Hinweistexte assertet (Grep ergab keine Treffer in .ts, nur Keys).

## Tests (TZ-unabhängig, feste Daten)
- Neu `calendar.spec.ts` (existiert nicht): `provideTranslateService` + `setTranslation` wie `holiday-banner.spec.ts`; `selectedDate` fix (z. B. `new Date(2026, 9, 15)`), `bundesland='bayern'`; Zelle `[data-date="2026-10-03"]` hat Klasse `holiday` + aria-label mit "Tag der Deutschen Einheit"; `2026-10-31` nur bei `brandenburg`/nicht bei `bayern`; `bundesland=null` -> keine Markierung; Monatswechsel Dez 2026 -> Jan 2027 (`2027-01-01` Neujahr; `2027-01-06` nur bayern); Sachsen Buß- und Bettag `2026-11-18`; en-Name via `translate.use('en')`; Feiertag + `daysWithEntries` -> Punkt vorhanden; `selected` Zelle behält Fett/kein Rot-Override.
- `reports.service.spec.ts` (Mock `getSettings: () => of({...DEFAULT_SETTINGS, bundesland: 'bayern'})`): `svc.bundesland()` Signal; Profil-/Auth-Reaktivität gilt über SettingsService-Spec bereits.
- Datumsableitung nur mit Konstruktor `new Date(y, m, d)` (nie `toISOString`, nie `new Date()` ohne Fake-Timer); CI läuft schon mit `TZ=Europe/Berlin`; optional lokal zusätzlich `TZ=America/Los_Angeles` und `Pacific/Auckland` prüfen.

## Offene Fragen
1. Farbe/Indikator: Mobile-Parität (rot, `--mat-sys-error`) oder Web-Banner-Look (tertiary)? Empfehlung: `--mat-sys-error` + Fettdruck + zusätzlich nicht-farbiger Indikator (Punkt/Unterstrich), da WCAG "nicht nur Farbe" und AXE.
2. Tooltip-Technik: natives `title` (einfach, kein Fokus) vs. `matTooltip`. Empfehlung: `matTooltip` (konsistent mit Material) + aria-label als eigentliche A11y-Quelle; Zellen bleiben ohne tabindex (Kalender ist bisher nicht per Tastatur bedienbar — bestehende Lücke, nicht Teil von #371; separat melden?).
3. Soll der Feiertagsname zusätzlich im Tagespanel (`day-header`) für den gewählten Tag erscheinen? Empfehlung: nein (Parität, Scope), eventuell Folge-Issue; auf Touch ist Tooltip schwer erreichbar.
4. Soll `app-calendar` `bundesland` (Calendar rechnet) oder `holidays`-Map (Parent rechnet) erhalten? Empfehlung: `bundesland`-Input (Jahr aus `viewDate`).
5. Wochen-/Monatsliste (`day-row`, Premium) ebenfalls markieren? Empfehlung: außerhalb Scope des Issues ("Kalender, Monatsansicht").

## Risiken
- Jahr falsch bei Monatswechsel: vermeiden, Jahr aus `viewDate()` statt `selectedDate()`.
- Klick/Drag: neue Kind-Elemente (Tooltip-Directive) dürfen `document.elementFromPoint(...).closest('[data-date]')` nicht brechen -> Tooltip an der Zelle selbst, keine Overlay-Elemente in der Zelle; Test: Tap/Drag bleibt funktionsfähig.
- Zellen-Kontrast Selected+Feiertag, Dark Mode: nur `--mat-sys-*`-Tokens nutzen; Light/Dark visuell prüfen.
- `matTooltip` + `touch-action: none` / `user-select: none` auf der Card: Long-Press-Tooltip auf Touch evtl. unzuverlässig -> aria-label bleibt Hauptweg.
- Hartkodiertes `weekDays`-Array via `translate.instant` bei Init (bestehend), nicht reaktiv auf Sprachwechsel — bestehender Mangel; Namen/aria für Feiertage reaktiv über Pipe/`translate.instant` im Template-Aufruf lösen (Pipe-Aufruf mit `translate`-Pipe auf zusammengesetztem Key, wie im Banner).
- Per-Zellen-Aufrufe in Template: Lookup in `computed`-Map (O(1)), kein Neuberechnen pro Change Detection.
- Backend-/Firestore-Arbeit: keine nötig (Rules, Endpunkte unberührt; `bundesland` liegt bereits in `settings/current` bzw. Profil-Pfad).

## Entscheidungen zu den offenen Fragen (Hauptsession)

Alle Empfehlungen übernommen: (1) Feiertage im Kalender in Error-Farbe (`--mat-sys-error`) plus fett plus nicht-farbiger Indikator (nicht kollidierend mit `.entry-dot`), Auswahlfarbe gewinnt bei selected/multi-selected; (2) `matTooltip` mit Feiertagsname, `aria-label` über neuen Key `shared.calendarHolidayAria` (de/en) als eigentliche A11y-Quelle; die fehlende Tastatur-Fokussierbarkeit der Kalenderzellen ist eine bestehende Lücke und kommt als eigenes Folge-Issue (von der Hauptsession angelegt); (3) Feiertagsname nicht zusätzlich im Tagespanel (Folge-Thema, kein Issue nötig); (4) `CalendarComponent` bekommt `bundesland`-Input und berechnet die Map aus dem Jahr des angezeigten Monats (`viewDate().getFullYear()`, inkl. Jahreswechsel Dez→Jan); `ReportsService` exponiert ein öffentliches `bundesland`-Computed; (5) Wochen-/Monatslisten (`day-row`) werden nicht markiert. Bundesland-Feiertag bleibt rein visuell (kein Eintrag, kein Soll), darf mit dem Eintragspunkt zusammen auftreten. i18n: `settings.bundesland.hint` → „… im Dashboard und Kalender", `notSelectedHint` → „… keine Feiertage in Kalender und Dashboard" (de/en), Kommentar in `models/index.ts` anpassen; neuer Key `shared.calendarHolidayAria`. Tests: neues `calendar.spec.ts` mit festen Daten (Bayern 2026-10-03, 2026-10-31 nur Brandenburg, Sachsen Buß- und Bettag 2026-11-18, Jahreswechsel Dez 2026 → Jan 2027, bundesland null, en-Namen) plus ReportsService-Signal-Test, auch unter `TZ=Europe/Berlin`.
