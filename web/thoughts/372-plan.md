# Web-Plan: #372 — Dashboard: Tageswechsel (Mitternacht) + anonymer visibilitychange-Listener
Erstellt: 2026-10-04
Research: web/thoughts/372-research.md (inkl. „Entscheidungen zu den offenen Fragen")
UI-Report: entfällt (Bugfix, keine UI-Änderung, keine neuen Texte)

## Ziel
Das Dashboard reagiert korrekt auf den Tageswechsel: gestoppter/leerer Eintrag schaltet still auf den neuen Tag, ein
laufender Timer läuft über Mitternacht weiter (Eintrag bleibt am Starttag, Soll/`isExtraDay`/Überstunden am Eintragsdatum),
keine Aktion schreibt mehr in den Vortag. Der anonyme `visibilitychange`-Listener und `_timerSub` verschwinden, alle
Listener/Timer werden über `DestroyRef` aufgeräumt.

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Hybrid-Service nötig? | nein | Kein neuer Datenzugriff; `TodayService` ist reine Zeit-Quelle |
| Neuer Core-Service? | ja: `core/services/today.ts` (`TodayService`, root) | Kapselt „heute"-Key, Midnight-Timer, Listener, Cleanup (aus #279 aus `DashboardService` herausgelöst). Kein Domain-Service: braucht `DestroyRef`/DOM |
| API `TodayService` | `readonly today: Signal<string>` (`YYYY-MM-DD`, `toDateKey`, lokale Felder) + `refresh(): void` (öffentlich, für den Tick-Abgleich) | Strings -> Signal-Gleichheit verhindert Doppel-Auslösung |
| Listener | benannte Handler: `visibilitychange` (nur `visible`), `window` `focus`, `window` `pageshow`; alle rufen `refresh()` + `_schedule()`; Entfernen mit derselben Referenz in `destroyRef.onDestroy` | Standby-Härtung (Frage 7); Leak-Fix |
| Midnight-Timer | `setTimeout` bis `new Date(y, m, d+1)` (lokal, min. 1000 ms), unverändert aus #279 | DST-sicher (23/25-h-Tage) |
| `holidayToday` | liest `todayService.today()`; `_today`, `_midnightHandle`, `_refreshToday`, `_scheduleMidnight`, `onVisible` aus `DashboardService` entfernt | Eine Quelle für „heute"; #279-Tests bleiben grün |
| `DashboardService`-Umbau | (1) `effect` auf `today()` (erster Lauf übersprungen, Rest `untracked`) -> `_onDayChange()`; (2) Generationszähler `_initGen` in `_init`; (3) Soll/`isExtraDay` ans Eintragsdatum; (4) Aktionen-Guard; (5) Anonym-Listener + `_timerSub` entfernt | siehe Research 9 |
| `_onDayChange()` | Timer läuft (`workStart && !workEnd`) -> nichts tun (Variante B). Sonst `_init(uid, { dayChange: true })` | Frage 1/2 |
| Soll-Kopplung | `_targetDailyMs(settings, forDate)`; Aufrufer übergeben `entry.date` (in `_init` `workEntry.date`, in `_recalculateOvertime` `_s().workEntry.date`, in `_recalculateState` `entry.date`). `isExtraDay` wird in `_recalculateOvertime`/`_recalculateState` aus `targetMs === 0` mitgeführt | Kein Soll-Sprung Fr->Sa / So->Mo bei laufendem Eintrag |
| Aktionen-Guard | `private async _ensureCurrentDay(): Promise<void>`: ist `toDateKey(workEntry.date) !== today()` **und** der Eintrag nicht laufend -> `await _init(uid, {dayChange:true})`. Aufruf am Anfang von `startOrStopTimer`, `startNewSession`, `startOrStopBreak`, `setManualStartTime`, `setManualEndTime`, `clearEndTime`, `updateBreak`, `deleteBreak`; danach `workEntry` neu lesen. Laufende Einträge sind ausgenommen (Stop/Pause gehören zum Starttag) | Verhindert `workStart=jetzt` im Vortagseintrag (Research 5.1) auch bei verpasstem Timer/Standby |
| `today()`-Frische im Guard | Vor dem Vergleich `todayService.refresh()` aufrufen | Standby: Timer evtl. noch nicht gefeuert |
| Autosave | `_autoSave` merkt sich Generation + Eintragsschlüssel, speichert nur, wenn unverändert | Kein Überschreiben des neuen Tags mit altem Eintrag; Fehler bleiben still (unverändert) |
| Tick-Abgleich | `_tick` ruft `todayService.refresh()` | Standby-Härtung, kostet nichts; `holidayToday` zieht nach |
| Stop nach Mitternacht | Nach Stop eines Eintrags mit `toDateKey(date) !== today()` und abgeschlossenem Speichern -> `_init(uid, {dayChange:true})`. **Default; Rückfrage O1** | Konsistent mit „gestoppt -> still auf neuen Tag" |
| Basis-Überstunden beim Reinit | `_init` mit `dayChange`: Basis = gespeicherter Wert (`stored`), **ohne** `calculateInitialOvertime`/`lastUpdated`-Heuristik; `calculateInitialOvertime`/`overtime.utils.ts` bleiben unverändert | Backend setzt `lastUpdated = jetzt`; ein Vortags-Save nach Mitternacht würde sonst den neuen Tages-Daily fälschlich abziehen (Research 5.4) |
| Final-Save vor Reinit | Variante B: kein Reinit bei laufendem Timer, also kein Final-Save nötig; jede Aktion speichert sofort. `_stopTimer()` am Anfang von `_init` bleibt | Kein Datenverlust-Fenster |
| Anonymer Listener | **entfernt**. Vorher Charakterisierungstest (Refokus + <= 1 s Tick aktualisiert Daily/Total/ExpectedEnd), der nach dem Entfernen grün bleiben muss; wäre er rot, wandert Recalc in einen benannten, über `DestroyRef` aufgeräumten Handler | Redundant zum 1-s-Tick; Entscheidung nach Test |
| `_timerSub` | entfernt (ungenutzt) | |
| Premium-Gate | nein | |
| Routing / API / Firestore-Pfad / Security Rule | nein | kein neuer Endpunkt, keine neuen Pfade |
| Neue Texte (i18n) | nein | Kein UI-Hinweis (Frage 6) |
| Shared Component | nein | Kalender-„heute" bleibt außerhalb (Folge-Issue) |
| Profilwechsel / Mobile | außerhalb (eigene Issues); `_init` mit Generationszähler ist der erweiterbare Reinit-Punkt, `profileId` später nur weiterer Trigger | Fragen 4/5 |

Kein `getTodayEntry`-Parameter nötig: der Reinit läuft nach dem Tageswechsel, `getTodayEntry()` bestimmt den Schlüssel zum
Abo-Zeitpunkt (= neuer Tag). Der Generationszähler schützt vor Überholern.

## Neue / geänderte Dateien

### Core Layer
```
web/src/app/core/services/
├── today.ts          # NEU: TodayService (root)
└── today.spec.ts     # NEU
```

### Feature Layer
```
web/src/app/features/dashboard/
├── dashboard.service.ts        # GEÄNDERT (Umbau, siehe Tabelle)
├── dashboard.service.spec.ts   # GEÄNDERT: feste Systemzeit in beforeEach, #279-Tests bleiben, neue describe-Blöcke
├── dashboard.ts / .html / .scss  # unverändert (reine Darstellung)
└── dashboard.spec.ts           # nur Audit: kein `new Date()` ohne Argument (Fake-Service, feste Daten) — bisher bereits ok
```

### Doku
```
web/CLAUDE.md   # GEÄNDERT:
                #  - core/services-Baum: `today.ts  TodayService — lokaler Tages-Key (Signal), Midnight-Timer, visibilitychange/focus/pageshow, Cleanup via DestroyRef (#372)`
                #  - Tabelle Feature-Services: DashboardService aggregiert zusätzlich TodayService, AuthService
                #  - Abschnitt „Feiertage (#279)": `holidayToday` liest `TodayService.today()` statt eigenem Timer
                #  - neuer Kurzabschnitt „Tageswechsel (#372)": Variante B (Timer läuft weiter, Eintrag bleibt Starttag,
                #    Soll/isExtraDay am Eintragsdatum), stilles Umschalten bei gestopptem Eintrag, Aktionen-Guard, Basis aus Stored
```
Keine Änderung an `overtime.utils.ts`, `work-entry.ts`, `overtime.ts`, Backend, Firestore-Rules, i18n.

## Test-Konventionen (für alle Schritte)
- `vi.useFakeTimers()` + `vi.setSystemTime(new Date(y, m, d, h, min))` (lokale Konstruktoren, nie UTC-/ISO-Strings), `advanceTimersByTimeAsync` für asynchrones `_init`/Saves.
- Dauern nie hart kodieren: `new Date(next).getTime() - Date.now()` (23-/25-h-Tage).
- Erwartete Datumsschlüssel/Wochentage über lokale Konstruktoren/`toDateKey`, nicht über Konstanten.
- Läufe: `TZ=Europe/Berlin` (CI), `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland`, `TZ=UTC`, jeweils `npm test -- --watch=false` aus `web/`. Alle Tests müssen in allen vier Zonen grün sein (keine TZ-Annahme im Code; kein `process.env.TZ` im Spec). CI bleibt bei Berlin.
- DST-Daten als feste lokale Daten: 2026-03-29 (Berlin 23 h), 2026-10-25 (Berlin 25 h); in LA/Auckland fallen die Umstellungen auf andere Tage, daher nur Invarianten prüfen (Key = lokaler Folgetag, Delay = Differenz der lokalen Mitternächte), zusätzlich Auckland-Umstellung 2026-09-27 (23 h) und 2026-04-05 (25 h), LA 2026-03-08 / 2026-11-01 als Zusatzdaten in einer `it.each`.
- Fake-Services im `TestBed` (wie bestehender `create()`-Helper): `getTodayEntry` liefert je nach `Date.now()` den passenden Eintrag (Fake, der Key aus `new Date()` ableitet wie das echte), `saveEntry` = `vi.fn()`, `AuthService.user` als Signal.
- Bestehende Dashboard-Tests: `beforeEach` setzt `vi.setSystemTime(new Date(2026, 9, 3, 12, 0))` als Default (alle `create()`-Aufrufer), damit kein Test von der echten Uhr abhängt; Einzeltests überschreiben. Audit-Grep `new Date\(\)` ohne Argumente in `dashboard*.spec.ts` (aktuell keine Treffer) ist Teil von Schritt 0.

## Implementierungsschritte (TDD-First, rot vor Fix)

### Schritt 0: Absicherung der Bestandstests
- [x] `dashboard.service.spec.ts`: Default-Systemzeit in `beforeEach` (siehe oben), grep-Audit beider Dashboard-Specs, Lauf in 4 Zeitzonen = grün (Baseline vor jeder Änderung).
- [x] Charakterisierungstest „Refokus": laufender Timer, `visibilityState` hidden -> Zeit +5 min (`setSystemTime`, ohne Ticks) -> `visible` + `visibilitychange` -> `advanceTimersByTime(1000)` -> `dailyOvertime`/`totalOvertime`/`expectedEndTime` aktuell. Muss vor und nach Entfernen des Listeners grün sein.
- [x] Charakterisierungstest „Leck" (rot): Service erzeugen, `TestBed.resetTestingModule()`, dann `document.dispatchEvent(new Event('visibilitychange'))` -> Spy auf `Date`-Zugriff/`workSvc` des zerstörten Service nicht aufgerufen. Rot wegen anonymem Listener.

### Schritt 1: `TodayService` (Core) — `core/services/today.spec.ts` zuerst
Tests (alle rot, Datei existiert noch nicht):
- [x] initial = `toDateKey(now)` (fest: 2026-10-03 12:00 -> `'2026-10-03'`).
- [x] 23:59:30 -> `advanceTimersByTime(31_000)` -> Folgetag; 23:59:59.999 + 1 ms -> Folgetag; Delay-Minimum 1 s (00:00:00.000 -> kein Spin, `vi.getTimerCount()` = 1).
- [x] Folgetag-Timer wird neu geplant (zweiter Wechsel nach 24 h lokal: `new Date(y,m,d+1) - Date.now()`).
- [x] Jahreswechsel 2026-12-31 23:59:30 -> `'2027-01-01'`; Schaltjahr 2028-02-28 23:59:30 -> `'2028-02-29'`, danach `'2028-03-01'`.
- [x] DST: 2026-03-28 23:59:30 -> `'2026-03-29'`, dann Folgetag `'2026-03-30'` (Delay = lokale Mitternachtsdifferenz); 2026-10-24 -> `-25` -> `-26`; Zusatzdaten LA/Auckland per `it.each` mit Invariante „Key = lokaler Folgetag".
- [x] `visibilitychange` `visible` nach Zeitsprung (`setSystemTime` auf Folgetag ohne Timer-Ablauf) aktualisiert Key und plant Timer neu; `hidden` ändert nichts.
- [x] `window` `focus` und `pageshow` aktualisieren ebenfalls (Standby).
- [x] `refresh()` setzt den Key, Signal feuert nicht doppelt (Effect-Zähler = 1 pro Tageswechsel).
- [x] Cleanup (kein Leak): Spy auf `document.addEventListener`/`window.addEventListener` und `removeEventListener`; Handler-Referenz aus `addEventListener.mock.calls` muss in `removeEventListener.mock.calls` mit **derselben Referenz** und Eventnamen (`visibilitychange` auf document, `focus`/`pageshow` auf window) stehen; nach `TestBed.resetTestingModule()`: `vi.getTimerCount()` = 0, Events lösen kein `refresh` mehr aus.
- [x] Impl: `today.ts` (`@Injectable({providedIn:'root'})`, `inject(DestroyRef)`, `signal`, `asReadonly`, `_schedule`/`refresh`, benannte Handler). Logik 1:1 aus `DashboardService` (#279) übernehmen, ergänzt um `focus`/`pageshow`.

### Schritt 2: `holidayToday` auf `TodayService` umstellen (Refactor, grün halten)
- [x] Bestehende #279-Tests (Midnight, Visibility, DST, rein informativ) bleiben unverändert und laufen zuerst gegen den alten Code (grün), dann nach Umstellung (grün). Test-Setup: echter `TodayService` (root) im `TestBed`, `TestBed.resetTestingModule()` bleibt.
- [x] Impl: `DashboardService` injiziert `TodayService`, `holidayToday` liest `todayService.today()`, `_today`/`_midnightHandle`/`_refreshToday`/`_scheduleMidnight`/`onVisible`-Block und dessen `onDestroy` entfernen, `toDateKey`-Import nur falls noch gebraucht.
- [x] Altes Destroy-Test (Z. 155, „irgendein removeEventListener") an `TodayService` binden bzw. durch die Handler-Referenz-Variante aus Schritt 1 ersetzen.

### Schritt 3: Soll/`isExtraDay` ans Eintragsdatum koppeln
Tests zuerst (rot), `describe('Eintragsdatum-Kopplung (#372)')`:
- [x] Fr 2026-10-02 08:00 Timer läuft (Eintrag Fr), Zeit -> Sa 2026-10-03 01:00: `dailyOvertime` = elapsed − Soll **Freitag** (Soll springt nicht auf 0), `expectedEndTime` unverändert gegenüber vor Mitternacht (bezogen auf Fr-Soll).
- [x] So 2026-10-04 -> Mo 2026-10-05, laufender Timer: Soll bleibt 0 (So-Eintrag), `isExtraDay` bleibt true; Gegenprobe: Mo-Eintrag Soll 8 h (Settings `[1..5]`, 40 h).
- [x] Gestoppter Eintrag mit Start/Ende, `_recalculateState` (z. B. `updateBreak`) nach Mitternacht rechnet mit Soll des Eintragstags.
- [x] Laufender Timer über 2026-03-29 und 2026-10-25 (z. B. Start 22:00, Ablauf bis 03:00 am Folgetag, Elapsed = absolute ms-Differenz, nicht hart kodiert) ohne Fehlrechnung; Soll am Starttag.
- [x] Impl: `_targetDailyMs(settings, forDate)`, Aufrufer anpassen, `_init` nutzt `workEntry.date` statt `today` für `targetDailyMs`/`isExtraDay`, `isExtraDay` in `_recalculateOvertime`/`_recalculateState` aktualisieren.

### Schritt 4: Generationszähler in `_init`
Tests zuerst (rot):
- [x] Zwei `_init`-Läufe überlappend: erster mit verzögertem `getOvertime` (Promise manuell auflösen), zweiter schnell; nach Auflösen des ersten bleibt der Zustand des zweiten (Eintrag, Überstunden). Variante mit Auth-Wechsel (`user.set(...)` Login um 23:59) und Tageswechsel gleichzeitig.
- [x] Alter Lauf startet keinen Timer (`vi.getTimerCount()`) und setzt `status` nicht.
- [x] Impl: `_initGen`, `const gen = ++this._initGen`, nach jedem `await` `if (gen !== this._initGen) return;`, auch im `catch`. `_init(uid, opts?: { dayChange?: boolean })`.

### Schritt 5: Tageswechsel-Effect (stiller Wechsel) + Basis aus Stored
Tests zuerst (rot):
- [x] Gestoppter/leerer Eintrag Fr 2026-10-02 23:59:30, Fake `getTodayEntry` liefert nach Mitternacht `null` -> nach `advanceTimersByTimeAsync(31_000+)` ist `workEntry().id`/`date` = 2026-10-03, Daily/Total für Sa (Soll 0), kein `saveEntry`-Aufruf.
- [x] So -> Mo (2026-10-04 -> 05): Soll 8 h für den neuen Tag, Eintrag neuer Tag.
- [x] Stiller Wechsel bei vollständigem gestopptem Eintrag (Start+Ende am Vortag): neuer Tag leer, keine Speicherung, `saveOvertime` nicht aufgerufen.
- [x] Standby: `setSystemTime` auf Folgetag ohne Timerablauf, `window` `focus` (und `pageshow`) dispatchen -> Wechsel erfolgt (async flush); ebenso Key-Abgleich im Tick bei laufendem Timer (Holiday-Chip zieht nach, Eintrag bleibt).
- [x] Laufender Timer über Mitternacht: kein `_init`, kein `saveEntry` mit neuem Datum, `workEntry().date` = Starttag, Timer läuft weiter (`isTimerRunning`), `_autoSave` (30 Ticks) speichert Eintrag mit Starttag-`date`/-`id`.
- [x] Basis-Überstunden: `getOvertime`=120 min, `getLastUpdateDate` = **neuer** Tag (Backend-`lastUpdated` nach Vortags-Save), neuer Eintrag mit `workStart` -> `initialOvertime` = 120 min (nicht 120 min − Daily), Total = Basis + Daily. Gegenprobe normaler `_init` (ohne `dayChange`) unverändert (`calculateInitialOvertime`).
- [x] DST: Wechsel 2026-03-28 -> 29 und 2026-10-24 -> 25 -> 26 (Berlin) mit stillem Wechsel; Key = lokaler Folgetag auch in LA/Auckland (Invariante).
- [x] Anonym (`user` = null, Fake-localStorage-Pfad im `WorkEntryService`-Fake) und eingeloggt (`user` mit `uid`): gleicher Wechsel, anonym unverändert (kein ApiClient-Aufruf, `isLoggedIn` false); Login um 23:59 + Mitternacht = genau ein gültiger Endzustand (Generationszähler).
- [x] Impl: `effect` in `constructor` (`todayService.today()` lesen, erster Lauf überspringen via Flag, Rest `untracked`) -> `_onDayChange()`; `_init`-Basis-Zweig `opts.dayChange`.

### Schritt 6: Aktionen-Guard (Regression 5.1)
Tests zuerst (rot):
- [x] Gestoppter leerer Vortagseintrag, Systemzeit nach Mitternacht, **ohne** Timer-/Effect-Ablauf (Fake-`TodayService.refresh` nicht gefeuert): `startOrStopTimer()` -> `saveEntry` mit `date`/`id` = **heute**, `workStart` heute, kein Save auf den Vortag.
- [x] `startNewSession(keepBreaks)` auf abgeschlossenem Vortag überschreibt `workStart`/`workEnd` des Vortags **nicht**; neuer Eintrag heute; `startOrStopBreak`, `setManualStartTime`/`EndTime`, `clearEndTime`, `updateBreak`, `deleteBreak` schreiben ausschließlich auf heute (`it.each` über alle Aktionen).
- [x] Laufender Eintrag (Variante B): Stop nach Mitternacht speichert auf Starttag, `calculateAndApplyBreaks` auf Brutto > 24 h ohne Fehler, `saveOvertime` mit Soll Starttag; anschließend Reinit auf heute (O1), `saveEntry`-Reihenfolge: alter Eintrag vor `_init`; kein Save auf neuen Tag mit altem Eintrag.
- [x] Pause starten/stoppen im laufenden Vortagseintrag bleibt am Vortagseintrag (offene Pause läuft weiter).
- [x] Autosave nach Reinit: nur neuer Eintrag, Zähler zurückgesetzt, alter Eintrag nicht mehr gespeichert.
- [x] Impl: `_ensureCurrentDay()` + Aufrufe, Generation/Schlüssel-Check in `_autoSave`, Reinit nach Stop eines Vortagseintrags.

### Schritt 7: Anonymen Listener + `_timerSub` entfernen, Cleanup prüfen
- [x] Rote Tests aus Schritt 0 („Leck") werden grün; Charakterisierungstest „Refokus" bleibt grün (sonst Handler benennen und per `DestroyRef` aufräumen, siehe Entscheidungstabelle).
- [x] DestroyRef-Test Dashboard: nach `TestBed.resetTestingModule()` `vi.getTimerCount()` = 0 (kein `interval`, kein Midnight-Timer), `visibilitychange`/`focus`/`pageshow`/Tageswechsel lösen keinen `workSvc`-/`saveEntry`-Aufruf mehr aus; Handler-Referenz-Vergleich für `removeEventListener`.
- [x] Impl: Block „Page Visibility API" und `_timerSub` löschen; ungenutzte Imports (`interval` bleibt für Timer, `isSameDay` prüfen) bereinigen.

### Schritt 8: Doku + Gesamtlauf
- [x] `web/CLAUDE.md` wie oben aktualisieren.
- [x] `npm test -- --watch=false` in `TZ=Europe/Berlin`, `America/Los_Angeles`, `Pacific/Auckland`, `UTC` + `npm run build -- --configuration production` (aus `web/`).
- [x] Manuelle Browser-Verifikation (nicht automatisierbar): Tab offen über Mitternacht (Systemuhr stellen), laufender Timer über Mitternacht, Laptop-Standby.
- [x] Commit/PR übernimmt die Hauptsession (kein Commit durch den Planer).

## Signal-Design

```typescript
// core/services/today.ts
@Injectable({ providedIn: 'root' })
export class TodayService {
  private readonly _today = signal(toDateKey(new Date()));
  readonly today = this._today.asReadonly();
  refresh(): void;               // setzt Key aus new Date()
  // privat: _schedule() (setTimeout bis lokale Mitternacht, min. 1000 ms),
  //         benannte Handler _onVisibility/_onFocus/_onPageShow, onDestroy-Cleanup
}

// DashboardService (Ergänzungen)
private readonly todayService = inject(TodayService);
private _initGen = 0;
readonly holidayToday = computed(/* liest this.todayService.today() */);
// constructor: effect(() => { const day = this.todayService.today(); untracked(() => this._onDayChange(day)); }) mit Skip des ersten Laufs
```

## Offene Fragen an die Hauptsession
- O1: Nach Stop eines über Mitternacht gelaufenen Timers sofort auf den neuen (leeren) Tag umschalten (Default im Plan, konsistent mit „gestoppt -> still wechseln") oder den gerade beendeten Eintrag sichtbar lassen, bis die nächste Aktion/der nächste Reload den Guard auslöst? Wirkt nur auf Schritt 6/Stop-Pfad.
- O2: TZ-Matrix (LA/Auckland/UTC) nur lokal/manuell oder zusätzlich als CI-Matrix? Plan: nur lokal/manuell, CI unverändert Berlin (kein Eingriff in `ci.yml`).
- Keine weiteren Rückfragen; Profilwechsel (Frage 4) und Mobile (Frage 5) bleiben eigene Issues.
