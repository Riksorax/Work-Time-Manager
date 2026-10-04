# Web-Research: #390 — `_recalculateOvertime` rechnet bei gestopptem Eintrag mit „jetzt“ statt `workEnd`
Datum: 2026-10-04
Feature-Ordner: web/src/app/features/dashboard/ (reiner Bugfix, kein neues Feature, kein Flutter-Port)

## Flutter-Quelle / Referenz
Kein Port. Kanonische Referenz ist das Backend (`server/src/WorkTimeManager.Api/Domain/ReportCalculator.cs`, `BreakCalculator.cs`).
Flutter nur zum Vergleich: `mobile/lib/presentation/view_models/dashboard_view_model.dart` (`_recalculateOvertime`, `_calculateElapsedTime`).

## Feature-Verständnis
`DashboardService` hält `totalOvertimeMs` / `dailyOvertimeMs` im Signal-State. Berechnet wird an drei Stellen:
- `_initInner` (Zeilen ~275-298): unterscheidet korrekt gestoppt (`workEnd`) und laufend (`new Date()`).
- `_recalculateState` (~625-661): bei `workStart && workEnd` korrekt mit `workEnd`.
- `_recalculateOvertime` (~573-599): **kennt nur „jetzt“**, auch wenn `workEnd` gesetzt ist. Das ist der Fehler.

## (1) Alle Stellen im Web mit „jetzt“ und Bewertung

| Stelle | Rechnet mit „jetzt“? | Bei gestopptem Eintrag falsch? |
|---|---|---|
| `dashboard.service.ts` `_recalculateOvertime` (573-599): `now` für Netto (`elapsed`), `_totalBreakMs(.., now)`, `_calcExpectedEnd` | ja, immer | **JA — der Bug.** `dailyOvertimeMs`, `totalOvertimeMs`, `expectedEndTime`, `expectedEndTotalZero` |
| `_tick` (551-561): `elapsedMs`, `grossMs` mit `now` | ja | nein: `if (!e.workStart \|\| e.workEnd) return;` am Anfang, nur laufend |
| `_initInner` Zeile 283-286 (`else if (workEntry.workStart)`) | ja | nein: Zweig nur ohne `workEnd` (gestoppt geht in den Zweig davor mit `workEnd`) |
| `_recalculateState` (631-641) | nein | korrekt (`workEnd`) |
| `_stopRunning` (351) / Start/Pause (`nowToMinute()`) | Zeitstempel setzen, keine Dauerberechnung | nein |
| `overtime.utils.ts` `calculateInitialOvertime` (`new Date()`) | nur Tagesvergleich `isSameDay(lastUpdate, heute)`, keine Dauer | nein (Heuristik, bekannt, siehe #372) |
| `reports.service.ts` 287, `report-calculator.ts` 44/126/193 | nein, nur `workEnd`; Eintrag ohne `workEnd` zählt 0 (wie Backend) | nein |
| `dashboard.ts` / `dashboard.html` | keine Datumslogik | nein |
| `today.ts`, `work-entry.ts:93`, `time-precision.util.ts` | Tages-Key / Zeitstempel | nicht betroffen |

Also genau **eine** fehlerhafte Stelle. Die Anzeige in `dashboard.html` (Zeilen 27-36) liest `dailyOvertime()`/`totalOvertime()` direkt;
`expectedEnd*` ist per `isTimerRunning()` ausgeblendet (47/52), der falsche Wert ist dort unsichtbar, sollte aber trotzdem konsistent sein.

**Wann wird `_recalculateOvertime` bei gestopptem Eintrag aufgerufen?** `_tick` ruft es nur laufend auf. Der Fehlerpfad ist der
Settings-Abo im Constructor (Zeilen 168-175): jede Emission von `settingsSvc.getSettings()` bei `status === 'ready'` ruft
`_recalculateOvertime()`, unabhängig vom Laufzustand. Auslöser:
- Nutzer ändert Soll/Arbeitstage in den Einstellungen (Firestore-`onSnapshot` re-emittiert; lokal `BehaviorSubject`), der Service ist Singleton und lebt weiter.
- Initiale Settings-Emission, die nach `_init` (status `ready`) eintrifft (Race: Abo im Constructor vs. `_init`; im lokalen Modus ist `BehaviorSubject` synchron, dann `loading` und harmlos; bei Firestore reihenfolgeabhängig, nicht verifiziert).
- Profilwechsel / Re-Emission der Settings.
Die Beschreibung im Issue („−2 h statt −3 h, sobald jetzt später als 11:00“) passt: Das Ergebnis ist `(jetzt − workStart − Pausen) − Soll`, wächst also mit der Uhrzeit, nach 14:00 (6 h Netto) sogar ins Plus.

## (2) Kanonische Logik

Backend (`ReportCalculator.NetWorkMs`, `GrossWorkMs`, `CalculateDailyStat`): Netto nur bei `WorkStart` **und** `WorkEnd` (`workEnd - workStart - Pausen`),
sonst 0; es gibt im Domain-Code **keine** Uhr (`UtcNow` kommt nur in `OvertimeRepository` als `lastUpdated` und `WorkProfileRepository.createdAt` vor).
Backend rechnet also nie mit „jetzt“; Tages-Überstunden = `worked − target + manualMs`. Ein laufender Eintrag ist rein Client-Sache (Live-Anzeige).

Abweichung am Rande (nicht Teil des Fixes): Backend `SumBreakMs` ignoriert offene Pausen (`End is null`), Web `_totalBreakMs(breaks, workEnd)` zählt eine offene Pause bis `workEnd`.
Beides gilt identisch in `_init`/`_recalculateState`, nur der Rand „gestoppt mit offener Pause“ (der Stop-Pfad verhindert das über `hasRunningBreak` nur für Pflichtpausen). Kein Handlungsbedarf für #390.

Flutter: `_recalculateOvertime` (view_model 340-366) und `_calculateElapsedTime` (332-337) rechnen ebenfalls immer mit `_now()`; Aufruf aus
`recalculateOvertimeFromSettings()` (Einstellungsänderung, nur Guard `workStart == null`). Identischer Fehler, bei Mobile aber über `_clock`/`_now()`.
Das ist **#386**, nicht Teil dieser Aufgabe. Flutters `_recalculateState`-Pendant (500-530) rechnet gestoppt korrekt mit `workEnd`.

Erwartetes Verhalten für Web (issue-konform): `end = e.workEnd ?? now`; Netto = `end − workStart − _totalBreakMs(breaks, end)`; daily = Netto − Soll + manuell. Gleiches `end` für `_calcExpectedEnd`-Pausen (für gestoppte Einträge ohnehin ausgeblendet).

## (3) Reproduktion als Test (Fake-Uhr, datums-/TZ-unabhängig)

Neuer Test in `web/src/app/features/dashboard/dashboard.service.spec.ts`, in einer `fakeClockSuite(...)` (setzt `vi.useFakeTimers()`), nutzt vorhandene Helfer `setup`, `mkEntry`, `settings$`.
Alle Zeiten lokal per `new Date(y, m, d, h, min)` (Konvention der Datei, keine ISO-/UTC-Strings, keine Wochentags-Annahme außer Arbeitstag; Mo 2026-10-05 wie in den bestehenden Tests, `DEFAULT_SETTINGS.workdays` enthält Mo).

Szenario A (Kern, rot vor dem Fix):
- `vi.setSystemTime(new Date(2026, 9, 5, 12, 0))`; Eintrag `mkEntry(2026, 9, 5, { workStart: 08:00, workEnd: 11:00 })`, kein `breaks` (<6 h, keine Pflichtpause).
- `setup({ entries: [...] })` mit `settings$` auf `weeklyTargetHours: 30` (bei 5 Arbeitstagen = 6 h Soll), `await vi.advanceTimersByTimeAsync(0)` damit `_init` durchläuft.
- Vorab-Assertion: `dailyOvertime() === -3 * H` (`_init`-Pfad, bereits korrekt).
- `settings$.next({ ...settings, weeklyTargetHours: 30 })` (neue Emission löst `_recalculateOvertime` aus), `vi.advanceTimersByTimeAsync(0)`.
- Erwartung: `dailyOvertime() === -3 * H`, `totalOvertime() === -3 * H` (Basis 0). Ohne Fix: `-2 * H` (12:00 − 08:00 − 6 h).
- Zusatz: Uhr nach 14:00 setzen (z. B. 15:00) und erneut emittieren: Wert bleibt `-3 * H` (ohne Fix `+1 * H`) — belegt „wächst mit der Uhr“.

Szenario B (Gegenprobe, muss grün bleiben): gleicher Eintrag nur mit `workStart`, Timer läuft, Uhr 12:00 → `dailyOvertime() === 4 * H − 6 * H`; Uhr +1 h → +1 h Differenz (bestehende Tests „Refokus“ decken das teilweise ab).
Szenario C (optional): gestoppter Eintrag mit manueller Überstunde (`manualOvertimeMinutes`) und Pause, Pause im Intervall vor `workEnd` — prüft, dass Pausen bis `workEnd` gezählt werden.
Szenario D (optional): Stop-Ablauf, d. h. laufender Eintrag, `startOrStopTimer()` um 11:00, danach Uhr auf 12:00 + Settings-Emission → `dailyOvertime()` bleibt der Wert von 11:00.

Test-Hinweise (aus `web/CLAUDE.md`): Datum/TZ-unabhängig, lokal in `TZ=UTC`/`America/Los_Angeles`/`Pacific/Auckland` prüfen; `TestBed.resetTestingModule()` + `vi.useRealTimers()` im `afterEach` (macht `fakeClockSuite` schon).

## (4) Auswirkung auf gespeicherte Daten

**Nur Anzeige, keine Reparatur nötig.** Belege:
- `_recalculateOvertime` schreibt ausschließlich per `this._s.update(...)` den lokalen Signal-State, kein `saveEntry`/`saveOvertime`.
- Persistiert wird der Saldo nur in `_recalculateState(save=true)` (`_saveOvertime(pid, totalMs)`) und `_stopRunning`; beide rechnen vorher selbst (gestoppt mit `workEnd`, korrekt) und nehmen **nicht** den State-Wert aus `_recalculateOvertime`. `_autoSave` speichert nur den Eintrag.
- `updateInitialOvertime` liest `dailyOvertimeMs` aus dem State (kann falsch sein) nur für die Anzeige `totalOvertimeMs = newBase + daily`; gespeichert wird `newBaseMs` (Basis ohne Daily). Folge: die Anzeige nach manueller Saldo-Änderung kann kurz falsch sein, das Persistierte ist richtig.
- Nächster `_init` / jede Aktion (`updateBreak`, `setManualEndTime`, …) überschreibt den State wieder mit dem korrekten Wert.
Einziger Randfall: Nutzer liest den falschen Wert ab und trägt ihn über „Gleitzeit anpassen“ ein (`dashboard.ts:79`: `currentOvertimeMs: totalOvertime()`). Dann wird der falsche Wert bewusst persistiert (User-Aktion, nicht reparierbar, kein Backfill sinnvoll).

## Domain-Mapping (Fix-Skizze, kein Code)
| Ist | Soll | Datei |
|---|---|---|
| `_recalculateOvertime`: `const now = new Date()` | `const end = e.workEnd ?? new Date()`; alle drei Verwendungen (`_totalBreakMs`, `elapsed`, `_calcExpectedEnd`) auf `end` | `features/dashboard/dashboard.service.ts` |
| Test | neue Fälle A-D in `fakeClockSuite` | `features/dashboard/dashboard.service.spec.ts` |
Kein Backend-, Firestore-, Rules-, i18n-, Routing- oder UI-Change. Keine Backend-Arbeit (`/server-implement` nicht nötig).

## UI-States
| State | Betroffen? |
|---|---|
| loading | nein (Aufruf nur bei `ready`) |
| data (laufend) | nein, bleibt wie bisher |
| data (gestoppt) | ja, Tages-/Gesamtüberstunden falsch nach Settings-Emission |
| empty (`workStart` fehlt) | nein (Guard `if (!e.workStart) return`) |
| error / premium-locked | nein |

## Offene Fragen und Empfehlungen
1. **Fix-Umfang:** Nur `end = workEnd ?? now` in `_recalculateOvertime` oder zusätzlich gestoppte Einträge dort ganz herausnehmen? Empfehlung: nur `end`-Variante. Ein Settings-Update (Sollstunden) muss einen gestoppten Eintrag neu bewerten; Früh-Return würde einen weiteren Fehler (Soll-Änderung wirkt nicht) einführen.
2. **`expectedEndTime`/`expectedEndTotalZero` bei gestopptem Eintrag:** Weiter berechnen (UI blendet per `isTimerRunning()` aus) oder auf `null` setzen? Empfehlung: unverändert lassen (mit `end` konsistent berechnen), minimaler Diff; `null` wäre sauberer, ändert aber `_recalculateState`-Semantik (setzt sie dort nicht zurück) und braucht Tests.
3. **Auslöser-Race (Settings-Emission nach `_init`):** Gesondert absichern (z. B. Settings-Abo erst nach Ready)? Empfehlung: nein, mit `end`-Fix ist jede Emission harmlos; kein Zusatz-Scope.
4. **Test-Umfang:** A (Pflicht), B als Regression; C/D optional. Empfehlung: A + B + D (Stop-Ablauf, deckt den realen Nutzerfluss), C weglassen.
5. **#386 (Mobile-Gegenstück):** Nicht in diesem Branch. Empfehlung: getrennt lassen; Backend ist unbeteiligt, Reihenfolge egal. Im PR #386 verlinken, damit Web/Mobile paritätisch bleiben.
6. **Branch/Workflow:** Der Branch `claude/week-number-display-bug-x5xq8r` heißt thematisch anders (Wochennummer-Bug) und steht auf `develop`. Empfehlung: Trotzdem hier arbeiten (vom Nutzer vorgegeben), PR-Titel mit `#390`; `/web-plan` kann bei einem Zwei-Zeilen-Fix entfallen, direkt TDD.
7. **Randnotiz Offene Pause (Backend ignoriert, Web zählt bis `workEnd`):** Separates Issue? Empfehlung: nur bei Bedarf als eigenes Issue, nicht in #390.

## Risiken
- Test-Falle Vite-SSR (siehe `web/CLAUDE.md`): neue Tests nur über Helfer/Konstanten im Spec, keine nackten importierten Werte als Klassenfeld-Initializer.
- Fake-Uhr + `settings$.next` im Vollauf: bestehende Suites setzen `vi.useRealTimers()`/`resetTestingModule()`; die Reihenfolge nicht ändern, sonst Flakiness im Gesamtlauf (CI-Kommando `npm test -- --watch=false`).
- Zeitzone: Alle Testzeiten lokal konstruiert; Differenzen (`3 * H`) sind unabhängig von DST, solange 08:00-11:00 des 5.10.2026 (kein DST-Tag) genutzt werden.

## Entscheidungen zu den offenen Fragen (Hauptsession)

1. Nur `end = e.workEnd ?? new Date()` in `_recalculateOvertime` (Netto, Pausen, `_calcExpectedEnd`); gestoppte Einträge nicht herausnehmen.
2. `expectedEnd*` unverändert lassen (UI blendet sie bei gestopptem Eintrag aus).
3. Keine zusätzliche Absicherung der Settings-Emission-Race.
4. Tests A (Kern), B (Gegenprobe laufend), D (Stop-Ablauf); C entfällt. Rot-Nachweis vor dem Fix.
5. #386 (Mobile) getrennt, im PR verlinken (nicht schließen).
6. Auf dem Session-Branch arbeiten, `/web-plan` entfällt (Zwei-Zeilen-Fix), direkt TDD.
7. Randnotiz (offene Pausen Backend vs. Web) nur als Hinweis im PR-Body, kein eigenes Issue ohne Bedarf.
