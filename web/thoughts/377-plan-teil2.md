# Web-Plan: #377 Teil 2 — Mehrfachauswahl per Tastatur im Kalender (Button + Shift+Pfeil)
Erstellt: 2026-10-05
Research: web/thoughts/377-research-teil2.md (inkl. "Entscheidungen zu den offenen Fragen (Hauptsession)", gilt vor allem anderen), ergänzt 377-research.md / 377-plan.md (Teil 1, gemergt als #401)
UI-Report: entfällt (kein Flutter-Port; Button-Konzept steht in Research, Abschnitt 3)

## Ziel
Der Mehrfachmodus ist ohne Maus erreichbar: sichtbarer Toggle "Mehrfachauswahl" über dem Kalender UND Shift+Pfeil/Home/End/PageUp/PageDown
als Abkürzung (Bereich mit Anker erweitern/verkleinern/umkehren), Escape beendet den Modus, Screenreader hören Modus und Anzahl.
Ein PR, Commits je Schicht (Service, Util, Kalender, Reports-Verdrahtung, i18n, Doku). Pointer-/Drag-Vertrag bleibt unverändert.
`Closes`/`Refs #377`: nach Maintainer-Entscheid (Teil 1 ist gemergt; Empfehlung `Closes #377` erst nach manueller Prüfung).

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Hybrid-Service nötig? | nein | reine UI + `ReportsService`-Signals, kein Backend |
| Neuer Domain-Service? | nein | Bereichs-/Anker-Mathematik als pure Funktionen in `shared/utils/calendar-keyboard.util.ts` (Teil 1 Entscheidung 10) |
| Premium-Gate? | nein | Täglich-Tab ist frei (`reports.html:177` gated nur Wochen/Monat) |
| Routing / API / Firestore / Rules? | nein | — |
| Neue Texte? | ja, je 5 Keys de/en | `reports.multiSelectButton`, `reports.multiSelectTooltip`, `shared.calendarMultiSelectOnAria`, `shared.calendarMultiSelectOffAria`, `shared.calendarSelectedCountAria` |
| Shared Component? | bestehend | `CalendarComponent` bekommt Input `multiSelectActive`, Outputs `daysDeselected`, `multiSelectEnded`; bleibt state-frei (Modus gehört `ReportsService`) |
| Service-Änderung? | ja, klein | `removeDatesFromSelection(dates)`, idempotentes `endMultiSelect()`; `saveBatchEntries` beendet den Modus (Entscheidung 7) |
| Filter Nicht-Arbeitstage | bleibt im Service | `addDateRangeSelection` filtert; Util liefert ungefilterte Bereiche; Space auf Sa/So im Modus bleibt Bestandsverhalten (kein Filter) |
| Anker-State | Komponente | `_anchorKey`, `_rangeKeys`, `_rangeBase` als Felder/Signals, kein Service-State |
| Live-Region | CDK `LiveAnnouncer`, polite | im Dashboard etabliert, per `{ provide: LiveAnnouncer, useValue: { announce } }` mockbar, kein Timer im Test |

Abweichungen vom Naheliegenden:
- Verkleinern/Umkehr braucht `daysDeselected` + `removeDatesFromSelection`, weil das Modell bisher rein additiv ist; `dragSelected` bleibt idempotent additiv.
- `remove = (_rangeKeys \ newRange) \ _rangeBase`: vorher gewählte Tage werden beim Verkleinern nie entfernt.
- Aktivieren per Button startet mit leerer Auswahl; Einzelauswahl-Kreis und `aria-selected` für `selectedDate` entfallen im aktiven Modus (auch bei leerer Menge).
- Escape beendet den ganzen Modus inkl. Auswahl und emittiert nur, wenn `multiSelectActive()` true ist.
- Ansage-Logik in EINEM `effect` über `multiSelectActive` + `multiSelectedDates().size` mit gemerktem Vorwert (statt zwei Effects, deren Reihenfolge nicht garantiert ist). Kein Effect setzt Fokus.
- Shift+Pfeil aus dem Ruhezustand sagt nur "Ausgewählte Tage: N" an (der lange Modus-an-Hinweis wäre sonst von der zweiten Ansage überschrieben); der Hinweis kommt nur bei Button-Aktivierung (siehe offene Frage 1).

## Neue / geänderte Dateien

### Core/Feature-Service
```
web/src/app/features/reports/
├── reports.service.ts         # + removeDatesFromSelection, endMultiSelect; saveBatchEntries beendet Modus
└── reports.service.spec.ts    # + describe 'Mehrfachauswahl' (bisher ungetestet)
```

### Shared Utils (pure)
```
web/src/app/shared/utils/
├── calendar-keyboard.util.ts       # + rangeKeys(anchor, target), rangeDiff(oldRange, newRange, base)
└── calendar-keyboard.util.spec.ts  # + Bereichs-/Diff-Tests (Datei aus Teil 1 erweitern)
```

### Shared Component
```
web/src/app/shared/components/calendar/
├── calendar.ts                      # Input/Outputs, Handler-Zweig, Anker-State, aria-multiselectable, LiveAnnouncer-Effect
├── calendar-keyboard.spec.ts        # Bestandstest Zeile 299 umstellen (Schritt 7)
└── calendar-multiselect.spec.ts     # NEU: Host-Komponente im Spec, Komponenten-Tests
```

### Feature / i18n / Docs
```
web/src/app/features/reports/reports.html, reports.scss, reports.ts, reports.spec.ts
web/public/i18n/de.json, en.json
web/CLAUDE.md
```

## Test-Konventionen (für alle Schritte)
- Vitest/jsdom, feste Daten: `vi.useFakeTimers` + `vi.setSystemTime(new Date(2026, 9, 15, 12))`, lokale Konstruktoren, Vergleiche über `dayKey`/`getFullYear/Month/Date`, nie `toISOString()`, nie Wochentag aus "heute". Fixtures im `document`; Events `new KeyboardEvent('keydown', { key, shiftKey, bubbles: true, cancelable: true })` + `detectChanges()` + `await fixture.whenStable()` (Setup wie `calendar-keyboard.spec.ts`: `provideTranslateService`, `LOCALE_ID de-DE`, `registerLocaleData`).
- **Kein Warten auf echte Timer:** `LiveAnnouncer` gemockt; Effects über `fixture.detectChanges()` bzw. `TestBed.tick()`; `afterNextRender` über `detectChanges()`; `onCardPointerUp` nutzt `setTimeout`, Assertions nicht davon abhängig machen, bei Bedarf `vi.advanceTimersByTime(0)` mit Fake-Timern.
- `setTranslation` im Spec ergänzen um die 3 neuen `shared.*`-Keys (sonst Roh-Key in der Ansage; Erwartungen gegen den übersetzten Text).
- **Rot-Nachweis je Schritt (Pflicht):** Test zuerst, Einzelspec-Lauf, erwarteten Fehlschlag mit Grund notieren (inhaltlich, nicht Import-/Syntaxfehler; für neue Util-Funktionen/Service-Methoden zuerst Stub mit Signatur und Platzhalterrückgabe, für Komponenten-Inputs/Outputs zuerst leere Deklaration), dann Impl, dann Grün-Nachweis. Belege als Stichpunkte in den PR-Body.
- **Mutationsprobe je Kernlogik (Pflicht, manuell):** nach Grün eine gezielte Mutation einbauen, Test muss rot werden, Mutation zurücknehmen, Grün erneut; Ergebnis tabellarisch in den PR-Body (Mutation / welcher Test fiel). Mutationen je Schritt unten.
- **Vite-SSR-Falle:** keine nackten Import-Referenzen als Klassenfeld-Initializer (`inject(LiveAnnouncer)`, `signal<string | null>(null)`, `new Set<string>()` sind Aufrufe, unkritisch; keine Util-Konstante als Feldwert). Gegencheck im Vollauf, nicht nur Einzelspec.
- Bestehende Pointer-, Drag- (Drag [3,4,5]), Tastatur-, Feiertags- (#371), Mitternachts-Tests (#382) laufen unverändert grün; nach jedem Schritt `calendar.spec.ts` + `calendar-keyboard.spec.ts` laufen lassen.

## Implementierungsschritte (TDD-First)

### Schritt 1: Service `removeDatesFromSelection` / `endMultiSelect` / Batch-Ende (Commit 1)
Tests zuerst in `reports.service.spec.ts`, neuer `describe('ReportsService - Mehrfachauswahl')`, Provider-Muster wie vorhandene Describes (Fakes für Auth/WorkProfile/WorkEntry/Settings/...; `getSettings` über `of({...DEFAULT_SETTINGS, workdays})` steuerbar; `saveEntry`/`getEntriesForMonth` als `vi.fn`). Feste Daten `new Date(2026, 9, n)` (3./4.10.2026 = Sa/So, Wochentag nur über feste Konstruktoren, nicht aus "heute").
- [ ] Ausgangszustand: Modus aus, `selectedDates().size === 0` (Baseline, würde schon grün sein, trotzdem als Regressionsanker)
- [ ] `toggleMultiSelect()`: aus -> an mit leerer Menge; an -> aus leert eine vorhandene Auswahl
- [ ] `toggleDateSelection`: fügt hinzu, zweiter Aufruf entfernt (Bestand, bisher ungetestet); filtert Sa/So NICHT
- [ ] `addDateRangeSelection`: schaltet Modus ein; Bereich Do 1.10.–Mo 5.10.2026 mit Default-Arbeitstagen Mo–Fr enthält Sa/So nicht, ist additiv zu vorhandener Auswahl; mit `workdays: [1..7]` enthält alle; mit leeren/nur-Wochenend-Bereich bleibt Menge unverändert, Modus trotzdem an
- [ ] `removeDatesFromSelection`: entfernt nur die genannten Keys; nicht vorhandene Keys = No-op (Set-Inhalt gleich); leeres Array = No-op; kein Arbeitstage-Filter beim Entfernen (Sa-Key, der per Toggle drin ist, wird entfernt); Modus bleibt aktiv (auch bei leerer Menge); neue Set-Instanz nur bei Änderung ist nicht gefordert (kein Referenztest)
- [ ] `endMultiSelect`: Modus an + Auswahl {a,b} -> Modus aus, Menge leer; zweimal aufgerufen bleibt aus (idempotent, kein erneutes Einschalten); im Ruhezustand aufgerufen bleibt aus
- [ ] `saveBatchEntries`: nach Erfolg Modus AUS und Menge leer (Entscheidung 7), `_reloadCurrentMonth`-Wirkung wie bisher (bestehender Test "lädt genau einmal neu" bleibt grün); bei Schreibfehler (`saveEntry` rejects) bleibt Modus UND Auswahl erhalten (kein Verlust bei Fehler)
- Rot-Nachweis: Stubs `removeDatesFromSelection(){}` / `endMultiSelect(){}`; Rot: Menge unverändert bzw. Modus bleibt an; Batch-Test rot, weil Modus bleibt aktiv.
- Impl: `removeDatesFromSelection` (neue Set-Instanz via `update`, kein Filter), `endMultiSelect` (`_isMultiSelectActive.set(false)` + `_selectedDates.set(new Set())`), `saveBatchEntries` ruft nach erfolgreichem `Promise.all` `endMultiSelect()` statt `clearDateSelection()` (`clearDateSelection` bleibt öffentlich). `toggleMultiSelect` und `addDateRangeSelection` unverändert.
- Mutationsproben: (a) `removeDatesFromSelection` entfernt zusätzlich Wochenenden/alles -> Test "nur genannte Keys" rot; (b) `endMultiSelect` als `toggle` implementiert -> Idempotenz-Test rot; (c) Arbeitstage-Filter in `addDateRangeSelection` entfernen -> Wochenend-Test rot; (d) `endMultiSelect` im Fehlerpfad vor `await` aufrufen -> Fehlerfall-Test rot.

### Schritt 2: Reine Bereichs-/Anker-Logik im Util (Commit 2)
Neue pure Funktionen in `calendar-keyboard.util.ts` (Namen verbindlich, Feinheiten im Code; keine Angular-Imports, keine Millisekunden-Arithmetik, kein `toISOString`):
- `rangeKeys(anchor: Date, target: Date): string[]` — geordnete Keys `yyyy-MM-dd` von min bis max (inklusive), unabhängig von der Richtung, Schritt über `new Date(y, m, d + i)`; mutiert keine Eingabe
- `rangeDiff(oldRange: ReadonlySet<string>, newRange: ReadonlySet<string>, base: ReadonlySet<string>): { add: string[]; remove: string[] }` — `add = newRange`, `remove = (oldRange \ newRange) \ base`
- Der Nicht-Arbeitstage-Filter bleibt im Service (`addDateRangeSelection`); das Util liefert ungefilterte Bereiche. Spec-Host in Schritt 3 bildet den Filter nach.
Tests zuerst in `calendar-keyboard.util.spec.ts` (ohne DOM), Rot gegen Stubs (`rangeKeys` -> `[]`, `rangeDiff` -> leer):
- [ ] `rangeKeys`: Gleicher Tag = 1 Key; vorwärts 15.–18.10.2026 = 4 Keys geordnet; rückwärts (Anker 18., Ziel 15.) = identisch geordnet
- [ ] Monatsgrenze 30.10.–02.11.2026 (Keys beider Monate); Jahreswechsel 30.12.2026–02.01.2027; Schaltjahr 27.02.2028–01.03.2028 (enthält `2028-02-29`) und 2026 (27.02.–01.03. ohne 29.02.)
- [ ] DST: 24.10.–27.10.2026 und 28.03.–30.03.2026 (Zeitumstellung): je Tag ein Key, keine Lücke/Doppelung, `getDate()`-konsistent
- [ ] Grenzen: sehr großer Bereich (z. B. 01.01.–31.12.2026 = 365 Keys, 2028 = 366) und Reinheit (Eingabe-Dates unverändert, Rückgabe neue Strings)
- [ ] `rangeDiff` Erweitern: old {10,11,12}, new {10..13}, base {} -> remove []
- [ ] Verkleinern: old {10..13}, new {10..12}, base {} -> remove ['…-13']
- [ ] Umkehr über den Anker: Anker 10., old {10..13}, new {8..10} -> remove {11,12,13}, add = {8,9,10}
- [ ] Base wird nie entfernt: base {11}, old {10..13}, new {10} -> remove {12,13} (11 bleibt)
- [ ] Leere Mengen: old {} / new {} / base {} liefern leere Ergebnisse ohne Fehler; identische Mengen -> remove []
- [ ] Integration der Navigation: Kombination `nextFocusDate(key, from, false)` + `rangeKeys` für Shift+Pfeil (±1, ±7), Shift+Home/End (Mo/So, Monatsklemmung), Shift+PageUp/PageDown (31.01.2026 -> 28.02.2026, Bereich enthält alle Tage dazwischen), Grenzen Monats-/Jahreswechsel (31.12.2026 +1 -> 01.01.2027), Schaltjahr (28.02.2028 +1 -> 29.02.2028, 29.02.2028 +1 -> 01.03.2028) — als reine Funktionskomposition im Spec
- Impl dann grün. Bestehende Util-Tests aus Teil 1 unverändert grün.
- Mutationsproben: (a) `rangeKeys` ohne min/max-Ordnung (nur Anker->Ziel) -> Rückwärts-/Umkehr-Test rot; (b) Endpunkt exklusiv -> Länge-Tests rot; (c) `rangeDiff` ohne `base`-Abzug -> "Base nie entfernt" rot; (d) `setDate`/Millisekunden-Schritt (86_400_000) statt `new Date(y,m,d+i)` -> DST-Test rot unter `TZ=Europe/Berlin` (Mutation im TZ-Lauf prüfen).

### Schritt 3: Kalender — Input/Outputs, Tastaturverhalten, ARIA (Commit 3)
Neue Spec `calendar-multiselect.spec.ts` mit kleiner **Host-Komponente** (Signals `active`, `selected: Set<string>`; verdrahtet `dragSelected` -> additiv (inkl. Arbeitstage-Filter Mo–Fr per Wochentag aus festen Daten, Modus an), `daysDeselected` -> Entfernen, `dateSelected` -> im Modus Toggle sonst `selectedDate`, `multiSelectEnded` -> Modus aus + Menge leer; gibt `multiSelectActive`/`multiSelectedDates` zurück). Spiegelt den Parent ohne `ReportsService`. Rot zuerst: Inputs/Outputs existieren noch nicht -> Rot-Grund inhaltlich (Stub-Deklarationen vor den Tests, Handler-Zweig fehlt).
Tests (aus Research 6, Nr. 1–12 ohne Live-Region, die kommt in Schritt 4):
- [ ] Shift+ArrowRight ohne Modus: `dragSelected` mit [15.,16.10.] (Anker = fokussierter Tag), Fokus 16.10., `defaultPrevented` true, kein `dateSelected`, kein `daysDeselected`; Host danach: Modus an, Menge {15,16}
- [ ] Folgeschritte: Shift+→ ×3 -> 15–18; Shift+← ×1 -> 15–17 und `daysDeselected` [18.]; Umkehr über den Anker: Shift+← ×2 ab 15–17-Bereich Anker 15. -> 14–15, `daysDeselected` [16.,17.] (genaue Sequenz im Test dokumentieren)
- [ ] Vorherige Auswahl (Base {10.,11.}) bleibt beim Verkleinern/Umkehren immer erhalten; `daysDeselected` enthält 10./11. nie
- [ ] Shift+ArrowDown/Up (±7), Shift+Home/End (Mo/So der Zeile, auf Monat geklemmt), Shift+Ctrl-Kombis unbehandelt (siehe unten)
- [ ] Shift+PageDown/PageUp über Monatsgrenze: `monthChanged` einmal, Fokus per `afterNextRender` auf Zielzelle (über `detectChanges`, kein Timer), Anker bleibt, Bereich enthält Tage beider Monate; Jahreswechsel 31.12.2026 -> Shift+→ -> 01.01.2027 (`monthChanged {2027,1}`), Schaltjahr (Fixture 2028, Shift+→ von 28.02.2028 -> enthält 29.02.2028)
- [ ] Grenzen: Shift+Home auf Montag bleibt Montag (Bereich unverändert, keine Emission nötig oder idempotente Emission — im Test festlegen: idempotente Emission mit gleichem Bereich zulässig, `daysDeselected` nicht emittiert); Shift+End auf Monatsletztem mit Sa/So-Klemmung
- [ ] Plain Pfeil im Modus: Fokus bewegt, keine Emission (`dragSelected`/`daysDeselected`/`dateSelected`), Anker verworfen: nächstes Shift+Pfeil startet am neuen Fokus, Base neu aus aktuellem `multiSelectedDates`
- [ ] Plain Home/End/PageUp/PageDown im Modus verwerfen den Anker ebenso
- [ ] Enter/Space im Modus: `dateSelected` genau einmal, Anker verworfen, `repeat` ignoriert (kein Emit, aber `defaultPrevented`); Enter/Space ohne Modus unverändert (Teil 1)
- [ ] Unbehandelt (`defaultPrevented` false, keine Emission, Fokus unverändert): Ctrl+Space, Shift+Space, Shift+Enter, Ctrl+Shift+Pfeil, Alt+Shift+Pfeil, Meta+Shift+Pfeil, Ctrl+Shift+Home/PageDown (Entscheidung 10)
- [ ] `repeat` bei Shift+Pfeil wird NICHT ignoriert (zwei Events mit `repeat: true` erweitern weiter)
- [ ] Escape im Modus: `multiSelectEnded` genau einmal, `defaultPrevented` true, Fokus bleibt auf der Zelle, Anker verworfen; Escape ohne Modus: unbehandelt (`defaultPrevented` false, keine Emission); Escape mit Ctrl/Alt/Meta/Shift: unbehandelt
- [ ] `pointerdown` (über `onCardPointerDown` mit gemocktem `document.elementFromPoint`/`setPointerCapture`) verwirft den Anker; `focusout` mit `relatedTarget` außerhalb des Grids verwirft ihn, mit `relatedTarget` in einer anderen Zelle nicht; externes Ausschalten (`setInput('multiSelectActive', false)`) verwirft ihn ohne Fokusänderung
- [ ] `aria-multiselectable="true"` am Grid nur bei `multiSelectActive` (auch bei leerer Menge); Attribut fehlt sonst (nicht `"false"`)
- [ ] Aktiver Modus + leere Menge: `aria-selected` aller Tageszellen `"false"` (auch `selectedDate`), keine Zelle mit Klasse `.selected`; Modus aus: Einzelauswahl wie Teil 1 (Regression)
- [ ] Kein Fokusdiebstahl: Setzen von `multiSelectActive`/`multiSelectedDates` per `setInput` ändert `document.activeElement` nicht
- [ ] Regression: `calendar.spec.ts` und `calendar-keyboard.spec.ts` (außer Zeile 299, Schritt 7) unverändert grün; Drag [3,4,5] emittiert `dragSelected` unverändert und ändert Anker nicht
Impl (Komponente):
- [ ] `multiSelectActive = input(false)`; Outputs `daysDeselected = output<Date[]>()`, `multiSelectEnded = output<void>()`
- [ ] Private Felder `_anchorKey: string | null`, `_rangeKeys: Set<string>`, `_rangeBase: Set<string>` (nur Methodenzugriff, keine Util-Konstante als Feldwert)
- [ ] `onGridKeydown`: Modifier-Filter umbauen: Alt/Meta immer unbehandelt; Shift nur zusammen mit den 8 Nav-Tasten und ohne Ctrl; Shift+Enter/Space unbehandelt; Ctrl wie bisher (nur Home/End ohne Shift). Zweige: (1) Escape (`multiSelectActive()` true, kein Modifier) -> `preventDefault`, `multiSelectEnded.emit()`, Anker verwerfen; (2) Enter/Space wie bisher + Anker verwerfen; (3) Shift+Nav -> `_extendRange(key, from)`; (4) Nav ohne Shift -> Anker verwerfen, dann wie Teil 1
- [ ] `_extendRange`: Anker setzen, falls null (Fokus-Tag; `_rangeBase = new Set(multiSelectedDates())`, `_rangeKeys = new Set()`), `target = nextFocusDate(key, from, false)`, `newRange = rangeKeys(anchor, target)`, `diff = rangeDiff(_rangeKeys, newRange, _rangeBase)`; `dragSelected.emit(newRange als Date[])`; wenn `diff.remove` nicht leer `daysDeselected.emit(...)`; `_rangeKeys = newRange`; `_focusCell(target)` (Monatswechsel-Pfad aus Teil 1 unverändert)
- [ ] `focusout` am Grid (`relatedTarget` nicht im Grid) und `pointerdown` (am Anfang von `onCardPointerDown`) -> `_resetAnchor()`; Effect auf `multiSelectActive()`: bei false `_resetAnchor()` (nur State, `untracked`)
- [ ] Template: `[attr.aria-multiselectable]="multiSelectActive() ? 'true' : null"`; `.selected`-Klasse und `isSelected` nur, wenn `!(multiSelectActive() || hasMultiSelected())` (einzige gemeinsame Hilfsmethode, z. B. `isMultiMode()`)
- Mutationsproben: (a) `_rangeBase` leer lassen -> Test "Vorherige Auswahl bleibt" rot; (b) Anker nicht bei Plain-Pfeil verwerfen -> Test "Anker verworfen" rot; (c) Escape ohne `multiSelectActive()`-Prüfung -> "Escape ohne Modus unbehandelt" rot; (d) `shiftKey`-Filter entfernt (Ctrl+Shift behandelt) -> "unbehandelt" rot; (e) `aria-selected` ohne Modus-Bedingung -> "alle false im leeren Modus" rot; (f) `diff.remove` ohne Verkleinerungs-Emission -> Verkleinern-Test rot.

### Schritt 4: LiveAnnouncer (Commit 3, gleicher Kalender-Commit oder eigener Commit)
Tests zuerst in `calendar-multiselect.spec.ts` (`announce = vi.fn()`, `{ provide: LiveAnnouncer, useValue: { announce } }`; keine echten Timer):
- [ ] Modus an per Input (ohne Taste, z. B. Button-Aktivierung im Host): `announce` einmal mit `calendarMultiSelectOnAria`-Text, Politeness `'polite'`
- [ ] Modus aus (Input -> false, auch durch Escape): `announce` einmal mit `calendarMultiSelectOffAria`-Text
- [ ] Kein Announce beim initialen Render (auch mit Startwert `multiSelectActive=true`); kein Announce bei unverändertem Input
- [ ] Shift+Pfeil aus Ruhezustand: genau EINE Ansage `Ausgewählte Tage: 2` (Modus-an-Hinweis unterdrückt, weil Tastaturaktion) — bei bereits aktivem Modus ebenfalls nur die Anzahl
- [ ] Anzahl nach Tastaturaktion = tatsächliche Mengengröße (`multiSelectedDates().size`), nicht Bereichslänge: Bereich Do 1.10.–Mo 5.10.2026 mit Host-Filter Mo–Fr -> Ansage zählt 3 (Do, Fr, Mo), nicht 5; Verkleinern sagt die kleinere Zahl an; Enter/Space-Toggle im Modus sagt die neue Zahl an
- [ ] Plain Pfeil (keine Mengenänderung): keine Ansage
- [ ] **Kein** Announce bei Pointer-Drag und Tap (Methodenaufrufe `onCardPointerDown/Move/Up`, `elementFromPoint` gemockt), auch wenn die Menge wächst
- [ ] Zwei Tastaturaktionen hintereinander ergeben zwei Ansagen (Flag wird zurückgesetzt)
Impl: `inject(LiveAnnouncer)`, `inject(TranslateService)` bereits vorhanden; Flag `_announceNext` nach Tastaturänderung (Shift-Zweig, Enter/Space im Modus); EIN `effect` liest `multiSelectActive()` und `multiSelectedDates().size`, vergleicht mit gemerkten Vorwerten (Felder, nicht getrackt), erste Ausführung nur Vorwerte setzen, ansagen in `untracked`: Modus geändert und nicht Tastatur -> On-/Off-Text; Größe geändert und Flag -> Zählertext (`calendarSelectedCountAria` mit `{count}`); Flag danach zurücksetzen. Texte über `translate.instant`.
- Mutationsproben: (a) Flag ignorieren (immer ansagen) -> Pointer-Drag-Test rot; (b) Bereichslänge statt Mengengröße -> Filter-Test rot; (c) erstes Effect-Laufen ansagen -> "kein Announce beim Render" rot; (d) Off-Ansage entfernen -> Off-Test rot.

### Schritt 5: Toolbar-Button und Verdrahtung in Reports (Commit 4)
Tests zuerst. `reports.spec.ts` ist bisher ein Mini-Test mit `template: ''`. Plan: neuer `describe` mit schlankem Spec mit gefaktem `ReportsService` (Signals `isMultiSelectActive`, `selectedDates`, `selectedDate`, `daysWithEntries`, `bundesland`, `isLoading=false`, `dailyStat`, `selectedDayEntries`, `vi.fn` für `toggleMultiSelect`, `endMultiSelect`, `removeDatesFromSelection`, `addDateRangeSelection`), echtes Template; fällt das Setup unverhältnismäßig aus (Tabs, Dialoge, Premium, Leave-Card), Verdrahtung nur manuell prüfen und im PR ausweisen (Entscheidung wie Research 6). Mindestumfang, wenn machbar:
- [ ] Button `.multi-select-toggle` im `.calendar-panel` VOR `app-calendar`; `aria-pressed` = `isMultiSelectActive()` (`"false"`/`"true"`); Klick ruft `svc.toggleMultiSelect()`
- [ ] Icon wechselt (`checklist` aus, `done_all` an); kein zusätzliches `aria-label` (Accessible Name = sichtbarer Text); `aria-describedby` zeigt auf sr-only-Element mit Tooltip-Text
- [ ] Outputs verdrahtet: `(daysDeselected)` -> `svc.removeDatesFromSelection($event)`, `(multiSelectEnded)` -> `svc.endMultiSelect()`, `[multiSelectActive]="svc.isMultiSelectActive()"`
- [ ] "Abbrechen" im Day-Panel ruft `svc.endMultiSelect()`; danach (nach dem nächsten Render, `afterNextRender` bzw. `detectChanges`, kein Timer) hat der Toggle-Button Fokus (`document.activeElement`)
- [ ] Nach Batch-Speichern: Modus beendet (über Service getestet in Schritt 1), Fokus nach Dialog-Ende wie bisher (Material-Dialog gibt Fokus zurück) — nur manuell prüfen
Impl:
- [ ] `reports.ts`: `MatTooltipModule` in `imports`; `viewChild` auf den Toggle (`ElementRef<HTMLElement>`/`MatButton`), Methode `onCancelMultiSelect()`: `svc.endMultiSelect()` + `afterNextRender(() => toggle.focus(), { injector })`; Template-Handler für `multiSelectEnded` ohne Fokusverschiebung (Escape: Fokus bleibt auf Zelle)
- [ ] `reports.html`: neue Zeile `.calendar-toolbar` über `<app-calendar>`, `mat-stroked-button`, `[attr.aria-pressed]`, `[class.is-active]`, `<mat-icon aria-hidden="true">`, `matTooltip` mit Kürzel, `aria-describedby` auf `<span class="sr-only" id="…">`; "Abbrechen" ruft `onCancelMultiSelect()`; Calendar-Bindings ergänzen
- [ ] `reports.scss`: `.calendar-toolbar { display: flex; justify-content: flex-end; gap: 8px; flex-wrap: wrap; }`, `.is-active` mit `--mat-sys-secondary-container`/`--mat-sys-on-secondary-container` (analog `.batch-btn`, M3-Tokens, kein Hardcode, Hell/Dunkel); vorhandene `.sr-only`-Klasse wiederverwenden, sonst minimal anlegen (Grep zuerst)
- Mutationsproben (soweit getestet): (a) `aria-pressed` statisch -> Test rot; (b) Fokus-Rückgabe entfernen -> Fokus-Test rot; (c) "Abbrechen" ruft `toggleMultiSelect` statt `endMultiSelect` -> Handler-Test rot.

### Schritt 6: i18n (Commit 5)
- [ ] Zuerst Paritätsprüfung/vorhandenen i18n-Test lokal laufen lassen (falls vorhanden) und Rot-Nachweis: Test/Template referenziert Keys, die fehlen (Roh-Key im Spec-Ausgabetext)
- [ ] `public/i18n/de.json` und `en.json`: `reports.multiSelectButton`, `reports.multiSelectTooltip` (Namensraum `reports`, neben `cancelMultiSelectAria`, Zeile ~92); `shared.calendarMultiSelectOnAria`, `shared.calendarMultiSelectOffAria`, `shared.calendarSelectedCountAria` (neben `calendarHolidayAria`, Zeile ~318). Texte laut Research Abschnitt 5, deutsch neutral/imperativ (kein Duzen nötig), Zähler pluralfrei "Ausgewählte Tage: {{count}}". Minimale Diffs, JSON-Syntax prüfen.
- [ ] Mutation: Key in en.json weglassen -> Paritätstest (falls vorhanden) bzw. Spec mit `use('en')` rot

### Schritt 7: Bestandstest `calendar-keyboard.spec.ts:299` umstellen (Commit 3, mit Kalender-Änderung, damit kein roter Zwischenstand)
- [ ] Test "lässt Ctrl/Alt/Meta/Shift+Pfeil, Tab und andere Tasten unbehandelt" bleibt namentlich, Varianten ändern: `ArrowRight+shiftKey` und `Home+shiftKey` entfernen; ersetzen durch `Enter+shiftKey`, `' '+shiftKey`, `ArrowRight+ctrlKey+shiftKey`, `ArrowRight+altKey+shiftKey`, `ArrowRight+metaKey+shiftKey`; übrige Varianten (Ctrl/Alt/Meta+Pfeil, `PageDown+ctrl`, `Enter+ctrl`, Tab, `a`) unverändert. Verhalten für diese Kombinationen bleibt "unbehandelt"; im PR benennen (Entscheidung 11)
- [ ] Reihenfolge TDD: Test umstellen, laufen lassen (grün gegen alten und neuen Code, solange Ctrl/Alt/Meta+Shift unbehandelt bleiben), danach den Shift-Zweig implementieren; Rot-Nachweis liefert Schritt 3 (neues Shift-Verhalten) — hier kein eigener Rot-Beleg nötig, im PR vermerken
- [ ] Mutation: Shift-Filter in der Komponente lockern (Ctrl+Shift behandelt) -> dieser Test rot

### Schritt 8: Doku und Vollläufe (Commit 6)
- [ ] `web/CLAUDE.md`: Kalender-Zeile (Zeile ~60) um Mehrfachauswahl per Tastatur ergänzen (Toggle-Button, Shift+Pfeil/Home/End/PageUp/PageDown, Anker/`daysDeselected`, Escape, `aria-multiselectable`, LiveAnnouncer nur nach Tastaturaktionen); Utils-Zeile (Zeile ~70) um `rangeKeys`/`rangeDiff` ergänzen; `ReportsService`-Abschnitt: `endMultiSelect`/`removeDatesFromSelection`, Modus endet nach Batch-Speichern
- [ ] Vollläufe `cd web && npm test -- --watch=false` unter `TZ=Europe/Berlin`, `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland`, `TZ=UTC` (Vite-SSR-Falle nur im Vollauf sichtbar); DST-Bereich 24.–27.10.2026 prüft die Util-Tests; danach `npm run build -- --configuration production`
- [ ] Ergebnisse (Anzahl Tests, Läufe je TZ) in den PR-Body; Rot/Grün-Belege und Mutationstabelle ebenfalls
- [ ] Commit-Trailer und PR-Footer laut Vorgabe der Hauptsession; PR gegen `develop`

## Signal-Design (Skizze, kein Code)
- `CalendarComponent`: neu `multiSelectActive` (input), `daysDeselected`/`multiSelectEnded` (outputs); private Felder `_anchorKey`, `_rangeKeys`, `_rangeBase`, `_announceNext`, `_prevActive`, `_prevCount`; ein Ansage-`effect`, ein Reset-`effect`; `isMultiMode()` Hilfsmethode (aktiv oder Größe > 0). Fokus ausschließlich imperativ (`_focusCell`/`afterNextRender`), nie aus einem Effect.
- `ReportsService`: bestehende Signals `_isMultiSelectActive`/`_selectedDates`, neue Methoden ohne neue Signals.
- `ReportsComponent`: `viewChild` Toggle, `onCancelMultiSelect()`. OnPush, `@if`/`@for`/`@let`, `inject()`, kein `@HostListener`, kein `standalone: true`.

## Manuelle Prüfliste (für den PR-Body, eigener Abschnitt)
Umgebung: `npm start`, Reports, Tab "Täglich", Chrome (axe DevTools + Lighthouse auf /reports), Hell und Dunkel, 320px/375px, Touch (DevTools-Emulation oder Gerät).
- [ ] Toggle sichtbar über dem Kalender, Tab-Reihenfolge Toggle -> Vorheriger/Nächster Monat -> Grid (ein Stopp) -> Stats; Enter/Space schaltet, `aria-pressed` im Accessibility-Tree, Fokusring sichtbar, Tooltip mit Kürzel (Hover/Fokus), Beschriftung auf 320px sichtbar (Zeile bricht um)
- [ ] Button an: Auswahl leer, Einzelauswahl-Kreis weg, Ansage "Mehrfachauswahl aktiv …"; aus: Auswahl verworfen, Ansage "beendet"
- [ ] Im Modus: Space/Enter toggelt Tage (Day-Panel "N Tage" zählt mit), Maus-Tap gemischt mit Tastatur; Space auf Sa/So nimmt den Tag auf (Bestandsverhalten, im PR benennen)
- [ ] Shift+Pfeil aus Ruhe: Modus an, Bereich wächst, Gegenrichtung schrumpft, Umkehr über den Anker; Shift+Home/End/PageUp/PageDown; über Monats- und Jahresgrenze; Sa/So werden übersprungen und die angesagte Zahl stimmt; gehaltene Taste erweitert fließend
- [ ] Vorher gewählte Tage bleiben beim Verkleinern; Pfeil ohne Shift committet, neuer Bereich beginnt am neuen Fokus; Pointerdown/Tab-Weg aus dem Grid verwirft den Anker
- [ ] Escape beendet den Modus, Fokus bleibt auf der Zelle; "Abbrechen" im Day-Panel bringt den Fokus zum Toggle
- [ ] Batch-Eintrag per Tastatur (Dialog öffnen/schließen, Fokus zurück); nach Speichern ist der Modus beendet, Toggle zeigt "nicht gedrückt"
- [ ] Maus-Drag und Touch-Drag unverändert (inkl. Wochenend-Filter), kein Anker-Rest nach Drag; Touch: Toggle erreichbar, Zielgröße >= 40px
- [ ] axe: 0 Verstöße (`aria-multiselectable` auf `role=grid` gültig, `aria-pressed` auf Button, keine ungültigen Rollen); Lighthouse-Accessibility-Score notieren
- [ ] Kontrast: Aktiv-Zustand des Toggles (on-secondary-container auf secondary-container), Fokusring auf `multi-selected`-Zellen, Hell/Dunkel, forced-colors-Stichprobe; Werte notieren
- [ ] Screenreader-Stichprobe, soweit möglich (Entscheidung 9, kein bestimmter Screenreader gefordert): NVDA/VoiceOver Shift+Pfeil kommt im Grid an (Fokusmodus), im NVDA-Browse-Modus wird Text markiert statt gewählt (bekannt, nur Handtest, Befunde als Folge-Issue durch die Hauptsession); Ansage "Ausgewählte Tage: N" ohne Dauerflut, keine doppelte Modus-Ansage; Doppelansage Zellenansage + Live-Region bewerten
- [ ] Hinweise im PR: Einzelauswahl-Kreis verschwindet im aktiven Modus (Absicht); kein Shift+Klick, kein Ctrl+Shift+Home/End (Entscheidung 10); kein Zähler-Chip (Entscheidung 8); Modus endet nun nach Batch-Speichern

## Offene Fragen an die Hauptsession
1. Ansage beim Einstieg per Shift+Pfeil: nur "Ausgewählte Tage: N" (Plan) statt Modus-an-Hinweis + Zähler, weil zwei `announce`-Aufrufe in einem Tick sich überschreiben. Einverstanden? Alternative: einmaliger kombinierter Text (zusätzlicher Key).
2. Escape beendet den Modus nur bei Fokus im Grid (Handler am Grid). Soll Escape auch vom Toggle-Button aus gelten? Plan: nein (Toggle ist selbst der Aus-Schalter).
3. Reports-Verdrahtungs-Spec (Schritt 5): soll ein aufwendigeres Setup in Kauf genommen werden, oder ist bei zu großem Aufwand rein manuelle Prüfung dieser Teile akzeptabel (im PR ausgewiesen)? Plan: erst versuchen, bei mehr als ca. 60 Zeilen Setup manuell.
4. Space auf Sa/So im Modus nimmt den Tag ohne Filter auf (Bestandsverhalten). Als Bestand belassen oder ebenfalls filtern? Plan: belassen und im PR benennen.
5. `Closes #377` im PR-Body oder `Refs #377` bis zur manuellen Prüfung (Research Frage 1, nicht explizit entschieden)?

## Entscheidungen zu den offenen Fragen (Hauptsession)

1. Beim Einstieg per Shift+Pfeil nur „Ausgewählte Tage: N" (kein kombinierter Text, kein zusätzlicher Key); der Modus-an-Hinweis nur bei Button-Aktivierung.
2. Escape gilt nicht vom Toggle-Button aus (nur im Kalender-Grid), wie im Plan.
3. Reports-Verdrahtungs-Spec: erst versuchen; bei mehr als ca. 60 Zeilen Setup nur manuell prüfen und im PR ausweisen – einverstanden.
4. Space auf Sa/So im Modus bleibt wie im Bestand (Tag ohne Filter aufnehmen); nicht ändern, im PR als Nebenbefund nennen.
5. PR-Body `Closes #377` (letzter Teil); das Issue wird nach dem Merge zusätzlich manuell geschlossen und die manuelle Prüfliste als Hinweis in den Abschlusskommentar übernommen.
