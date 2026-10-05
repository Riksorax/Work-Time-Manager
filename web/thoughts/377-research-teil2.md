# Web-Research: #377 Teil 2 — Mehrfachauswahl per Tastatur im Web-Kalender
Datum: 2026-10-05
Feature-Ordner: web/src/app/shared/components/calendar/ (Verwender: web/src/app/features/reports/)
Basis: Branch `claude/week-number-display-bug-x5xq8r` auf develop inkl. Teil 1 (PR #401). Ergänzt `377-research.md` / `377-plan.md` (PR 1), ersetzt sie nicht.

Kein Flutter-Port, kein Backend, keine Firestore-Pfade/Rules. Verbindliche Produktentscheidung (Maintainer): **beides** — sichtbarer
Mehrfachauswahl-Button als Einstieg UND Shift+Pfeil als Abkürzung.

## 0. Befund in Kurzform

- Der Mehrfachmodus liegt komplett im `ReportsService` (`_isMultiSelectActive`, `_selectedDates: Set<'yyyy-MM-dd'>`); der Kalender kennt den Modus nicht, nur `multiSelectedDates.size`.
- Heute gibt es **keinen** Einstieg außer Pointer-Drag (`addDateRangeSelection` schaltet ein). `toggleMultiSelect()` hat genau einen UI-Aufrufer: den „Abbrechen“-Button im Day-Panel.
- Das Modell ist rein **additiv** (Drag fügt hinzu, entfernt nie; Tap/Enter/Space togglet einzeln). Für „Shift+Gegenrichtung verkleinert“ braucht es eine kleine Service-Ergänzung (Abschnitt 2.3), kein Umbau.
- Der Kalender braucht zwei neue Inputs/Outputs (Modus rein, „Modus beenden“ und „Tage abwählen“ raus). `dateSelected`/`dragSelected`/`monthChanged` und die Pointer-Methoden bleiben unverändert.
- Es gibt keinen Premium-Gate und kein Backend im Täglich-Tab (Premium nur Wochen-/Monatsansicht, `reports.html:177`). Batch-Eintrag („N Tage“) ist für jeden Nutzer verfügbar.

## 1. Ist-Zustand des Mehrfachmodells

**Betreten** (`reports.service.ts`)
- Nur durch Pointer-Drag über mindestens zwei Tage: `onCardPointerMove` → `dragSelected(Bereich Start..Aktuell)` → `addDateRangeSelection(dates)`: setzt `_isMultiSelectActive=true`, filtert Nicht-Arbeitstage (`settings.workdays`, ISO 1-7, Default Mo-Fr) heraus, fügt additiv zu `_selectedDates` hinzu.
- `toggleMultiSelect()` (Zeile 269) schaltet nur um; beim Ausschalten wird die Auswahl geleert. Beim Einschalten per Toggle wäre der Modus aktiv mit leerer Auswahl — dieser Zustand ist heute über die UI nicht erreichbar, wird aber mit dem Button der Normalfall.

**Auswahl-Optik** (`calendar.ts`)
- `.multi-selected` (secondary-container) je Key in `multiSelectedDates`; die Einzelauswahl `.selected` (primary) nur, wenn `!hasMultiSelected()` (Größe 0).
- Lücke: bei aktivem Modus mit leerer Auswahl (neu: Button) zeigt der Kalender wieder die alte Einzelauswahl als „ausgewählt“ (auch `aria-selected` aus Teil 1). Gleiches heute schon, wenn man per Tap die letzte Auswahl abwählt (Modus bleibt aktiv, Set leer).

**Im Modus** (`reports.ts:123`, `onCalendarDayTap`)
- Tap/Enter/Space (`dateSelected`) → `toggleDateSelection(date)` (filtert **nicht** nach Arbeitstagen: ein einzeln getippter Sa/So wird aufgenommen; Drag-Bereiche filtern). Außerhalb des Modus → `selectDate`.
- Day-Panel (`reports.html:55-72`): `day-header-actions` nur bei aktivem Modus: bei Auswahl > 0 ein „N Tage“-Button (`openBatchQuickEntryDialog` → `saveBatchEntries(dates, type)` → Einträge je Tag speichern, danach `clearDateSelection()`), daneben „Abbrechen“ (`toggleMultiSelect`, aria „Mehrfachauswahl beenden“).
- Das Day-Panel liegt auf Mobile (<900px, Spalten-Layout) unter Kalender + Stats, also außerhalb des Bildschirms, wenn man im Kalender wählt.

**Beenden / Zurücksetzen — Lücken im Bestand**
- Einziger Ausstieg: „Abbrechen“. Kein Escape.
- `saveBatchEntries` ruft `clearDateSelection()`: leert nur die Menge, **Modus bleibt aktiv** (Batch-Button verschwindet, Abbrechen bleibt). Weder Monatswechsel, Tab-Wechsel noch Profilwechsel beenden den Modus.
- Der „Abbrechen“-Button entfernt sich beim Klick selbst aus dem DOM (`@if (isMultiSelectActive())`): **Fokusverlust** (Fokus fällt auf `body`). Mit dem neuen Toggle-Button muss der Fokus nach „Abbrechen“ auf den Toggle gehen (Abschnitt 3).
- Nicht Teil dieses Issues, aber mitzuprüfen: den Modus auch nach erfolgreichem Batch-Eintrag beenden? (Frage 7.)

**Tests heute:** Das Mehrfachmodell hat weder in `reports.service.spec.ts` noch `reports.spec.ts` Tests (grep: keine Treffer für `toggleMultiSelect|addDateRange|toggleDateSelection`). `calendar.spec.ts` deckt Drag [3,4,5] über die Pointer-Methoden ab, `calendar-keyboard.spec.ts` (502 Zeilen) die Teil-1-Tastatur inkl. „Shift+Pfeil wird nicht abgefangen“.

## 2. Tastaturmodell

### 2.1 Tasten (nur Grid-Fokus, Handler `onGridKeydown` am `.calendar-grid`)

| Taste | Modus aus | Modus an |
|---|---|---|
| Pfeile, Home/End, Strg+Home/End, PageUp/Down | wie Teil 1 (Fokus bewegt, Auswahl unberührt) | gleich; **beendet den Anker** (Bereich ist „committed“) |
| Enter / Leertaste | `dateSelected` → Einzelauswahl (Teil 1, `repeat` ignoriert) | `dateSelected` → Parent toggelt den Tag; Anker verwerfen |
| **Shift+Pfeil**, **Shift+Home/End**, **Shift+PageUp/Down** | **Einstieg**: Anker = fokussierter Tag, Modus an, Bereich Anker..neuer Fokus | Bereich ab Anker erweitern/verkleinern/umkehren |
| Escape | unbehandelt | Modus beenden (Auswahl leeren), Fokus bleibt auf der Zelle |
| Strg+Leertaste, Shift+Leertaste, Strg/Alt/Meta+Shift+* | unbehandelt | unbehandelt |

Begründungen:
- **Strg+Leertaste nicht belegen:** im Modus ist plain Space schon „toggle“ (explizit gewählter Modus), Strg+Space ist unter macOS/NVDA/IME belegt. Teil 1 lässt Strg+Space bewusst durch; das bleibt.
- **Ctrl+Shift+Home/End/PageUp/PageDown nicht belegen:** Ctrl+Shift+PageUp/Down verschiebt in Chrome/Firefox den Tab; YAGNI. Handler-Filter: `shiftKey && !ctrl && !alt && !meta` nur für die 8 Nav-Tasten (`isCalendarNavKey`), sonst wie heute zurückkehren. Shift+Enter/Space unbehandelt.
- **Home/End/PageUp/PageDown mit Shift:** gleiche Semantik wie Teil 1 (`nextFocusDate`, Zeile/Monat, Klemmung); Bereich darf Monatsgrenzen überschreiten (Keys im Service sind monatsunabhängig).
- `event.repeat` bei Shift+Pfeil **nicht** ignorieren (gehaltene Tasten dürfen den Bereich fließend erweitern); bei Enter/Space bleibt `repeat` ignoriert.

### 2.2 Anker und Bereichslogik (Komponenten-State, kein Service-State)

Neuer privater State in `CalendarComponent` (alles Signals bzw. Felder, kein Input):
- `_anchorKey: string | null` — gesetzt beim ersten Shift+Nav-Schritt auf den **fokussierten** Tag (nicht auf `selectedDate`; Excel/Explorer-Semantik, und `selectedDate` ist im Modus nicht Teil der Auswahl).
- `_rangeKeys: Set<string>` — der zuletzt gemeldete Bereich Anker..Fokus (inklusive Nicht-Arbeitstage; der Service filtert).
- `_rangeBase: Set<string>` — Schnappschuss von `multiSelectedDates()` beim Anker-Setzen (vorher bereits gewählte Tage; sie dürfen beim Verkleinern nie entfernt werden).

Schritt bei Shift+Nav: `target = nextFocusDate(key, from, false)`; `newRange = _dateRange(anchor, target)` (vorhandene Methode, geordnet, lokale Date-Konstruktoren). `add = newRange`, `remove = (_rangeKeys \ newRange) \ _rangeBase`. Emittiert wird `dragSelected(newRange)` (idempotent additiv, bestehender Vertrag) und, falls `remove` nicht leer, **ein neuer Output** `daysDeselected: Date[]`. Danach `_rangeKeys = newRange` und Fokus auf `target` (`_focusCell`, inkl. Monatswechsel/`afterNextRender` aus Teil 1).

Verhalten damit: Anker 10., Shift+→ ×3 = 10-13; Shift+← ×1 = 10-12 (13 abgewählt); weitere Shift+← über den Anker hinaus = 7-10 (11-13 abgewählt) — Umkehr funktioniert, vorher gewählte Tage bleiben.

Anker verwerfen (`_anchorKey=null`, Sets leeren) bei: Pfeil/Home/End/Page **ohne** Shift, Enter/Space, Escape, `pointerdown` (jede Maus-/Touch-Interaktion), `focusout` des Grids nach außen (`relatedTarget` nicht im Grid; deckt Batch-Dialog, Toggle-Klick, Tab-Wechsel ab), Modus wird extern beendet (Effect auf `multiSelectActive()` → false, nur State, kein Fokus). Es gibt keinen `effect`, der Fokus setzt.

### 2.3 Braucht das eine Service-Änderung? Ja, klein und additiv

`ReportsService` ergänzen (alles andere bleibt):
1. `removeDatesFromSelection(dates: Date[])` — entfernt Keys aus `_selectedDates` (kein Filter; nicht gewählte Keys sind No-op). Parent: `(daysDeselected)="svc.removeDatesFromSelection($event)"`.
2. `endMultiSelect()` — idempotent: Modus aus + Auswahl leeren. Parent: `(multiSelectEnded)="svc.endMultiSelect()"` (Escape) und das Toggle/Abbrechen. Grund: `toggleMultiSelect()` ist im Zustandsabgleich mit der Komponente riskant (Doppel-Toggle = unbeabsichtigt wieder an). `toggleMultiSelect()` bleibt für den Button (oder `setMultiSelect(active)`).
3. Optional (Frage 7): `saveBatchEntries` beendet den Modus statt nur die Auswahl zu leeren.

Alternative ohne Service-Änderung: nur additives Erweitern, Shift+Gegenrichtung tut nichts — funktioniert, widerspricht aber APG/Excel-Erwartung; nicht empfohlen. Nicht-Arbeitstage-Filter bleibt unverändert (Abschnitt 2.4).

### 2.4 Nicht-Arbeitstage
Der Filter bleibt (Konsistenz mit Drag; Batch-Eintrag für Sa/So wäre meist ungewollt). Per Tastatur ist das nachvollziehbar, solange das Feedback stimmt: die Live-Region sagt die **tatsächliche** Anzahl (`multiSelectedDates().size`) an, nicht die Länge des Bereichs; `aria-selected` bleibt auf Sa/So `false`. Space auf einem Sa/So im Modus nimmt den Tag explizit auf (bestehendes Toggle-Verhalten, kein Filter) — als Bestandsverhalten belassen und im PR benennen.

### 2.5 Roving tabindex und Fokus
- Fokus folgt weiter **nicht** der Auswahl; Shift+Pfeil bewegt den Fokus (wie Pfeil) und erweitert den Bereich. Roving unverändert (`_focusKey`).
- Button-Aktivierung verschiebt den Fokus **nicht** (Toggle-Button-Muster); Tab geht weiter zu Monat-Buttons und Grid (ein Stopp, Teil 1).
- Escape beendet den Modus, Fokus bleibt auf der Zelle; „Abbrechen“ im Day-Panel (verschwindet) → Fokus auf den Toggle-Button (`afterNextRender`, im `ReportsComponent`).
- Maus-Drag/Tap: unverändert; `pointerdown` verwirft nur den Anker. Shift+Klick (Bereich per Maus) ist ausdrücklich **nicht** Teil (nicht gefordert, Pointer-Vertrag unangetastet).

## 3. Button-Konzept

- **Ort:** in `reports.html`, im `calendar-panel` als eigene Zeile **über** `<app-calendar>` (neuer `.calendar-toolbar`, rechtsbündig, `display:flex; gap:8px; flex-wrap:wrap`). Der Modus gehört dem `ReportsService`, nicht dem wiederverwendbaren Kalender (der hat nur einen Verwender, bleibt aber state-frei). Auf Mobile liegt der Button so direkt über dem Kalender statt unterhalb der Falte wie „Abbrechen“. Variante: unter dem Grid (Tab-Reihenfolge Grid → Button) — Empfehlung bleibt oben (Frage 2).
- **Muster:** `mat-stroked-button` (wie „Abbrechen“/„Schnelleintrag“ im Day-Panel), `[attr.aria-pressed]="svc.isMultiSelectActive()"`, `[class.is-active]`. Aktiv-Optik analog `.batch-btn`: `--mat-sys-secondary-container` / `--mat-sys-on-secondary-container` (beide Themes über M3-Tokens, kein Hardcode). Zustand nicht nur über Farbe: Icon wechselt (`checklist` aus, `done_all` an; beide in Material Icons vorhanden, `index.html` lädt die Font) — WCAG 1.4.1. `aria-label` **nicht** zusätzlich setzen: sichtbarer Text = Accessible Name; Name ändert sich nicht mit dem Zustand (sonst Doppelaussage mit `aria-pressed`).
- **Beschriftung:** Text „Mehrfachauswahl“ / „Multi-select“, sichtbar auch auf 320px (Zeile bricht via `flex-wrap`).
- **Tooltip:** `matTooltip` mit Tastenkürzel (Touch zeigt ihn nicht; reiner Zusatz). `MatTooltipModule` in `reports.ts` ergänzen (heute nicht importiert).
- **Tastatur:** nativer `<button>`: Enter/Space, Fokusring von Material; Tab-Reihenfolge Toggle → Vorheriger Monat → Nächster Monat → Grid → Stats. Kürzel-Hinweis zusätzlich per `aria-describedby` auf ein sr-only-Element (Text = Tooltip-Text), damit Screenreader-Nutzer ihn ohne Hover hören.
- **Verhalten Aktivieren:** `svc.toggleMultiSelect()` → Modus an, Auswahl **leer** (kein aktueller Tag als Vorauswahl: ein ungewollt vorbelegter Tag fließt sonst unbemerkt in den Batch-Eintrag; Drag-Einstieg nimmt dagegen den Starttag bewusst mit). Anker wird erst beim ersten Shift+Pfeil auf den dann fokussierten Tag gesetzt. Deaktivieren: Auswahl wird verworfen (bestehende Semantik von `toggleMultiSelect`); Risiko versehentlichen Verwerfens einer größeren Auswahl → akzeptiert, Escape verhält sich gleich. Live-Region sagt „Mehrfachauswahl beendet“ an.
- **Sichtbares Zählfeedback** (optional, klein): neben dem Toggle „N Tage“-Chip (`aria-hidden`, die Live-Region trägt den Text), sodass Sehende die Auswahl nicht erst im Day-Panel finden. Erst nach Rückfrage (Frage 8).
- **Kalender-Anpassungen für den Modus:** neuer Input `multiSelectActive = input(false)`; `aria-multiselectable="true"` am Grid, solange aktiv (nicht über `size>0`, damit leerer aktiver Modus korrekt ist); Einzelauswahl-Optik/`aria-selected` für `selectedDate` nur, wenn `!(multiSelectActive() || size>0)`. Standardwert `false` hält `calendar.spec.ts`/`calendar-keyboard.spec.ts` grün.
- **Dark Mode / Mobile-Breite:** nur M3-Tokens; Zielgröße = Material-Button (≥ 40px); Fokusring über Material (Button) bzw. bestehenden Zellenring (Grid). Kontrast Aktiv-Zustand (on-secondary-container auf secondary-container) in Hell/Dunkel per Handcheck notieren.

## 4. ARIA

| Element | Maßnahme |
|---|---|
| Grid | `[attr.aria-multiselectable]="multiSelectActive() ? 'true' : null"` (gültig für `role=grid`) |
| Zellen | `aria-selected` bleibt „visuelle Auswahl“ (`isSelected`), im aktiven Modus nur Mehrfachmenge; kein `aria-pressed` (Teil 1 hat es entfernt) |
| Toggle | `aria-pressed`, `aria-describedby` → Hinweis |
| Live-Region | `LiveAnnouncer` (CDK, im Projekt via Dashboard etabliert; `polite`) statt eigenem DOM-Element: Modus an, Modus aus, Anzahl nach **Tastaturaktionen** |
| Hinweis Tastenkürzel | siehe Toggle-`aria-describedby`; im Modus-an-Ansage mitsprechen (einmalig, kurz) |

Details Live-Region:
- Ansage nach Tastaturänderung: Handler setzt ein Flag `_announceNext`, ein `effect` auf `multiSelectedDates().size` (in `untracked` ansagen, Flag zurücksetzen) sagt „Ausgewählte Tage: N“ an. Nur tastaturinitiiert, damit Pointer-Drag nicht pro Zelle spammt (Alternative: immer ansagen; Spam-Risiko beim Drag).
- Modus an/aus: Effect auf `multiSelectActive()` (ohne Fokus!). Beim ersten Render nicht ansagen (initialer Wert ignorieren).
- Doppelansage Fokus-Zelle (`ausgewählt/nicht ausgewählt` durch `aria-selected`) + Live-Region ist erwartbar; `polite` reiht hinter die Fokusansage ein. Per Handtest prüfen.
- Shift+Pfeil und Screenreader: NVDA/JAWS schalten in Grids in den Fokusmodus (Shift+Pfeil kommt an); VoiceOver nutzt VO-Tasten, Shift+Pfeil kommt an. Im Browse-Modus von NVDA (wenn der Fokus nicht im Grid ist) würde Shift+Pfeil Text markieren — dort greift unser Handler nicht und `user-select:none` an der Card verhindert Markierung. Nur per Handtest zu bestätigen (Frage 9: Prüfumfang).
- Plural: ngx-translate ohne ICU; Formulierung pluralfrei „Ausgewählte Tage: {{count}}“ / „Selected days: {{count}}“ vermeidet „1 Tage“. Alternative „{{count}} Tage ausgewählt“ (wie im Auftrag) hat das Singular-Problem (so auch `reports.batchEntryButton`).

## 5. i18n (minimal, Deutsch duzen, Paritätstest de/en)

Neu in `public/i18n/de.json` / `en.json` (Namensraum nach Verwender):

| Key | de | en |
|---|---|---|
| `reports.multiSelectButton` | Mehrfachauswahl | Multi-select |
| `reports.multiSelectTooltip` | Mehrere Tage auswählen. Tastenkürzel: Umschalt + Pfeiltasten | Select multiple days. Shortcut: Shift + arrow keys |
| `shared.calendarMultiSelectOnAria` | Mehrfachauswahl aktiv. Leertaste wählt einen Tag, Umschalt + Pfeiltasten wählen einen Bereich, Escape beendet. | Multi-select on. Space toggles a day, Shift + arrow keys select a range, Escape ends it. |
| `shared.calendarMultiSelectOffAria` | Mehrfachauswahl beendet | Multi-select ended |
| `shared.calendarSelectedCountAria` | Ausgewählte Tage: {{count}} | Selected days: {{count}} |

Bestehend und weiterverwendet: `reports.cancelMultiSelectAria`, `reports.batchEntry*`, `common.cancel`. Keine Anrede „du“ nötig, alle Texte neutral/imperativ. Spec-`setTranslation` muss die `shared.*`-Keys enthalten (sonst Roh-Key in der Ansage; bei gemocktem Announcer Erwartung gegen den übersetzten Text).

## 6. Testplan (Vitest/jsdom, feste Daten, TZ-unabhängig)

Konventionen wie Teil 1: `vi.useFakeTimers` + `vi.setSystemTime(new Date(2026, 9, 15, 12))`, lokale Date-Konstruktoren, Vergleiche über `dayKey`/`getFullYear/Month/Date`, Fixture im `document`, `new KeyboardEvent('keydown', { key, shiftKey: true, bubbles: true, cancelable: true })` + `detectChanges()` + `await fixture.whenStable()`. `LiveAnnouncer` per `{ provide: LiveAnnouncer, useValue: { announce } }` mocken (Muster `dashboard.spec.ts:131/181`): kein `setTimeout` im Test, **kein Flush echter Timer** nötig (`announce()` selbst arbeitet im Original mit Timer; Mock vermeidet das). Hinweis: Die Anweisung „kein setTimeout-Flush“ steht so nicht in `web/CLAUDE.md`; sinngemäß gilt: `onCardPointerUp` nutzt `setTimeout`, daher Assertions nicht von Timern abhängig machen und `afterNextRender` über `detectChanges`, nicht Timer, auslösen (Plan Teil 1, Schritt 9).

**Vite-SSR-Falle:** keine nackte Import-Referenz als Klassenfeld-Initializer. Neue Felder der Komponente (`signal<string | null>(null)`, `new Set<string>()`, `inject(LiveAnnouncer)`) sind lokal/Aufrufe — unkritisch; keine neue Konstante aus dem Util als Feldwert. Gegencheck im **Vollauf**, nicht nur Einzelspec.

Pure Util: keine Änderung nötig (Shift nutzt `nextFocusDate(key, from, false)`). Optional ein reiner Helfer `rangeDiff(oldKeys, newKeys, base)` in `calendar-keyboard.util.ts` (pure, ohne DOM) — testbar mit festen Keys (Erweitern, Verkleinern, Umkehren, Base wird nie entfernt, Monats-/Jahresgrenze). Empfehlung: ja, dann liegt die Anker-Mathematik außerhalb der Komponente.

Komponenten-Spec (neue Datei `calendar-multiselect.spec.ts`; **kleine Host-Komponente** im Spec, die `dragSelected` → additives Set, `daysDeselected` → Entfernen, `multiSelectEnded` → Modus aus verdrahtet und `multiSelectedDates`/`multiSelectActive` zurückgibt; spiegelt das Parent-Verhalten ohne `ReportsService`):
1. Shift+ArrowRight ohne Modus: `dragSelected` mit [15.,16.10.], Fokus 16.10., Modus-an-Ansage; kein `dateSelected`; `defaultPrevented` true.
2. Folgeschritte: Shift+→ ×3 ergibt 15-18; Shift+← ×1 verkleinert auf 15-17 (`daysDeselected` [18.]); Umkehr über den Anker (Anker 15., Shift+← ×2: 14-15, 16-17 abgewählt).
3. Vorherige Auswahl bleibt: Basis {10.,11.10.}, Anker 15. erweitern/verkleinern entfernt nie 10./11.
4. Shift+Down ±7, Shift+Home/End (Mo/So), Shift+PageUp/Down über Monatsgrenze (`monthChanged`, Fokus per `afterNextRender` korrekt, Anker bleibt, Bereich enthält Tage beider Monate); Jahreswechsel 31.12.→01.01.
5. Plain Pfeil im Modus: Fokus bewegt, **keine** Emission, Anker verworfen (nächstes Shift+Pfeil startet am neuen Fokus, Basis neu).
6. Enter/Space im Modus: `dateSelected` (einmal, `repeat` ignoriert), Anker verworfen. Strg+Space / Shift+Space / Ctrl+Shift+Pfeil / Alt+Shift+Pfeil / Meta+Shift+Pfeil: unbehandelt (`defaultPrevented` false, keine Emission).
7. Escape im Modus: `multiSelectEnded` genau einmal, `defaultPrevented` true, Fokus bleibt; außerhalb des Modus: unbehandelt.
8. `aria-multiselectable="true"` nur bei `multiSelectActive`; `aria-selected` bei aktivem Modus mit leerer Menge: **alle** `false` (auch `selectedDate`); Default-Modus unverändert (Regression der Teil-1-Tests).
9. Live-Region: Modus an/aus je einmal, Anzahl nach Tastenaktion = Mengengröße (inkl. Arbeitstage-Filter: Host mit Filter nachbilden, Bereich über Wochenende → Ansage zählt gefilterte Menge); **kein** Announce bei Pointer-Drag (Methodenaufruf `onCardPointerDown/Move/Up` mit gemocktem `elementFromPoint`); kein Announce beim initialen Render.
10. Anker-Reset: `onCardPointerDown`, `focusout` nach außen (relatedTarget außerhalb), Modus extern aus.
11. Kein Fokusdiebstahl: Setzen von `multiSelectActive`/`multiSelectedDates` per `setInput` ändert `document.activeElement` nicht.
12. Regression: `calendar.spec.ts` (Tap, Drag [3,4,5] emittiert `dragSelected` unverändert) und alle Teil-1-Tests in `calendar-keyboard.spec.ts` (insbesondere `calendar-keyboard.spec.ts:299` „lässt Ctrl/Alt/Meta/Shift+Pfeil, Tab und andere Tasten unbehandelt“ mit `ArrowRight+shiftKey` und `Home+shiftKey` → **muss angepasst werden**, weil Shift+Nav jetzt behandelt wird; diese Fälle durch Shift+Enter/Shift+Space/Ctrl+Shift+Pfeil ersetzen und im PR benennen).

`reports.service.spec.ts` (neuer `describe`, vorhandenes Provider-Muster mit Fakes): `removeDatesFromSelection` entfernt nur genannte Keys, No-op bei nicht vorhandenen, keine Filterwirkung; `endMultiSelect` idempotent (Modus aus, Menge leer, zweimal aufgerufen bleibt aus); `addDateRangeSelection` mit Wochenende filtert weiter (bisher ungetestet: kleine Regression, `workdays` über `getSettings`-Fake); `toggleMultiSelect` → Modus an, Menge leer. Keine Datumsabhängigkeit (feste `new Date(2026, 9, …)`; 3.10.2026 = Samstag nur über feste Konstruktoren, Wochentag nicht aus „heute“).

`reports.spec.ts` ist bisher nur ein Mini-Test (`goToSettings`); ein Rendering-Test für Button/`aria-pressed` bräuchte großes Setup (Service-Fake, Tabs, Dialoge). Empfehlung: Button-Verdrahtung (`aria-pressed`, Klick → `toggleMultiSelect`, `multiSelectEnded` → `endMultiSelect`, Fokus zurück auf Toggle nach „Abbrechen“) mit einem schlanken `ReportsComponent`-Spec mit `provide ReportsService` Fake prüfen, falls das ohne Kopfschmerzen geht; sonst manuell (Checkliste unten) und im PR ausweisen.

TZ-Läufe (Vollauf, jeweils): `TZ=Europe/Berlin`, `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland`, `TZ=UTC` mit `npm test -- --watch=false`; dazu `npm run build -- --configuration production`. Wichtig: DST-Wochenenden (25.10.2026) im Bereichstest über die Zeitumstellung (`_dateRange` nutzt `setDate(+1)` auf lokaler Mitternacht, DST-sicher; Test mit Bereich 24.-27.10.2026 und `getDate()` je Tag).

## 7. Aufwand, PR-Zuschnitt, Risiken

**Aufwand:** ~120-160 Zeilen Komponentencode (Inputs/Outputs, Anker-State, Handler-Zweig, Effects, Template-/Style-Anteile), ~25 Zeilen Service, ~30 Zeilen Reports-Template/SCSS/TS, 5 i18n-Keys je Sprache, ~350-450 Zeilen Tests. Mittel; Risiko liegt im Handler-Umbau und Fokus.

**Zuschnitt:** ein PR genügt (`Refs`/`Closes #377` nach Maintainer-Entscheid; Teil 1 ist gemergt), weil Button, Tastaturkürzel und Service-Ergänzung dasselbe Modell teilen und einzeln wenig sinnvoll sind. Falls klein halten gewünscht: **PR 2a** = Button + `multiSelectActive`/`aria-multiselectable` + Escape + `endMultiSelect` + Live-Region Modus (Einstieg ohne Shift, barrierefreier Kernnutzen); **PR 2b** = Shift+Pfeil-Bereich mit Anker, `daysDeselected`, `removeDatesFromSelection`. Empfehlung: ein PR (Frage 1).

**Risiken**
- *Browser-/OS-Kürzel:* Shift+Pfeil/Home/End/Page ohne Ctrl/Alt/Meta kollidieren nicht mit Browser-Kürzeln (nur Textmarkierung, durch `preventDefault` + `user-select:none` unterbunden); Ctrl+Shift+Page* bewusst frei gelassen. Shift+PageUp/Down scrollt sonst die Seite: nur bei Fokus im Grid abgefangen.
- *Screenreader:* Shift+Pfeil im Browse-Modus (NVDA) markiert Text statt Handler; Grid erzwingt i. d. R. Fokusmodus — Handtest. Doppelansagen (Zellenansage + Live-Region) bei jeder Shift-Taste; `polite` und nur ein Count-Satz mindern das.
- *Fokusverlust:* „Abbrechen“ (Day-Panel) verschwindet beim Klick; Fokus auf Toggle zurückgeben. Monatswechsel per Shift+Page: Zellen werden neu erzeugt, Fokus über `afterNextRender` wie in Teil 1; Anker ist Key, nicht Element, bleibt gültig.
- *Anker-/Basisfehler:* verworfene/falsche Basis könnte bei Shift+Gegenrichtung vorher gewählte Tage entfernen → Tests 3 und 10 sind Pflicht; `remove` immer um `_rangeBase` bereinigen.
- *Zwei Wahrheiten für den Modus:* Der Modus liegt im Service, die Komponente bekommt ihn per Input; `endMultiSelect`/`toggle` müssen idempotent bleiben, Escape emittiert nur, wenn der Input `true` ist.
- *Bestehende Lücke Modus bleibt aktiv nach Batch-Speichern/leerer Menge:* mit dem Button auffälliger (Modus an, nichts ausgewählt, Button „aktiv“). Beenden nach Batch-Speichern empfohlen (Frage 7).
- *Visueller Wechsel:* Einzelauswahl-Kreis verschwindet beim Einschalten des Modus (Absicht, signalisiert „nichts ausgewählt“); im PR erwähnen.
- *Sticky-Keys-Nutzer:* Button deckt das ab; Escape/Space brauchen keine Kombination.

**Manuelle Prüfliste (PR-Body)** — Chrome (axe DevTools + Lighthouse auf /reports, Tab Täglich), Hell und Dunkel, 320px/375px:
- [ ] Toggle sichtbar über dem Kalender, Tab-Reihenfolge Toggle → Monat-Buttons → Grid; Enter/Space schaltet, `aria-pressed` im Accessibility-Tree, Fokusring sichtbar, Tooltip mit Kürzel
- [ ] Button an: Auswahl leer, Einzelauswahl-Kreis weg, Ansage „Mehrfachauswahl aktiv …“; aus: Auswahl verworfen, Ansage „beendet“
- [ ] Im Modus: Space/Enter toggelt Tage (Day-Panel-Button „N Tage“ zählt mit), Mehrfach-Tap per Maus gemischt mit Tastatur
- [ ] Shift+Pfeil aus dem Ruhezustand: Modus an, Bereich wächst, Shift+Gegenrichtung schrumpft, Umkehr über den Anker; Shift+Home/End/PageUp/PageDown; über Monats- und Jahresgrenze; Sa/So im Bereich werden übersprungen, Zahl stimmt
- [ ] Vorher gewählte Tage bleiben beim Verkleinern; Pfeil ohne Shift committet, neuer Bereich beginnt am neuen Fokus
- [ ] Escape beendet den Modus, Fokus bleibt; „Abbrechen“ im Day-Panel bringt den Fokus zum Toggle
- [ ] Batch-Eintrag per Tastatur (Dialog öffnen/schließen, Fokus zurück, Modus-Zustand sinnvoll danach)
- [ ] Maus-Drag und Touch-Drag unverändert (inkl. Wochenend-Filter), kein Anker-Rest nach Drag
- [ ] axe: 0 Verstöße (`aria-multiselectable` gültig, `aria-pressed` auf Button, keine ungültigen Rollen); Lighthouse-Score notieren
- [ ] Screenreader-Stichprobe, soweit möglich: Ansage Anzahl, keine Doppel-/Dauerflut, Shift+Pfeil kommt im Grid an
- [ ] Kontrast Aktiv-Zustand des Toggles und Fokusring auf `multi-selected`-Zellen, Hell/Dunkel, forced-colors-Stichprobe

## Offene Fragen (mit Empfehlung; Entscheidung Hauptsession)

1. **PR-Zuschnitt:** ein PR (Button + Shift) oder 2a/2b? *Empfehlung: ein PR.* Issue-Abschluss mit `Closes #377` erst nach manueller Prüfung beider Teile?
2. **Button-Position:** Toolbar über dem Kalender (3 Tab-Stopps bis Grid, dafür sichtbar/Mobile-nah) oder unter dem Grid? *Empfehlung: über dem Kalender.*
3. **Aktivieren ohne Vorauswahl** (leere Auswahl, Anker erst bei Shift+Pfeil), Einzelauswahl-Kreis im aktiven Modus ausblenden? *Empfehlung: ja, ja.*
4. **Service-Ergänzung:** `removeDatesFromSelection` + `endMultiSelect` (Shift+Gegenrichtung verkleinert, Escape idempotent) — oder rein additiv ohne Verkleinern? *Empfehlung: Ergänzung (klein, getestet).*
5. **Escape beendet den ganzen Modus** inkl. Verwerfen der Auswahl (statt zweistufig: erst Anker, dann Modus)? *Empfehlung: ganzer Modus, einfach und vorhersagbar, identisch zum Button-Aus.*
6. **Live-Region:** `LiveAnnouncer` (testbar per Mock) + pluralfreie Formulierung „Ausgewählte Tage: N“ statt „N Tage ausgewählt“ (Singular „1 Tage“); Ansage nur nach Tastaturaktionen? *Empfehlung: ja, ja, ja.* (Wenn „N Tage ausgewählt“ gewünscht ist: zwei Keys für 1/mehrere.)
7. **Modus nach Batch-Speichern beenden** (heute bleibt er aktiv mit leerer Menge) und Fokus nach „Abbrechen“ auf den Toggle? *Empfehlung: beides in diesem PR, kleine Änderungen, sonst wirkt der neue Button kaputt.*
8. **Sichtbarer Zähler-Chip** neben dem Toggle? *Empfehlung: nicht in diesem PR (Scope), Folge-Issue falls gewünscht.*
9. **Prüfumfang:** reicht axe + Tastaturtest + Checkliste, kein bestimmter Screenreader (wie bei Teil 1)? Shift+Pfeil im NVDA-Browse-Modus ist nur so zu klären. *Empfehlung: ja, Befunde als Folge-Issue.*
10. **Shift+Klick (Mausbereich) und Ctrl+Shift+Home/End** bewusst nicht Teil? *Empfehlung: nicht in diesem Issue.*
11. **Teil-1-Test anpassen:** der Bestandstest `calendar-keyboard.spec.ts:299` (Shift+ArrowRight/Shift+Home unbehandelt) wird durch das neue Verhalten ungültig und wird auf Shift+Enter/Space/Ctrl+Shift umgestellt. Einverstanden?

## Entscheidungen zu den offenen Fragen (Hauptsession)

Verbindliche Produktentscheidung: Button UND Shift+Pfeil (beides).

1. Ein PR (kein Split 2a/2b), Commits je Schicht.
2. Button oben in der Toolbar über dem Kalender.
3. Aktivieren ohne Vorauswahl; Einzelauswahl-Kreis im aktiven Modus ausblenden.
4. Kleine, additive Service-Ergänzung: `removeDatesFromSelection(dates)` und idempotentes `endMultiSelect()`; Kalender: Input `multiSelectActive`, Outputs `daysDeselected`, `multiSelectEnded`; `dragSelected` und Pointer-Methoden unverändert.
5. Escape beendet den ganzen Modus inklusive Auswahl.
6. `LiveAnnouncer` mit pluralfreier Formulierung („Ausgewählte Tage: N"), Ansage nur nach Tastaturaktionen; im Test gemockt.
7. In diesem PR: Modus nach Batch-Speichern beenden und Fokus nach „Abbrechen" auf den Toggle setzen.
8. Kein sichtbarer Zähler-Chip in diesem PR.
9. Axe + Tastaturtest + Checkliste reichen; Screenreader-Befunde (Shift+Pfeil im NVDA-Browse-Modus) nur per Handtest, ggf. Folge-Issue durch die Hauptsession.
10. Shift+Klick und Ctrl+Shift+Home/End ausklammern.
11. Bestandstest `calendar-keyboard.spec.ts:299` auf Shift+Enter/Shift+Space/Ctrl+Shift umstellen (Verhalten für diese Kombinationen bleibt „unbehandelt").
12. i18n: je 5 neue Keys de (duzen)/en, minimale Diffs; `MatTooltipModule` in `reports.ts` ergänzen.
