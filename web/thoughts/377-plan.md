# Web-Plan: #377 — Kalender per Tastatur bedienbar (PR 1: ARIA-Reparatur + Tastatur ohne Mehrfachauswahl)
Erstellt: 2026-10-04
Research: web/thoughts/377-research.md (inkl. "Entscheidungen zu den offenen Fragen (Hauptsession)", gilt vor allem anderen)
UI-Report: entfällt (kein Flutter-Port, kein neues Design; Fokusring-Vorgabe steht in Research, Abschnitt 5)

## Ziel
Tageszellen des Kalenders (Reports, Tab "Täglich") sind per Tastatur und Screenreader bedienbar: korrekte Grid-ARIA-Struktur,
Roving tabindex, Pfeile/Home/End/PageUp/PageDown, Enter/Space wählt, sichtbarer Fokusring. PR 1 mit `Refs #377` (nicht `Closes`),
keine Tastatur-Mehrfachauswahl (PR 2, nicht Teil dieses Plans). Bestehendes Pointer-/Drag-Verhalten bleibt unverändert.

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Hybrid-Service nötig? | nein | reine UI-Komponente |
| Neuer Domain-Service? | nein | Tastenlogik ist UI-nah: Util in `shared/utils/` (Entscheidung 10) |
| Premium-Gate? | nein | — |
| Routing-Änderung? | nein | — |
| Neuer API-Endpunkt / Firestore-Pfad? | nein | kein Backend, keine Rules |
| Neue Texte? | ja, 1 Key | `shared.calendarHasEntryAria` (de/en) neben `calendarHolidayAria` (Zeile ~303); Entscheidung 5 |
| Shared Component? | bestehend | `CalendarComponent` bleibt einziger Verwender-Pfad (nur `reports.html`) |
| Fokus folgt Auswahl? | nein | Entscheidung 3: Pfeile bewegen nur Fokus, nur Enter/Space emittiert `dateSelected` |
| Home/End | APG | Entscheidung 4: Zeilenanfang/-ende (Mo/So, auf Monat geklemmt), Strg+Home/End Monatsanfang/-ende |
| Shift+Pfeil | in PR 1 unbehandelt | Shift-Kombinationen fallen durch (kein `preventDefault`), damit PR 2 ohne Verhaltensänderung andocken kann |
| AXE | manuell | Entscheidung 6: keine neue Abhängigkeit, Checkliste im PR-Body |
| Host-`aria-label` in reports.html | entfernen | Entscheidung 7: Label auf generischem Host unzulässig, Grid trägt den Monat |
| Fokusring | primary, Fallback höherer Kontrast | Entscheidung 8; Messung in Schritt 8 |

Abweichungen vom Naheliegenden:
- Template-Umbau auf Wochenzeilen (`weeks`-Computed statt flacher Kinder); jede Zeile ist ein eigenes 7-Spalten-Grid (kein `display: contents`).
- `aria-selected` = visuelle Auswahl (Mehrfachauswahl vor `selectedDate`), `aria-pressed` entfällt.
- Fokus nur nach Tastatur/Tap, nie per Input-Änderung (kein `effect`, der Fokus stiehlt).

## Neue / geänderte Dateien

### Shared Utils (pure)
```
web/src/app/shared/utils/
├── calendar-keyboard.util.ts        # NEU: pure Tastenlogik (kein Angular, kein inject)
└── calendar-keyboard.util.spec.ts   # NEU
```

### Shared Component
```
web/src/app/shared/components/calendar/
├── calendar.ts                      # GEÄNDERT: Template (Zeilen, ARIA, tabindex, keydown), Roving-State, Fokus, Styles
└── calendar.spec.ts                 # unverändert lassen; neue Tests in calendar-keyboard.spec.ts
    calendar-keyboard.spec.ts        # NEU: Komponenten-Spec Tastatur + ARIA (gleiches Setup wie calendar.spec.ts)
```

### Feature / i18n / Docs
```
web/src/app/features/reports/reports.html   # Host-aria-label entfernen
web/public/i18n/de.json, en.json            # shared.calendarHasEntryAria
web/CLAUDE.md                               # Zeile 59 Kalender-Beschreibung ergänzen
```

## Test-Konventionen (für alle Schritte)
- Vitest/jsdom, keine Datums-/Wochentags-/TZ-Abhängigkeit: feste lokale Konstruktoren (`new Date(2026, 9, 15)`),
  `vi.useFakeTimers` + `vi.setSystemTime(new Date(2026, 9, 15, 12))` wie `calendar.spec.ts`. Kein `new Date()` ohne Argument in Erwartungen.
- Datumsvergleiche über `getFullYear/Month/Date` bzw. `dayKey`, nicht über `toISOString()`.
- Tasten über `dispatchEvent(new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true, ctrlKey?, shiftKey? }))`.
- Fixture im `document` (Fokus-Assertions über `document.activeElement`); nach Event `fixture.detectChanges()` und `await fixture.whenStable()`.
- `setTranslation` im Spec muss `shared.calendarHasEntryAria`, `calendarHolidayAria`, `calendarPrevMonthAria`, `calendarNextMonthAria`, `common.weekdaysShort` und `holidays.*` enthalten, sonst Roh-Key im Label.
- **Rot-Nachweis je Schritt:** Test zuerst schreiben, `npx` bzw. `npm test -- --watch=false` (Einzelspec über Filter) laufen lassen,
  Ausgabe mit dem erwarteten Fehlschlag notieren (richtiger Grund, nicht Import-/Syntaxfehler: für neue Util-Dateien zuerst leeres Stub-Modul mit
  Signatur, das `null`/Platzhalter liefert, damit der Rot-Grund inhaltlich ist), danach implementieren, Grün-Nachweis. Rot/Grün-Belege in die PR-Beschreibung (Stichpunkte).
- **Vite-SSR-Falle:** keine nackte Import-Referenz als Klassenfeld-Initializer (kein `readonly keys = KEY_MAP;`). Util-Werte nur in Methoden verwenden;
  Tastenkarte lebt im Util als Modul-Konstante und wird dort selbst benutzt, die Komponente ruft nur Funktionen auf. Gegencheck: Vollauf, nicht nur Einzelspec.
- Abschlusslauf mit `TZ=Europe/Berlin`, `TZ=UTC`, `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland` (siehe Schritt 9).

## Implementierungsschritte (TDD-First)

### Schritt 1: Util `calendar-keyboard.util.ts` (pure)
Schnittstelle (Namen verbindlich im Plan, Feinheiten im Code):
- `type CalendarNavKey = 'ArrowLeft' | 'ArrowRight' | 'ArrowUp' | 'ArrowDown' | 'Home' | 'End' | 'PageUp' | 'PageDown'`
- `isCalendarNavKey(key: string): key is CalendarNavKey`
- `nextFocusDate(key: CalendarNavKey, from: Date, ctrl: boolean): Date` — liefert immer ein neues Date (lokale Mitternacht), mutiert `from` nie.

Semantik:
- Pfeile: `new Date(y, m, d + n)` mit n = -1/+1/-7/+7 (nie Millisekunden-Arithmetik), geht frei über Monats-/Jahresgrenzen.
- Home/End ohne Ctrl: Montag/Sonntag der Woche von `from`, auf Monat von `from` geklemmt (erster/letzter Monatstag).
- Strg+Home/End: erster/letzter Tag des Monats von `from`.
- PageUp/PageDown: Monat -1/+1, Tag auf den Monatsletzten des Zielmonats geklemmt (31.01. -> 28.02.2026; 31.03.2028 -> 29.02.2028 bei PageUp aus 31.03.).
- Ctrl bei Pfeilen/Page-Tasten ändert nichts an der Semantik (das Filtern von Modifikatoren erfolgt in der Komponente, nicht im Util).

Tests zuerst (`calendar-keyboard.util.spec.ts`, ohne DOM):
- [x] Pfeile +-1/+-7 mitten im Monat
- [x] Monatsgrenze: 31.10.2026 +1 -> 01.11.2026; 01.11.2026 -1 -> 31.10.2026; 28.10. +7 -> 04.11.
- [x] Jahresgrenze: 31.12.2026 +1 -> 01.01.2027; 01.01.2027 -1 -> 31.12.2026; 01.01.2027 -7 -> 25.12.2026
- [x] Schaltjahr 2028: 28.02.2028 +1 -> 29.02.2028; 29.02.2028 +1 -> 01.03.2028; PageDown 31.01.2028 -> 29.02.2028
- [x] PageUp/PageDown Klemmen: 31.01.2026 PageDown -> 28.02.2026; 31.03.2026 PageUp -> 28.02.2026; Jahreswechsel 15.12.2026 PageDown -> 15.01.2027, 15.01.2027 PageUp -> 15.12.2026
- [x] Home/End Zeile: Mi 14.10.2026 Home -> Mo 12.10., End -> So 18.10.; Mo bleibt bei Home, So bleibt bei End
- [x] Home/End Zeilen-Klemmung: 02.10.2026 (Fr, Woche beginnt im September) Home -> 01.10.2026; 29.10.2026 End -> 31.10.2026 (Sa/So-Klemmung auf Monatsende, Monat endet am Sa)
- [x] Strg+Home/End: beliebiger Tag -> 01. bzw. letzter Monatstag (Februar 2026 = 28, Februar 2028 = 29)
- [x] DST: 25.10.2026 (Berlin Zeitumstellung) +-1 und +-7 und 29.03.2026 ohne Tagesverschiebung (Ergebnis `getDate()` exakt, `getHours() === 0`)
- [x] Reinheit: Eingabe-Date wird nicht mutiert; Rückgabe ist neue Instanz
- [x] `isCalendarNavKey`: true für die 8 Tasten, false für 'Enter', ' ', 'a', 'Tab'
- Rot-Nachweis: Stub liefert `from`, Tests schlagen inhaltlich fehl. Dann Impl, Grün.

### Schritt 2: ARIA-Struktur und Wochenzeilen im Template (Test zuerst)
Tests zuerst (`calendar-keyboard.spec.ts`, Block "ARIA-Struktur"), Rot gegen den Ist-Zustand:
- [x] Grid hat `role=grid`; direkte Kinder sind ausschließlich `role=row`; Kopfzeile = 1 Row mit 7 `columnheader`
- [x] Oktober 2026 (Do 01.10. -> 3 leere Prefix-Zellen, 31 Tage): 5 Datenzeilen, jede Zeile 7 Zellen; Zellen nur `gridcell`/`columnheader`
- [x] Kein Element mit `aria-pressed`
- [x] `aria-selected` Einzelmodus: `"true"` genau auf `selectedDate`, `"false"` explizit auf allen anderen Tagen
- [x] `aria-selected` Mehrfachmodus (`multiSelectedDates` = {2026-10-05, 2026-10-06}): `"true"` nur auf diesen zwei, selectedDate `"false"` — konsistent zu `.multi-selected` / `.selected`
- [x] `aria-current="date"` genau auf heute (15.10.), sonst Attribut fehlt; nach Mitternachts-Rollover (an den #382-Test in calendar.spec.ts anlehnen, `vi.advanceTimersByTime`) wandert es auf den Folgetag
- [x] `aria-label` enthält Wochentag + Datum (z. B. `Donnerstag, 15. Oktober 2026`, Locale fest de-DE); Feiertag: `{{label}}, Feiertag: {{name}}` bleibt (bestehende #371-Tests in calendar.spec.ts laufen unverändert grün)
- [x] Tag mit Eintrag (`daysWithEntries=[15]`) hat im Label "Eintrag vorhanden" (de) / "entry available" (en, über `TranslateService.use('en')` wie vorhandene en-Tests); Tag ohne Eintrag nicht; Feiertag + Eintrag: beide Hinweise, Reihenfolge Datum -> Feiertag -> Eintrag
- [x] Leere Prefix-Zellen: `aria-hidden="true"`, ohne `tabindex`, ohne `data-date`
- [x] Regression: alle Tests in `calendar.spec.ts` (Pointer, Drag [3,4,5], Klassen `.holiday/.selected/.today`, `cell(key)`) grün

Impl:
- [x] `weeks`-Computed: aus `viewDate` Array von Wochen (je 7 Einträge, `null` = leer vor Monatsbeginn bzw. nach Monatsende); ersetzt `emptyPrefix` für das Template (`emptyPrefix`/`daysInMonth` bleiben öffentlich, falls Tests sie nutzen; vor Entfernen Grep)
- [x] Template: `@for (week of weeks(); track $index)` -> `div.calendar-week[role=row]`, innen `@for` über Zellen; Kopfzeile `div.calendar-week.weekday-row[role=row]`; `track` für Tageszellen weiter `day.date.getTime()` (DOM-Stabilität innerhalb eines Monats)
- [x] `aria-pressed` entfernen; `aria-selected` an neue Methode `isSelected(date)`: `hasMultiSelected() ? isMultiSelected(d) : isSameDay(d, selectedDate())`, `.selected`-Klasse nutzt weiter dieselbe Logik
- [x] `aria-current` per `[attr.aria-current]="isToday(d) ? 'date' : null"`
- [x] Label-Komposition im Template per `@let` (Datum `EEEE, d. MMMM yyyy` -> optional Feiertag -> optional Eintrag über `shared.calendarHasEntryAria` mit `{ label }`); Template einfach halten, ggf. Hilfsmethode `cellLabel(...)` falls `@let`-Verschachtelung zu unlesbar
- [x] Styles: `.calendar-grid` wird Spaltenlayout (`display: flex; flex-direction: column; gap: 4px`), `.calendar-week` bekommt `display: grid; grid-template-columns: repeat(7, 1fr); gap: 4px`; Hit-Testing darf nicht leiden (Zeilen-Wrapper ohne `pointer-events`-Änderung, kein Layout-Loch; `[data-date]` bleibt auf der Zelle)
- i18n: `shared.calendarHasEntryAria` in `de.json` (`"{{label}}, Eintrag vorhanden"`) und `en.json` (`"{{label}}, entry available"`) direkt neben `calendarHolidayAria`

### Schritt 3: Roving tabindex (Test zuerst)
Tests zuerst, Rot (heute kein tabindex):
- [x] Initial genau eine Zelle `tabindex="0"` = `selectedDate` (15.10.), alle anderen Tageszellen `tabindex="-1"`, leere Zellen ohne tabindex
- [x] Nach `changeMonth(1)` ohne Auswahl im Zielmonat: `tabindex=0` auf "heute", wenn heute im Monat; sonst auf Tag 1 (Fixture mit heute in einem anderen Monat als selectedDate, z. B. selectedDate 15.10., heute 15.10., Blättern auf November -> 01.11.; Blättern zurück -> 15.10. = selectedDate)
- [x] selectedDate im angezeigten Monat hat Vorrang vor heute; heute vor Tag 1
- [x] Immer genau eine `tabindex=0`-Zelle (Property-Test über mehrere Monate/Blättern)
- [x] Tab-Reihenfolge: Grid hat insgesamt einen Tab-Stopp (Anzahl Elemente mit `tabindex=0` im Grid = 1)

Impl:
- [x] `private readonly _focusKey = signal<string | null>(null)`
- [x] `focusableKey = computed(...)`: `_focusKey` wenn im angezeigten Monat, sonst selectedDate-Key wenn im Monat, sonst `todayService.today()` wenn im Monat, sonst Key von Tag 1
- [x] Zelle: `[attr.tabindex]="dayKey(d) === focusableKey() ? 0 : -1"`
- [x] `selectedDate`-Effekt setzt zusätzlich `_focusKey` auf `null` (Auswahl von außen setzt den Roving-Stand zurück); `untracked` beibehalten

### Schritt 4: Tastatursteuerung ohne Monatswechsel (Test zuerst)
Tests zuerst, Rot:
- [x] ArrowRight/Left/Down/Up am Fokus-Tag (15.10.): `document.activeElement` ist 16./14./22./08.10.; `tabindex=0` wandert mit (nach `detectChanges`)
- [x] Pfeil emittiert weder `dateSelected` noch `dragSelected` noch `monthChanged` (Fokus folgt nicht der Auswahl)
- [x] Home -> Montag der Zeile (Mi 14.10. -> 12.10.), End -> So 18.10.; Strg+Home -> 01.10., Strg+End -> 31.10.
- [x] Enter und Leertaste (`key: ' '`) auf fokussierter Zelle emittieren `dateSelected` genau einmal mit diesem Tag (`getTime()`-Vergleich gegen `new Date(2026, 9, 22)`); Enter/Space ändern den Fokus nicht
- [x] `defaultPrevented === true` für Pfeile, Home/End, PageUp/PageDown, Space; Enter ruft `preventDefault` ebenfalls (verhindert Doppel-Auslösung/Click-Synthese), dokumentiert im Test
- [x] Nicht abgefangen (`defaultPrevented === false`, keine Emission, Fokus unverändert): Ctrl+ArrowRight, Alt+ArrowRight, Meta+ArrowRight, Shift+ArrowRight, Tab, andere Tasten (`a`), Keydown mit Target außerhalb einer Zelle (z. B. Event am Grid selbst)
- [x] Keydown auf Header-Buttons (Vorheriger/Nächster Monat) wird vom Grid-Handler nicht berührt (Handler hängt am Grid, nicht an der Card)

Impl:
- [x] `host`-frei: `(keydown)="onGridKeydown($event)"` am `.calendar-grid` (Event-Delegation, ein Handler); Zelle über `event.target.closest('[data-date]')`, `data-date` -> lokales Date (wie `_dateFromPoint`; gemeinsame private Hilfsmethode `_parseKey` statt Duplikat)
- [x] Modifier-Filter: bei `ctrlKey` nur Home/End zulässig; `altKey`/`metaKey`/`shiftKey` -> unbehandelt zurückkehren
- [x] Navigation: `isCalendarNavKey` + `nextFocusDate` (Aufruf nur in der Methode); Enter/Space -> `dateSelected.emit(date)`
- [x] `_focusCell(date)`: gleicher Monat wie `viewDate` -> `_focusKey.set(key)` und direkt `querySelector('[data-date="…"]')?.focus()` (`focus()` auf `tabindex=-1` ist zulässig; Attribut zieht im nächsten CD nach)
- [x] `preventDefault()` nur bei behandelten Tasten

### Schritt 5: Monatswechsel per Tastatur + Fokus per `afterNextRender` (Test zuerst)
Tests zuerst, Rot:
- [x] ArrowRight auf 31.10.2026: `monthChanged` emittiert `{ year: 2026, month: 11 }`, `.current-month`/Grid-Label zeigt November 2026, `document.activeElement` = Zelle 01.11.2026
- [x] ArrowLeft auf 01.10. -> 30.09. (September), ArrowDown auf 28.10. -> 04.11., ArrowUp auf 05.11. -> 29.10.
- [x] Jahreswechsel: Fixture `selectedDate` 31.12.2026, ArrowRight -> `{ year: 2027, month: 1 }`, Fokus 01.01.2027; ArrowLeft zurück -> `{ year: 2026, month: 12 }`, Fokus 31.12.2026
- [x] PageDown auf 31.01.2026 (Fixture mit selectedDate in Jan 2026) -> Februar, Fokus 28.02.2026, `monthChanged {2026, 2}`; PageUp -> Fokus 15.09.2026 aus 15.10.
- [x] Zuordnung Roving: nach Monatswechsel genau eine `tabindex=0`-Zelle = fokussierte
- [x] Kein Fokusdiebstahl: Input-Änderungen (`daysWithEntries` neu gesetzt, `selectedDate` per `setInput` geändert, Mitternachts-Rollover per `vi.advanceTimersByTime`, Button-`changeMonth`) ändern `document.activeElement` nicht (Anfangsfokus z. B. auf `document.body` oder einem externen Button; bleibt dort)
- [x] Button-Monatswechsel (`changeMonth(±1)` / Klick auf Header-Button) setzt Fokus nicht in das Grid (Fokus bleibt am Button)
- [x] `monthChanged` wird bei Tastatur-Monatswechsel genau einmal emittiert

Impl:
- [x] `changeMonth(delta)` intern auf `_showMonth(year, month)` umstellen (öffentliche Signatur/Emission unverändert); Tastatur-Pfad ruft `_showMonth`, setzt `_focusKey` auf Zielkey und registriert `afterNextRender(() => focus(querySelector(...)), { injector })` (`Injector` per `inject()` als Feld; kein nackter Import als Feldwert)
- [x] Fokus-Flag nur im Tastatur-/Tap-Pfad; es gibt keinen `effect`, der Fokus setzt
- [x] Live-Region `.current-month[aria-live=polite]` unverändert belassen (Doppelansage nur per Handtest klären, siehe Checkliste)

### Schritt 6: Tap/Klick setzt Roving-Stand (Test zuerst)
Tests zuerst (über die bestehenden Methoden `onCardPointerDown/Up` mit gemocktem `document.elementFromPoint`/`setPointerCapture`, nicht über echte Pointer-Events):
- [x] Tap auf 20.10. (Down + Up ohne Move): `dateSelected` wie bisher, danach `tabindex=0` auf 20.10. und Zelle hat Fokus
- [x] Drag [3,4,5] (bestehender Test) bleibt grün, emittiert `dragSelected` unverändert; `_focusKey` nach Drag: bleibt unverändert (offene Detailfrage der Research bewusst nicht ausgeweitet)
- [x] Mit Fake-Timern: `onCardPointerUp` nutzt `setTimeout`, Assertions nicht von Timern abhängig machen

Impl:
- [x] Im Tap-Zweig von `onCardPointerUp` vor/neben `dateSelected.emit`: `_focusKey.set(key)` und die Zelle fokussieren (Browser-unabhängig, da `preventDefault` auf `pointerdown` den nativen Fokus ggf. verhindert). Pointer-Methodennamen, Signaturen und Emissionen unverändert

### Schritt 7: Host-aria-label in reports.html
- [x] Test zuerst (Reports-Spec falls vorhanden, sonst Teil von `calendar-keyboard.spec.ts` mit Verwender nicht nötig): kein `aria-label` auf `app-calendar`-Host. Falls das Reports-Spec das Rendering des Hosts nicht abdeckt, Schritt als rein manuell prüfen und in der Checkliste führen (kein künstlicher Test)
- [x] `[attr.aria-label]="'reports.calendarAria'"` in `features/reports/reports.html` (Zeile ~17-26) entfernen; Begründung in PR: Label auf Element ohne Rolle (generic) ist laut ARIA unzulässig (`aria-prohibited-attr`), das Grid trägt den Monatsnamen
- [x] Prüfen per Grep, ob `reports.calendarAria` sonst genutzt wird; wenn nein, Key in de/en entfernen (nur, wenn ein vorhandener i18n-Paritätstest nicht anderes verlangt), sonst belassen und im PR benennen

### Schritt 8: Fokusring (SCSS im Inline-`styles` von `calendar.ts`)
- [x] Kein sinnvoller Unit-Test für Computed-Styles in jsdom; stattdessen Test, dass die Zelle fokussierbar ist (aus Schritt 3/4) und manuelle Prüfung (Checkliste)
- [x] `.calendar-day:focus-visible { outline: 2px solid var(--mat-sys-primary); outline-offset: 2px; }`, `.calendar-day:focus:not(:focus-visible) { outline: none; }` (Mausklick ohne Ring); `outline` statt `box-shadow` (forced-colors), kein `overflow: hidden` an Vorfahren
- [x] Fokus-Zustand nicht über Hintergrund lösen (`.selected` hat `!important`, `:hover` setzt Hintergrund)
- [x] Kontrast messen (>= 3:1 gegen `--mat-sys-surface-container-low`) in Hell und `.dark-theme` und auf Zuständen selected/today/holiday/multi-selected; bei Unterschreitung `--mat-sys-on-surface` (Entscheidung 8), Messwerte in den PR-Body

### Schritt 9: Integration, Docs, Vollläufe
- [x] `web/CLAUDE.md` Zeile 59 ergänzen: "Tastaturbedienung (#377): Roving tabindex, Pfeile/Home/End/PageUp/PageDown, Enter/Space; ARIA grid > row > gridcell; Util `calendar-keyboard.util.ts`" (Utils-Liste unter `shared/utils/` um den neuen Eintrag ergänzen)
- [x] `cd web && npm test -- --watch=false` (Vollauf, Vite-SSR-Falle) unter `TZ=Europe/Berlin`, `TZ=UTC`, `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland`
- [x] `npm run build -- --configuration production`
- [x] Vorhandene i18n-Tests/Paritätsprüfung (falls vorhanden) grün; de/en haben denselben Key
- [x] Commit-Trailer und PR-Footer laut Vorgabe der Hauptsession; PR-Titel/Body mit `Refs #377`

## Signal-Design (Skizze, kein Code)
- State: `viewDate` (besteht), `_focusKey: signal<string | null>`.
- Computed: `weeks` (Zeilen/Zellen), `focusableKey` (Roving-Fallback: `_focusKey` -> selectedDate -> heute -> Tag 1), `daysInMonth`/`emptyPrefix` bleiben solange Tests/Template sie brauchen.
- Methoden (kein Signal): `isSelected`, `onGridKeydown`, `_focusCell`, `_showMonth`.
- OnPush bleibt, `@if`/`@for`/`@let`, `inject()`, `input()`/`output()`, kein `@HostListener`, kein `standalone: true`.
- Fokus-Pfad strikt imperativ nach Tastatur/Tap (direkter `focus()` bzw. `afterNextRender` bei Monatswechsel), nie aus einem `effect`.

## Manuelle Prüfliste (für den PR-Body, eigener Abschnitt)
Umgebung: `npm start`, Reports, Tab "Täglich", je Hell und Dunkel; Chrome (axe DevTools, Lighthouse), optional Firefox. Kein bestimmter Screenreader nötig (Entscheidung 9).
- [ ] Tab-Reihenfolge: Vorheriger Monat -> Nächster Monat -> Kalender (genau ein Stopp) -> weiter zu Stats/Day-Panel; Shift+Tab zurück
- [ ] Pfeile bewegen sichtbar den Fokus (+-1/+-7), Seite scrollt dabei nicht; Auswahl und Tag-Panel ändern sich dabei nicht
- [ ] Home/End = Mo/So der Zeile, Strg+Home/End = Monatsanfang/-ende, PageUp/PageDown wechseln Monat (Klemmen: 31.01. -> 28.02.)
- [ ] Pfeil über Monats- und Jahresgrenze: Monat wechselt, Einträge laden nach, Fokus liegt auf richtiger Zelle
- [ ] Enter und Leertaste wählen den Tag (Day-Panel wechselt); Leertaste scrollt nicht
- [ ] Fokus bleibt nach Nachladen, Monatswechsel per Button und Mitternacht nicht im Grid "gestohlen"
- [ ] Mausklick/Tap: Auswahl wie bisher, Tab/Pfeil setzt am geklickten Tag fort; Drag-Mehrfachauswahl unverändert (Touch und Maus)
- [ ] Fokusring sichtbar bei Tastatur, nicht nach Mausklick; sichtbar auf selected/today/holiday/multi-selected, Hell und Dunkel; Kontrast >= 3:1 gemessen (Werte notieren), Windows-Hochkontrast/forced-colors Stichprobe
- [ ] axe DevTools auf /reports (Tab Täglich), Hell und Dunkel: 0 Verstöße im Kalender, Ergebnis im PR notieren; speziell `aria-required-children`, `aria-required-parent`, `aria-allowed-attr`, `aria-prohibited-attr`, leere `aria-hidden`-Zellen in Zeilen
- [ ] Lighthouse Accessibility auf /reports: Score und Kalenderbefunde notieren
- [ ] Zellenlabel (Accessibility-Tree/DevTools): "Donnerstag, 15. Oktober 2026[, Feiertag: …][, Eintrag vorhanden]", `aria-current="date"` auf heute, `aria-selected` konsistent, kein `aria-pressed`
- [ ] Host `<app-calendar>` ohne `aria-label`, Grid-Label = Monat/Jahr
- [ ] Soweit ohne Screenreader beurteilbar: Doppelansage Live-Region + Fokus bei Tastatur-Monatswechsel und Tooltip + Label bei Feiertagen im Accessibility-Tree prüfen; Auffälligkeiten als Folge-Issue notieren, nicht in diesem PR lösen
- [ ] Vorab-Hinweis im PR: Locale der DatePipe ist app-weit fest `de-DE` (EN-UI zeigt deutsche Wochentage im Label), bestehend, nicht Teil des Issues

## Offene Fragen an die Hauptsession
1. Shift+Pfeil bleibt in PR 1 bewusst unbehandelt (kein `preventDefault`, kein Fokuswechsel). Alternative wäre, Shift+Pfeil wie Pfeil ohne Shift zu behandeln; Empfehlung: unbehandelt, bis PR 2 entschieden ist. Einverstanden?
2. `reports.calendarAria`: Key nach Entfernen des Host-Labels löschen (falls ungenutzt) oder stehen lassen? Empfehlung: löschen, wenn weder Verwendung noch Paritätstest dagegen sprechen.
3. Leere Prefix-/Suffix-Zellen: Plan behält `aria-hidden="true"` in der Zeile und vertraut dem manuellen axe-Lauf; sollte axe sie als Verstoß melden, Wechsel auf `role="presentation"` bzw. Weglassen (Layout über `grid-column`). Freigabe für diese Rückfall-Entscheidung im Rahmen von PR 1?
4. Enter ruft `preventDefault()` (kein Click-Doppelauslösen); falls Auto-Repeat von Enter stören soll, `event.repeat` ignorieren? Empfehlung: ja, Enter/Space mit `event.repeat` ignorieren (einmaliges Auslösen).

## Entscheidungen zu den offenen Fragen (Hauptsession)

1. Shift+Pfeil bleibt in PR 1 unbehandelt (kein preventDefault, keine Auswahländerung); PR 2 entscheidet.
2. `reports.calendarAria` löschen, wenn der Key nach Entfernen des Host-Labels nirgends mehr verwendet wird (grep in src und public/i18n); sonst belassen. Beide Sprachdateien minimal ändern.
3. `role=presentation` für leere Zellen nur, wenn die ARIA-Spezifikation es klar verlangt oder ein messbarer axe-Befund vorliegt (axe läuft nicht im CI); sonst nicht umstellen und im PR als manuelle Prüfung nennen.
4. Enter/Space mit `event.repeat` ignorieren (Auswahl nicht per Tastenwiederholung toggeln); Test dafür.
