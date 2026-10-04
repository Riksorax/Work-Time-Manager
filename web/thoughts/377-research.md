# Web-Research: #377 — Web-Kalender: Tageszellen per Tastatur bedienbar (Accessibility)
Datum: 2026-10-04
Feature-Ordner: web/src/app/shared/components/calendar/ (Verwender: web/src/app/features/reports/)

Kein Flutter-Port: reine Web-Accessibility-Erweiterung einer bestehenden Komponente. Es gibt keine Flutter-Quelle,
kein Backend-/Firestore-/Domain-Mapping nötig. Auf Issue #377 liegen zwei Auto-Bugfix-Kommentare: gestartet, dann
„zurückgestellt: Scope und Design (Shift+Pfeil, Fokusring) vorab abstimmen“ (Neuversuch = `auto-bugfix:started`-Kommentar löschen).

## 1. Ist-Zustand

### Komponente (`calendar.ts`, 332 Zeilen, Inline-Template, OnPush)
- Inputs: `selectedDate` (required, `Date`), `daysWithEntries: number[]` (nur Tag-des-Monats, gilt für den angezeigten Monat),
  `multiSelectedDates: Set<string>` (`yyyy-MM-dd`), `bundesland`.
- Outputs: `dateSelected: Date`, `monthChanged: {year, month(1-12)}`, `dragSelected: Date[]`.
- State: `viewDate` (Signal, 1. des angezeigten Monats). Ein `effect` setzt `viewDate` bei **jeder** Änderung von
  `selectedDate` auf dessen Monat zurück (`untracked`).
- Template-Struktur heute: `div.calendar-card` (Pointer-Handler) > Header (zwei `mat-icon-button`, `.current-month`
  mit `aria-live="polite"`) > `div.calendar-grid[role=grid][aria-label=Monat Jahr]` mit **flachen** Kindern:
  `div.weekday-label[role=columnheader]` x7, `div.calendar-day.empty[role=gridcell][aria-hidden]` (Prefix), je Tag
  `div.calendar-day[role=gridcell][data-date][aria-label][aria-selected][aria-pressed]` + `matTooltip` (nur Feiertag).
  CSS-Grid mit 7 Spalten, `gap: 4px`. **Kein `role=row`, kein `tabindex`, kein Key-Handler.**
- `aria-label` pro Zelle: `d. MMMM yyyy` (DatePipe, `LOCALE_ID` ist app-weit fest `de-DE`, also auch in der EN-UI deutsch;
  bestehend, nicht Teil dieses Issues), bei Feiertag `shared.calendarHolidayAria` (`{{date}}, Feiertag: {{name}}`) aus #371.
- „Heute“ kommt aus `TodayService.today()` (#382), nur als CSS-Klasse `.today`, **ohne** ARIA (`aria-current` fehlt).
- Eintragspunkt `.entry-dot` ist `aria-hidden`: „hat Eintrag“ ist für Screenreader nirgends verfügbar.
- Pointer-Modell: `pointerdown/move/up/cancel` am Card-Container, Zelle per `document.elementFromPoint` + `closest('[data-date]')`.
  Tap (kein Drag) -> `dateSelected`; Drag (anderer Tag berührt) -> bei jedem Move `dragSelected(Bereich Start..Aktuell)`.
  `pointerdown` ruft `preventDefault()`, `setPointerCapture` auf der Card. `.calendar-card` hat `user-select:none; touch-action:none`.
- `changeMonth(delta)` (Header-Buttons): setzt `viewDate`, emittiert `monthChanged`. `selectedDate` bleibt unverändert.

### Verwender
Genau einer: `features/reports/reports.html` Zeile 17-26 (Tab „Täglich“). Verdrahtung:
- `(dateSelected)="onCalendarDayTap($event)"` -> `ReportsService.isMultiSelectActive() ? toggleDateSelection(d) : selectDate(d)`.
- `(dragSelected)="svc.addDateRangeSelection($event)"` -> schaltet Mehrfachmodus **ein**, fügt Bereich **additiv** zu
  `selectedDates` hinzu, filtert Nicht-Arbeitstage (`settings.workdays`) heraus.
- `(monthChanged)="svc.onMonthChanged($event)"` -> `_viewMonth` -> lädt Monatseinträge (`daysWithEntries`).
- `[attr.aria-label]="'reports.calendarAria'"` auf dem Host `<app-calendar>` (Element ohne Rolle, siehe 3).
- `selectDate(date)` setzt zusätzlich `_viewMonth`, wenn der Monat wechselt.
- Wochen-/Monatslisten (reports.html 277/421) rufen `svc.selectDate` per Button, sind nicht betroffen.

### Mehrfachauswahl-Modell (wichtig für Frage 2)
- Der Mehrfachmodus wird **nur durch Drag** betreten (`addDateRangeSelection`). `toggleMultiSelect()` wird in der UI nur
  vom „Abbrechen“-Button im Modus verwendet. Es gibt **keinen** Einstieg ohne Pointer-Drag. Im Modus toggelt ein Tap einzelne Tage.
- Visuell: `.selected` nur, wenn `!hasMultiSelected()`; sonst `.multi-selected` je Key in `multiSelectedDates`.
  `aria-selected` dagegen hängt immer an `selectedDate` (auch wenn visuell die Mehrfachauswahl gilt) und `aria-pressed`
  (auf `gridcell` nicht erlaubt) an der Multi-Auswahl -> **visuell und ARIA inkonsistent**.
- Der Batch-Button („N Tage eintragen“) steckt im Day-Panel, nicht im Kalender; er erscheint dynamisch und wird nicht angesagt.

### Tests (`calendar.spec.ts`, 221 Zeilen)
- Fester Zeitpunkt `vi.useFakeTimers` + `vi.setSystemTime(new Date(2026, 9, 15, 12))`, lokale Date-Konstruktoren.
- Pointer-Regression ruft `onCardPointerDown/Move/Up` **direkt als Methoden** auf, mocked `document.elementFromPoint`
  und `setPointerCapture`. Diese Methodennamen/Signaturen und der `[data-date]`-Selektor sind der Vertrag, den neue
  Tests/Änderungen nicht brechen dürfen. `cell(key)` = `[data-date="..."]`, Klassen `.holiday/.selected/.today` werden geprüft.

## 2. Umfang: MVP vs. Vollausbau

| Baustein aus dem Issue | Aufwand | Risiko | Empfehlung |
|---|---|---|---|
| ARIA-Struktur reparieren (`role=row`, `aria-pressed` raus, `aria-selected` konsistent, `aria-current`) | mittel (Template-Umbau auf Wochenzeilen) | mittel (Layout/Tests, die Zellen per Klasse finden) | MVP, Voraussetzung |
| Roving tabindex + Pfeile ±1/±7, Home/End, PageUp/PageDown | mittel | gering | MVP |
| Enter/Leertaste -> `dateSelected` | klein | gering | MVP |
| Sichtbarer Fokusring | klein | gering (Kontrast prüfen) | MVP |
| Tests (Keyboard + ARIA) | mittel | gering | MVP |
| Shift+Pfeil-Mehrfachauswahl | mittel | **hoch** (Semantik, siehe unten) | **eigener Folge-PR** |
| AXE-Check | klein bis mittel | — | manuell im PR; Automatisierung nur nach Rückfrage |

### Empfehlung
Zwei PRs. **PR 1 (MVP)** liefert alles außer Shift+Pfeil: Tastatur- und Screenreader-Nutzer können einen Tag wählen und
den Monat wechseln, das ist der Kern („im Täglich-Tab keinen Tag auswählen“). Das Issue verlangt AXE-Konformität
(`web/AGENTS.md`: „MUST pass all AXE checks“) — die heutige Grid-Struktur ohne `row` ist wahrscheinlich selbst ein Verstoß
(siehe 3), daher gehört die Strukturkorrektur in PR 1.
**PR 2** ergänzt Shift+Pfeil, sobald die Produktentscheidung zur Mehrfachauswahl steht (siehe Fragen 1-2).

### Shift+Pfeil und das Drag-Modell
Technisch passt es zum bestehenden Vertrag: Shift+Pfeil kann `dragSelected(range(anker, neuerFokus))` emittieren, `Reports`
braucht keine Änderung. Aber die Drag-Semantik überträgt sich nur teilweise:
1. **Nur additiv.** `addDateRangeSelection` fügt hinzu, entfernt nie. Mit der Maus „zieht“ man nur in eine Richtung weiter;
   per Tastatur erwartet man, dass Shift+Gegenrichtung den Bereich wieder verkleinert (APG/Excel). Das ginge nur mit einem
   neuen Output oder Ersetzen-Semantik in `ReportsService` (Service-Änderung).
2. **Nicht-Arbeitstage werden gefiltert** (Service). Startet man auf Sa/So oder läuft über das Wochenende, „verschwindet“
   die Auswahl scheinbar. Beim Drag ist das sichtbar, bei Tastaturfokus verwirrend.
3. **Modus-Einstieg implizit.** Der erste `dragSelected` schaltet `isMultiSelectActive` ein; danach bedeutet Enter/Leertaste
   „Tag umschalten“ (Parent-Logik `onCalendarDayTap`), vorher „Tag wählen“. Der Komponente fehlt dazu die Info, ob der Modus
   aktiv ist (sie kennt nur `multiSelectedDates.size`, bei aktivem Modus mit 0 Treffern ist sie blind). Für Screenreader muss
   der Moduswechsel angesagt werden (`aria-multiselectable` + Live-Region „N Tage ausgewählt“, neuer i18n-Key).
4. **Anker** ist in der Komponente nur während eines Drags vorhanden; bei Tastatur braucht es einen eigenen Anker-State
   (gesetzt beim ersten Shift+Pfeil, gelöscht bei Pfeil ohne Shift, Enter, Escape?). Escape zum Abbrechen existiert nicht.
5. **Kein Tastatur-Einstieg ohne Shift.** Wer Shift nicht benutzen kann (Einhand-/Sticky-Keys-Nutzer), käme gar nicht in den
   Mehrfachmodus. Ein sichtbarer „Mehrfachauswahl“-Button (Reports-UI) wäre der barrierefreiere Einstieg, ist aber eine UI-Entscheidung.
Fazit: Shift+Pfeil in PR 1 würde Scope und Risiko stark erhöhen; ohne Klärung von 1-5 nicht sinnvoll umsetzbar.

## 3. ARIA-Struktur

Prüfung gegen WAI-ARIA 1.2 / APG „Date Picker (Dialog) Grid“ (Annahme aus dem Wissensstand, kein axe-Lauf möglich):

| Punkt | Ist | Soll |
|---|---|---|
| `role=grid` Pflicht-Kinder | direkte Kinder sind `columnheader`/`gridcell` ohne `row` | `grid > row > (columnheader \| gridcell)`; axe-Regeln `aria-required-children` und `aria-required-parent` schlagen vermutlich an |
| Wochenzeilen | CSS-Grid flach | Template-Umbau: `computed` `weeks` (Array je 7 Zellen, `null` = leer) und je Woche `div[role=row]`. Variante `display: contents` auf `row` ist möglich, hat aber historisch Probleme im A11y-Tree; Zeile als eigenes 7-Spalten-Grid bevorzugen |
| Leere Zellen | `gridcell` + `aria-hidden` | in der Zeile belassen (oder `role=presentation`); nie fokussierbar |
| `aria-pressed` auf `gridcell` | gesetzt | **nicht erlaubt** (nur `button`), entfernen; Mehrfachauswahl über `aria-selected` ausdrücken |
| `aria-selected` | = `selectedDate`, auch im Mehrfachmodus | = visuell Ausgewählte: `hasMultiSelected() ? isMultiSelected(d) : isSameDay(d, selectedDate)` (Wert `"false"` explizit lassen, Grid ist selektierbar) |
| `aria-multiselectable` | fehlt | auf dem Grid `true`, solange `hasMultiSelected()` (PR 2) |
| Heute | nur `.today` | `[attr.aria-current]="isToday(d) ? 'date' : null"` |
| Zellenlabel | `d. MMMM yyyy` (+ Feiertag) | Wochentag ergänzen: `EEEE, d. MMMM yyyy` (Konsistenz mit Day-Titel `reports.html:53`), da Screenreader beim Pfeilen sonst nur Zahl+Monat hören; ändert `calendar.spec.ts`-Erwartung `toContain('5.')` nicht |
| „Hat Eintrag“ | nur Punkt, `aria-hidden` | Hinweis ins Label (z. B. `, Eintrag vorhanden`), WCAG 1.3.1; optional, braucht neuen Key |
| Host `<app-calendar aria-label>` | Label auf Element ohne Rolle | wahrscheinlich axe-Befund (`aria-prohibited-attr`/Label auf generic). Label entfernen (Grid trägt den Monat) oder `role="group"` auf den Host; erst mit axe-Lauf bestätigen |
| Live-Region | `.current-month[aria-live=polite]` existiert | reicht für Monatswechsel (Text „Oktober 2026“ wird angesagt); beim Tastatur-Monatswechsel kommt zusätzlich die Fokusansage der neuen Zelle, möglicherweise doppelt — im Screenreader-Handtest prüfen, ggf. `aria-live` nur bei Button-Wechsel |
| Tooltip | `matTooltip` nur für Feiertag | Tooltip erscheint bei Tastaturfokus mit (FocusMonitor) und setzt `aria-describedby` auf denselben Namen, das Label enthält ihn schon: Doppelansage möglich, im Handtest prüfen |

## 4. Fokusverwaltung (OnPush/Signals)

Grundsatz laut APG: **Fokus folgt nicht der Auswahl.** Pfeile bewegen nur den Fokus; Auswahl (und damit Nachladen im
Reports-Service, teuer) erst per Enter/Leertaste. Das Issue sagt dasselbe.

- **Roving-State:** neues `private readonly _focusKey = signal<string | null>(null)` (Key `yyyy-MM-dd`, wie `dayKey`).
  `computed focusableKey`: `_focusKey` wenn im angezeigten Monat, sonst `selectedDate` wenn im Monat, sonst „heute“ wenn im
  Monat, sonst Tag 1. So hat der Grid **immer genau eine** Zelle mit `tabindex="0"`, auch nach Monatswechsel per Header-Button
  (selectedDate liegt dann oft im anderen Monat). Alle anderen `tabindex="-1"` (per `[attr.tabindex]`).
- **Event-Delegation:** ein `(keydown)` am Grid (nicht pro Zelle, wegen Performance 30+ Handler); Zelle über
  `event.target.closest('[data-date]')`. Keine Modifikatoren außer Shift (Ctrl/Alt/Meta unverändert durchlassen).
  `preventDefault()` für Pfeile/Home/End/PageUp/PageDown/Space (sonst scrollt die Seite). Host-Listener nur über `host: {}`, nie `@HostListener`.
- **Pure Logik auslagern:** `shared/utils/calendar-keyboard.util.ts` mit `nextFocusDate(key, from): Date | null`
  (Pfeile `+-1/+-7` über `new Date(y, m, d + n)`, nie über Millisekunden-Arithmetik, DST-sicher; PageUp/Down = +-1 Monat mit
  Klemmen auf den Monatsletzten, 31.01. -> 28./29.02.). Importiert nur in Methoden verwenden (Vite-SSR-Falle, siehe 7).
- **Fokus setzen:** gleicher Monat -> DOM-Knoten bleiben erhalten (`track day.date.getTime()`, `daysInMonth` erzeugt zwar neue
  `Date`-Objekte, aber identische Zeitwerte), also `_focusKey.set(...)` und direkt das Element fokussieren
  (`querySelector('[data-date=..]').focus()`; die `tabindex`-Aktualisierung passiert im nächsten CD-Lauf, `focus()` auf ein
  `tabindex=-1`-Element funktioniert trotzdem). Monatswechsel (Pfeil über die Grenze, PageUp/Down) -> Zellen werden **neu
  erzeugt**, Fokus ginge verloren: `changeMonth(delta)` aufrufen (emittiert `monthChanged`, Reports lädt den Monat) und
  Fokus per `afterNextRender` (Injector) setzen. Kein `effect` auf Inputs, der Fokus stiehlt: fokussiert wird **nur** nach
  Tastatureingaben (internes Flag/direkter Aufruf im Handler), nie bei Input-Änderungen (z. B. Mitternachts-Rollover #382,
  `selectedDate`-Effekt, Nachladen der Einträge).
- **Interaktion mit `selectedDate`-Effekt:** setzt `viewDate` bei jeder Änderung von `selectedDate` zurück. Enter auf einem
  Tag im anderen Monat -> Parent ruft `selectDate`, `_viewMonth` und `selectedDate` ziehen nach, `viewDate` landet im selben
  Monat wie die Zelle: kein Springen. Risiko nur, wenn ein Verwender `selectedDate` nicht aktualisiert (dann bliebe `viewDate` im neuen Monat; ok).
- **Maus/Touch:** Nach Tap `_focusKey` auf den getippten Tag setzen (Fokus folgt Klick), damit anschließendes Tab/Pfeil
  dort weitermacht. Ob `preventDefault()` auf `pointerdown` den nativen Fokus verhindert, ist browserabhängig und hier nicht
  verifiziert: im Tap-Zweig von `onCardPointerUp` sicherheitshalber `_focusKey.set(...)` und gezielt fokussieren
  (`focusVisible`-Ring erscheint nach Mausklick nicht, siehe 5). Drag setzt den Roving-Stand auf das Drag-Ende nicht zwingend (offen).
- **Tab-Reihenfolge:** Vorher/Nächster-Button -> Grid (ein Stopp) -> Stats -> Day-Panel. Header-Buttons haben Material-Fokus.
- **Home/End:** APG = erste/letzte Zelle der **Zeile** (Mo/So der Woche, auf den Monat geklemmt), Strg+Home/End = erster/letzter Monatstag. Das Issue sagt nur „Home/End“ (Frage 4).

## 5. Fokusring / SCSS

- Ist: kein Fokus-Style für `.calendar-day`; Browser-Default-Outline würde auf runden Zellen (`border-radius:50%`) erscheinen,
  ist aber nicht definiert. `reports.scss:484` nutzt als Muster `outline: 2px solid var(--mat-sys-primary); outline-offset: 2px`.
- Vorschlag: `.calendar-day:focus-visible { outline: 2px solid var(--mat-sys-primary); outline-offset: 2px; }` und `outline: none`
  nur für `:focus:not(:focus-visible)` (Mausklick zeigt keinen Ring). Mit `outline-offset: 2px` liegt der Ring außerhalb der Zelle
  auf `--mat-sys-surface-container-low`, daher auch bei gefüllter `.selected`-Zelle (Primärfarbe) sichtbar; Gap ist 4px,
  Ringe benachbarter Zellen berühren sich nicht. Weder `outline: none` noch `overflow: hidden` an Vorfahren einführen
  (`.calendar-card` hat keines).
- Kontrast (WCAG 1.4.11, >= 3:1 gegen Hintergrund): Ring Primary gegen `surface-container-low` im Hell- und `.dark-theme`-Modus
  per Handcheck messen (Theme in `styles.scss` ist ein eigenes `mat.define-theme`, konkrete Werte hier nicht geprüft). Kandidat
  bei Unterschreitung: `--mat-sys-on-surface`. Zusätzlich Heute-Zelle (Primär-Rahmen) und Feiertag (Error-Farbe, Unterstrich)
  mit Ring prüfen. `.selected` hat `!important`-Hintergrund, `:hover` setzt Hintergrund: Fokus-Zustand nicht über Hintergrund lösen.
- `forced-colors`/High-Contrast: Outline statt `box-shadow` verwenden (bleibt dort sichtbar).
- `touch-action: none` und `user-select: none` an der Card bleiben (Pointer-Drag), betreffen Tastatur nicht.

## 6. i18n

- PR 1 braucht **keinen** zwingend neuen Key: `aria-current`, `aria-selected`, Wochentag im Label und Struktur sind textfrei;
  die vorhandene Live-Region `.current-month` bleibt.
- Optional (Empfehlung: mitnehmen, wenn „hat Eintrag“ angesagt werden soll): `shared.calendarHasEntryAria`
  (de: `"{{label}}, Eintrag vorhanden"`, en: `"{{label}}, entry available"`) in `public/i18n/de.json` und `en.json`
  (neben `calendarHolidayAria`, Zeile ~303). Testspec muss den Key in `setTranslation` ergänzen (sonst erscheint der Roh-Key im Label).
- Optional: Tastatur-Hinweis per `aria-describedby` (`shared.calendarKeyboardHintAria`). Nicht Teil des MVP.
- PR 2: `shared.calendarSelectedCountAria` (`"{{count}} Tage ausgewählt"`) für die Live-Region.
- Nicht anfassen: bestehende Keys, der feste `de-DE`-Locale der DatePipe (bekannte Eigenheit, eigenes Thema).

## 7. Testplan (Vitest/jsdom via `@angular/build:unit-test`)

Bestehende Datei `calendar.spec.ts` unverändert lassen und einen **neuen** `describe`-Block (oder `calendar-keyboard.spec.ts`)
mit demselben Setup (fixes `vi.setSystemTime(new Date(2026, 9, 15, 12))`, lokale Konstruktoren, `selectedDate` 15.10.2026)
ergänzen. Lauf zusätzlich mit `TZ=Europe/Berlin` und einer Gegenprobe (z. B. `TZ=Pacific/Auckland`, `America/Los_Angeles`, `UTC`).

Pure Util-Spec (`calendar-keyboard.util.spec.ts`, ohne DOM): Pfeile +-1/+-7, Monats-/Jahresgrenze (31.10.->01.11., 01.01.2027 <-),
PageUp/Down mit Klemmen (31.01.2026 -> 28.02.2026; 31.03. -> 28.02.? Richtung beachten), Schaltjahr 2028, Home/End (Zeile + Monat),
DST-Wechselwochenenden (25.10.2026 und 29.03.2026, Berlin) ohne Tagesverschiebung.

Komponenten-Spec:
1. Genau eine Zelle `tabindex="0"`, alle übrigen `-1`; Initial = `selectedDate`; nach `changeMonth` ohne Auswahl im Monat = Tag 1 (bzw. heute).
2. `keydown ArrowRight/Left/Down/Up` am fokussierten Tag: `document.activeElement` ist die erwartete Zelle (Fixture hängt im
   `document`; `dispatchEvent(new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true }))`, danach `detectChanges()`/`await fixture.whenStable()`).
3. Pfeil über Monatsgrenze: `monthChanged`-Emission `{year, month}`, Titel wechselt, Fokus auf der richtigen Zelle im neuen Monat (Dez->Jan Jahreswechsel).
4. PageUp/PageDown, Home/End, Strg+Home/End.
5. Enter und Leertaste emittieren `dateSelected` mit dem fokussierten Tag (`getTime()`-Vergleich); Pfeile emittieren **nicht**;
   `defaultPrevented` bei Space/Pfeilen; Ctrl/Alt/Meta+Pfeil wird nicht abgefangen.
6. ARIA: `role=row` je Woche mit 7 Zellen; kein `aria-pressed`; `aria-selected` im Einzel- und im Mehrfachmodus
   (`multiSelectedDates` gesetzt) konsistent zu `.selected`/`.multi-selected`; `aria-current="date"` genau auf heute und
   nach Mitternachts-Rollover (an den bestehenden #382-Test anlehnen, `vi.advanceTimersByTime`); Wochentag im Label; Feiertags-Label aus #371 bleibt (bestehende Tests).
7. Mausklick/Tap setzt den Roving-Stand (`tabindex=0` auf der getippten Zelle) — über die bestehenden Methodenaufrufe `onCardPointerDown/Up`, nicht über echte Events.
8. Regression: der bestehende Pointer-Block (Tap, Drag [3,4,5]) muss unverändert grün bleiben; `[data-date]`-Selektor, Methodennamen und `dateSelected/dragSelected`-Verträge nicht ändern.
9. Fake-Timer-Hinweis: `onCardPointerUp` nutzt `setTimeout`; `afterNextRender` läuft in `detectChanges`, nicht in Timern.

**Vite-SSR-Falle (web/CLAUDE.md):** keine nackte importierte Konstante als Klassenfeld-Initializer
(`x = IMPORTIERTE_KONSTANTE;`). Betrifft v. a. eine Tastenkarte (`KEY_DELTAS`) oder Util-Werte, die in `calendar-keyboard.util.ts`
liegen: nur innerhalb von Methoden verwenden, sonst im Constructor zuweisen bzw. als `signal(X)`/`[...X]` einbetten.
Lokale, in derselben Datei definierte Konstanten (wie `EMPTY_HOLIDAYS`) sind unkritisch. Zum Gegencheck `npm test -- --watch=false` im **Vollauf** (nicht nur Einzelspec).

**AXE:** Im Repo ist `axe-core`/`jest-axe`/`@axe-core/*` nicht vorhanden (`node_modules` geprüft), CI führt keinen AXE-Lauf aus.
Empfehlung: PR 1 mit manuellem Check (axe DevTools bzw. Lighthouse auf `/reports`, Tab „Täglich“, hell + dunkel, Ergebnisse im PR
notieren) plus Screenreader-Stichprobe. Keine neue Abhängigkeit ohne Rückfrage; Option wäre `axe-core` als devDependency mit
jsdom-Test (Regel `color-contrast` in jsdom nicht verwertbar, deaktivieren) — dann Frage 6.

## 8. Aufteilung / PR-Größe

- **PR 1 (MVP)** — Calendar-Komponente + Util + Specs + (optional) 1 i18n-Key:
  Wochenzeilen/ARIA-Reparatur, Roving tabindex, Pfeile/Home/End/PageUp/PageDown, Enter/Space, Fokusring, Tests. Keine Änderung am Reports-Service
  nötig (`dateSelected` wird vom Parent wie bisher interpretiert; evtl. nur den Host-`aria-label` in `reports.html` anfassen). Geschätzt ~150-250 Zeilen Code + ~250 Zeilen Tests.
- **PR 2** — Shift+Pfeil-Mehrfachauswahl nach Produktentscheidung, ggf. mit Service-Änderung (Ersetzen/Verkleinern, Anker, Modus-Einstieg,
  Escape), Live-Region, `aria-multiselectable`.
- Optional davor ein kleiner Schritt 0 nur für die Struktur (`row`, `aria-pressed`, `aria-selected`, `aria-current`) — nur falls ein
  separat reviewbarer Template-Umbau gewünscht ist; sonst in PR 1. Ein Mini-Docs-Update in `web/CLAUDE.md` (Zeile 59, Kalender-Beschreibung) gehört in PR 1.

## Risiken
- Template-Umbau auf `role=row` ändert die DOM-Struktur; bestehende Selektoren (`[data-date]`, `.calendar-day`, `.calendar-card`)
  und das Pointer-Hit-Testing per `elementFromPoint` müssen unverändert funktionieren (Zeilen-Wrapper dürfen kein `pointer-events`/Layout-Loch erzeugen).
- Fokusverlust bei Monatswechsel (Zellen werden neu erzeugt) -> `afterNextRender` nötig; Gefahr von Fokusdiebstahl bei Input-getriebenen Re-Renders (nur nach Tastatur fokussieren).
- Kontrast des Fokusrings in zwei Themes ist ungemessen; `!important` am `.selected`-Hintergrund und `:hover` nicht mit dem Fokus mischen.
- Doppelansagen (Live-Region + Fokus, Tooltip + Label) sind screenreaderabhängig; nur per Handtest klärbar.
- Shift+Pfeil: additive Service-Semantik und Arbeitstage-Filter passen nicht zur Tastatur (siehe 2).
- `preventDefault` auf `pointerdown` kann Fokus nach Klick beeinflussen (nicht verifiziert) -> explizit fokussieren.
- Spec-Falle: `setTranslation` im Test muss neue Keys enthalten, sonst Roh-Key im `aria-label`.

## Offene Fragen (mit Empfehlung)
1. **Umfang:** PR 1 ohne Shift+Pfeil, PR 2 später? *Empfehlung: ja* (Gründe in 2).
2. **Mehrfachauswahl per Tastatur:** Shift+Pfeil wie im Issue, oder zusätzlich/stattdessen ein sichtbarer „Mehrfachauswahl“-Button
   als barrierefreier Einstieg (heute gibt es keinen Einstieg ohne Drag)? Soll Shift+Gegenrichtung verkleinern (Service-Änderung) und
   dürfen Nicht-Arbeitstage übersprungen/gefiltert werden? *Empfehlung: erst Button-Einstieg klären, Shift+Pfeil mit Verkleinern in PR 2.*
3. **Fokus folgt Auswahl?** *Empfehlung: nein* (APG, Last-Request-Kosten im Reports-Service); nur Enter/Space wählt.
4. **Home/End-Semantik:** Zeile (Mo/So) wie APG, Strg+Home/End = Monatsanfang/-ende, oder einfach Monatsanfang/-ende? *Empfehlung: APG.*
5. **„Hat Eintrag“ im aria-label** (+ 1 neuer Key `shared.calendarHasEntryAria`) und Wochentag im Label? *Empfehlung: ja, beides in PR 1.*
6. **AXE:** manueller Check im PR (Empfehlung) oder `axe-core` als neue devDependency mit jsdom-Test? *Empfehlung: manuell, Dependency separat entscheiden.*
7. **Host-`aria-label`** auf `<app-calendar>` in `reports.html` entfernen/ersetzen (Grid trägt schon den Monat)? *Empfehlung: entfernen oder `role="group"`, nach axe-Lauf entscheiden.*
8. **Fokusring-Farbe:** Primary wie `reports.scss` (Empfehlung) oder `on-surface`, falls Kontrastmessung < 3:1? Messung gehört in die Implementierung.
9. **Handtest-Umgebung:** Gibt es einen bevorzugten Screenreader (NVDA/VoiceOver) für die Stichprobe, oder reicht axe + Tastaturtest?

## Entscheidungen zu den offenen Fragen (Hauptsession)

1. Zwei PRs: PR 1 (MVP ohne Shift+Pfeil), PR 2 später. PR 1 mit `Refs #377`, Issue bleibt bis PR 2 bzw. bis zur Umfangsentscheidung offen.
2. Mehrfachauswahl per Tastatur: gehört zu PR 2; der Einstieg (Shift+Pfeil vs. sichtbarer Button) wird erst nach PR 1 entschieden (Rückfrage an den User). In PR 1 keine Tastatur-Mehrfachauswahl.
3. Fokus folgt nicht der Auswahl; nur Enter/Space wählt.
4. Home/End: APG – Zeilenanfang/-ende (Mo/So), Strg+Home/End Monatsanfang/-ende.
5. Wochentag und „Eintrag vorhanden" im aria-label (neuer Key `shared.calendarHasEntryAria`, de/en minimal) in PR 1.
6. AXE: manueller Check im PR (axe DevTools bzw. Lighthouse auf /reports, hell/dunkel); keine neue Abhängigkeit.
7. Host-`aria-label` auf `<app-calendar>` in reports.html: tendenziell entfernen; im PR begründen, falls die Messung nichts findet, trotzdem entfernen wenn `aria-label` auf generischem Host-Element unzulässig ist.
8. Fokusring: primary; falls Kontrast < 3:1 (hell/dunkel), `on-surface`/höherer Kontrast.
9. Reicht Tastaturtest + axe; kein bestimmter Screenreader nötig (manuelle Checkliste im PR).
10. Reine Tastenlogik in ein Util (Vite-SSR-Test-Falle vermeiden).
