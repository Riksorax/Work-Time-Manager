# Web-Plan: #385 Teil 2 — „Fortsetzen" eines offenen Eintrags im Banner (Web-Parität zu Mobile PR 1b #422)
Erstellt: 2026-10-05
Research: web/thoughts/385-research.md (Fortsetzen war dort ausdrücklich ausgeklammert)
Vorgänger: web/thoughts/385-plan.md (Banner Beenden/Später, gemergt #409). Vorlage: mobile/thoughts/385-plan-1b.md, 385-pr-1b.md, mobile/CLAUDE.md „Offene Einträge vor heute (#385)"
UI-Report: entfällt (Stitch nicht verfügbar; ein zusätzlicher Button im bestehenden Banner, Hierarchie siehe Schritt 5)
Branch: claude/week-number-display-bug-x5xq8r (auf origin/develop), PR gegen `develop`

## Ziel
Der Banner bietet für den **neuesten** offenen Eintrag vor heute zusätzlich „Fortsetzen" an, wenn der heutige Tag leer ist
und der Eintrag höchstens 24 h alt ist. Fortsetzen lädt den Vortag ins Dashboard („Pinning"), der Timer läuft über Mitternacht
weiter (#372-Zustand), Stop speichert am Starttag und schaltet auf heute um. Nichts ändert sich ohne Nutzeraktion; Fortsetzen
schreibt selbst nichts (erst Autosave/Stop).

Nicht Teil: Backend, Splitten (#381), Fortsetzen für ältere/nicht-neueste Einträge, Re-Check beim Tab-Rückkehr, Scan anderer
Profile, Reports (#404/#407), Meldung bei Ablehnung.

## Ist-Stand (im Code geprüft)
- `DashboardService._init(uid, { dayChange })` → `_initInner`: liest immer `getTodayEntry(pid)`, Generationszähler `_initGen`,
  `_initRun`. Mit `dayChange` bleibt der alte Zustand stehen (kein Ladezustand), ohne `dayChange` wird `initialState()` (status
  `loading`) gesetzt. Basis bei `dayChange && !dailyAlreadyStored` = gespeicherter Saldo; bei offenem Eintrag ist
  `dailyAlreadyStored` immer `false`. Genau diese Basis braucht Fortsetzen (nicht die `lastUpdated`-Heuristik).
- **Falle:** der `catch` in `_initInner` setzt nur `status: 'ready'` auf dem Platzhalter (leerer heutiger Eintrag, Basis `null`).
  Ein Ladefehler sieht von außen wie „heute leer" aus. Es gibt kein Pendant zu Mobile `_loadedOk`.
- `_ensureCurrentDay` wartet nur bei `status === 'loading'` auf `_initRun`; `_isCurrentDay` lässt laufende Einträge durch;
  `_onDayChange` und der Stop-Pfad (`_stopRunning` → `_init({dayChange:true})` bei `toDateKey(updated.date) !== today`) kennen
  einen laufenden Vortag bereits (#372). `reloadAfterRetroClose` hat den Zweig „laufender Vortag: nur Basis erneuern".
- Dashboard-Template zeigt bei `isLoading()` einen Spinner (kein Banner, keine Start/Stop-Buttons), sonst Banner + Inhalt;
  Fokus-Anker `p.timer-label#focusAnchor` liegt im `@else`.
- `OpenEntryService`: `_candidates`/`_found`, `entries` (ohne `dashboard.workEntry().id`, ohne Später, leer solange Dashboard lädt),
  `current`, `busy`, `closedCount` (steuert Fokus im Dashboard), Effect-Trigger inkl. `_dashEntryId`, `_search`. `endEntry`
  setzt `busy` im `finally` unbedingt zurück.
- `date` eines Web-Eintrags ist UTC-Mitternacht, der Tag kommt immer aus der `id` (`localDateFromEntryId`); der Close-Service
  schreibt `date` deshalb als lokales Datum aus der `id` zurück. Pinning muss dasselbe tun, sonst stimmen Soll und
  `isExtraDay` westlich von UTC nicht (`_targetDailyMs(settings, entry.date)`).
- Ein Einzel-Read für einen Tag existiert nicht; `WorkEntryService.getEntriesForMonthOnce(y, m, pid)` + Suche per `id` genügt
  (kein neuer Core-Endpunkt, `getTodayEntry` ist ein Live-Stream und für Vortage ungeeignet).

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Hybrid-Service / Core-Änderung? | Nein | `getEntriesForMonthOnce` reicht; keine neue API, kein Firestore-Pfad, keine Rule |
| Backend? | Nein | Fortsetzen schreibt nichts |
| Neuer Domain-Service? | Nein, eine reine Funktion `canResumeOpenEntry` in `domain/utils/open-entry.utils.ts` | Einzige Regel für Anzeige **und** Durchsetzung (zwei Prüfstellen, eine Regel) |
| Regel `canResumeOpenEntry({ entry, now, todayId, todayIsEmpty })` | Typ work, Start, kein Ende, `id < todayId` (String-Vergleich), `now − workStart <= OPEN_ENTRY_MAX_NOW_AGE_MS` (inklusiv, wie „Jetzt"), `todayIsEmpty` | Wie Mobile; Tag aus `id`, nicht aus `date` |
| „Heute leer" | Neues Computed `DashboardService.todayIsEmpty`: nicht ladend, **geladen ohne Fehler**, `workEntry().id === today()`, Typ work, kein `workStart`. Heutiger Urlaub/Krank zählt nicht als leer | Wie Mobile. Dafür neues Signal `_loadOk` (true am Ende von `_initInner`, false zu Beginn und im `catch`), da `status` nach einem Fehler ebenfalls `ready` ist |
| Pinning-Technik | `_init(uid, { dayChange?, pinned?: { id, entry } })`, `_initInner` liest bei `pinned` statt `getTodayEntry` den Monat per `getEntriesForMonthOnce(y, m, pid)` und sucht per `id`. Rest unverändert | Kleinster Eingriff; Gen-Prüfungen gelten automatisch |
| Frisch lesen + Validierung | Gelesener Eintrag muss weiter offen sein (Typ work, Start, kein Ende) **und** erneut `canResumeOpenEntry`-konform (Alter, Tag; `todayIsEmpty` ist da schon geprüft) sein. Sonst: nicht pinnen, normaler heutiger Ladepfad, `resumePastEntry` liefert `false`. Der 24-h-Re-Check am frischen Eintrag ist strenger als Mobile (dort offener Punkt im Review) | Nie einen beendeten Eintrag als laufend anzeigen/überschreiben |
| Lesefehler beim Pin | Eigenes try/catch nur um den Pin-Read: Fehler = nicht pinnen, normaler heutiger Ladepfad, `false`. Das Dashboard bleibt damit korrekt geladen (`_loadOk` true). Abweichung zu Mobile (dort `_loadedOk=false`, Nachladen bei der nächsten Aktion): Web hat diesen Nachladepfad nicht (siehe Falle oben), also darf der Fehler nicht in den `catch` laufen | Dashboard bleibt benutzbar |
| Ladezustand beim Pin | **Ohne** `dayChange`-Verhalten für den Zustand: `_s.set(initialState())` (Spinner), aber Basis wie `dayChange` (gespeicherter Saldo). Dafür in `_initInner`: `storedBase = dayChange \|\| !!pinned` für die Basisformel, die Zustandsrücksetzung bleibt an `!dayChange` gebunden (Pin setzt sie also) | Entspricht Mobile `isLoading: true`; im UI sind Start/Stop während des Pins nicht erreichbar (Spinner). Ein Dashboard-Service-Aufruf in der Lücke wartet in `_ensureCurrentDay` (`status loading && _initRun`) auf den Pin und sieht danach einen laufenden Vortag (`startOrStopTimer` würde stoppen, dokumentierte Grenze wie Mobile) |
| Reihenfolge in `resumePastEntry(entry, pid)` | (1) `while (_initRun !== null) await _initRun` (wie `_ensureCurrentDay`), (2) **synchron ohne `await`**: `pid === _loadedProfileId === activeProfileId()`, `todayIsEmpty()`, `canResumeOpenEntry` mit frischer Uhr und `todayService.refresh()` vorher, dann `_init(..., { pinned })` | Keine Lücke zwischen Prüfung und `_initGen`++; kein `_ensureCurrentDay` (es würde auf heute zurückschalten) |
| Rückgabe | `true` nur, wenn der Lauf gepinnt hat und nicht überholt wurde (`_pinnedGen === _initGen` nach dem `await`, `workEntry().id === entry.id`); danach sofort `_tick()` (sonst `elapsedMs` 0 bis zum nächsten Sekunden-Tick, Muster `reloadAfterRetroClose`) | Wie Mobile |
| `ActionCtx` nötig? | Nein | Kein Write (Eintrag/Saldo); Überholung (Profil-/Tageswechsel, Login) läuft über `_initGen`. Autosave/Stop nutzen danach ihre eigenen Kontexte (`saveEntry(entry, _loadedProfileId)`). Regel #380 gilt für Writes, hier gibt es keine |
| Eintrags-`date` im Pin | `{ ...frisch, date: localDateFromEntryId(id) }` | Soll/`isExtraDay`/Stop-Reinit hängen an `date` (UTC-Falle westlich von UTC); identisch zum Close-Service |
| Timer über Mitternacht | Unverändert #372 (`_onDayChange`, `_ensureCurrentDay`, `_isCurrentDay`) | Nur Regressionstest |
| Offene Pause | läuft weiter (`_totalBreakMs` nimmt `until` für offene Pausen) | wie Mobile |
| Stop → Reinit | bestehender Pfad, nur Regressionstest | |
| Banner-Zustand `canResume` | `OpenEntryService.canResume` (Computed): `current` + `entryOf(current.id)` + `dashboard.todayIsEmpty()` + `todayService.today()` + ein Uhr-Signal `_clockTick` (wird bei Ablehnung und bei Suchläufen erhöht, damit `Date.now()` im Computed neu bewertet wird) → `canResumeOpenEntry`. Gilt nur für `current` (neuester sichtbarer). Ältere Kandidaten bieten nie Fortsetzen: solange der neueste gepinnt ist, ist heute nicht leer, danach ist der ältere in der Praxis älter als 24 h | Button nur sichtbar, wenn er wirkt; Tap prüft zusätzlich frisch |
| Aktion `OpenEntryService.resume(candidate)` | `Promise<boolean>`: `busy`-Guard, `epoch` und Entry festhalten, Regel mit frischer Uhr erneut prüfen, `await dashboard.resumePastEntry(entry, candidate.profileId)`; nach dem `await` bei geändertem `epoch` nichts anfassen. Erfolg: Kandidat sofort aus `_candidates`/`_found` entfernen (siehe Flash-Schutz), `closedCount++` (Fokus), kein Zusatz-Read, Später-Set unberührt. Ablehnung (`false`): `_clockTick++`, **stille Neusuche** `_search` (nur lesend, Seq/Epoch-geschützt): ein anderswo beendeter Eintrag verschwindet, ein weiter offener bleibt | Wie Mobile (Review-Fund 7) |
| `busy` | Zurücksetzen nur, wenn `epoch` unverändert; bei Kontextwechsel (`_ctxEpoch++` in `_onTrigger`) wird `busy` selbst auf `false` gesetzt. Gilt auch für `endEntry` (bisher `finally` unbedingt: ein überholter Lauf aus Profil A würde `busy` von Profil B zurücksetzen) | Mobile-Review: „busy des neuen Profils bleibt". Kleine Härtung des bestehenden Pfads, mit Regressionstest |
| Flash-Schutz | Der Effect in `OpenEntryService` merkt sich die vorherige `_dashEntryId`; wechselt sie, wird der **vorherige** Tag synchron aus `_candidates`/`_found` entfernt, bevor die Suche läuft | Nach Pin → Stop → Reinit auf heute (Dashboard-Id wechselt auf heute) würde der Vortag sonst aus einem älteren Suchergebnis kurz wieder als Banner erscheinen. Der Folge-Read findet ihn beendet |
| Ablehnung ohne Text | Still, kein Snackbar, kein neuer Text (Button verschwindet bzw. Banner wird neu gesucht) | wie Mobile; dokumentierte Grenze |
| Fokus nach Erfolg | über bestehendes `closedCount`-Signal: nächster Banner, sonst Anker `p.timer-label`. Während des Pins zeigt das Dashboard den Spinner, `afterNextRender` läuft nach dem Ende von `resumePastEntry` (Service-Promise endet erst nach `_init`), der Anker ist dann gerendert. Keine zusätzliche `LiveAnnouncer`-Ansage (kein dritter Key) | Parität, keine Zusatztexte |
| Premium-Gate | Nein | Datensicherheit |
| Routing | Nein | |
| Neue Texte | Ja, 2 Keys `dashboard.openEntryContinue`, `dashboard.openEntryContinueSemantics` | #221 |
| Shared Component | Bestehender `OpenEntryBannerComponent`, rein darstellend, bekommt `canResume` + Output `resume` | |

## Neue / geänderte Dateien

### Domain
```
web/src/app/domain/utils/open-entry.utils.ts        # + canResumeOpenEntry
web/src/app/domain/utils/open-entry.utils.spec.ts   # + Tests
```

### Feature Layer
```
web/src/app/features/dashboard/dashboard.service.ts       # _loadOk, todayIsEmpty, pinned in _init/_initInner, resumePastEntry (heikel)
web/src/app/features/dashboard/dashboard.resume.spec.ts   # neu (Pinning, Saldo, Races); bestehende dashboard.service.spec.ts bleibt grün
web/src/app/features/dashboard/open-entry.ts              # canResume, resume(), Flash-Schutz, busy-Härtung
web/src/app/features/dashboard/open-entry.spec.ts         # erweitert
web/src/app/features/dashboard/dashboard.ts / .html       # Banner-Bindings, onResumeOpenEntry
web/src/app/features/dashboard/dashboard.spec.ts          # erweitert
web/src/app/shared/components/open-entry-banner/open-entry-banner.ts / .html / .scss / .spec.ts
web/src/app/shared/testing/open-entry-fake.ts             # canResume-Signal, resumeCalls, resumeResult (ohne vi-Import)
web/public/i18n/de.json, en.json                          # 2 Keys
web/src/app/core/i18n-open-entry.spec.ts                  # erweitert (Keys, Platzhalter, Test „kein Fortsetzen" umkehren)
web/CLAUDE.md                                             # Doku
```
Kein Core-/ApiClient-/Settings-Eingriff. Die Dashboard-Fakes in `dashboard.spec.ts`, `.switch`, `.profile` und im
`open-entry.spec.ts` brauchen `todayIsEmpty`/`resumePastEntry` (Stub-Pflege in Schritt 3 und 4 einplanen).

## Test-Rahmen (gilt für alle Schritte)
- Rot-Nachweis je Schritt: Spec zuerst, Fehlschlag festhalten (`web/thoughts/385-pr-fortsetzen.md`), dann implementieren.
  Einzelspec per `--include` (Flag aus #385 Schritt 0 bekannt), vor Abschluss immer **Vollauf** (Fake-Timer-Interferenz #392).
- Feste lokale Daten: `vi.useFakeTimers()` + `vi.setSystemTime(new Date(2026, 9, 3, 9, 0))` (Sa 2026-10-03 09:00 lokal), offener
  Eintrag Fr 2026-10-02 22:00 lokal (`id` `2026-10-02`). Weitere Tage nur als lokale Konstruktoren; Monatsgrenze 10-31/11-01,
  Jahreswechsel 2026-01-01/2025-12-31; DST nur als Invarianten (absolute Differenzen, lokale Folgetag-Schlüssel): 2026-10-25,
  2026-03-29 (Berlin), 2026-11-01, 2026-03-08 (LA), 2026-04-05 (Auckland). Kein Wochentag-/Zonen-Hartcode. Fr als Arbeitstag,
  Sa als Zusatztag aus den Test-Einstellungen (`workdays [1..5]`), nicht aus dem Kalender abgeleitet.
- **Kein `setTimeout`-Flush.** Flush nur über Microtasks (`await Promise.resolve()` in Schleife, `TestBed.tick()`); Specs mit
  eigenem Fake-Timer (Dashboard-Service-Specs, Timer-Ticks) mit `vi.advanceTimersByTimeAsync(0)` bzw. `advanceTimersByTime(1000)`
  fürs Tick-Intervall. `afterEach`: `vi.useRealTimers()`, `TestBed.resetTestingModule()`.
- **LiveAnnouncer gemockt** (`{ provide: LiveAnnouncer, useValue: { announce: vi.fn() } }`); in den Fortsetzen-Tests zusätzlich
  Assertion, dass Fortsetzen **keine** Ansage auslöst. `MatSnackBar` gemockt (Assertion: bei Ablehnung nie geöffnet).
- **Vite-SSR-Falle:** keine nackten importierten Werte als Klassenfeld-Initializer (`OPEN_ENTRY_MAX_NOW_AGE_MS`,
  `DEFAULT_WORK_PROFILE_ID`, `WorkEntryType.Work`). Neue Felder (`_loadOk = signal(false)`, `_pinnedGen = 0`, `_clockTick = signal(0)`)
  sind Literale; Konstanten nur im Funktionskörper (`canResumeOpenEntry`) referenzieren, nie als Feld. Fakes in
  `shared/testing/` ohne `vi`-Import (`tsconfig.app.json`, `types: []`).
- Fakes: bestehende Fake-Repos/`work-profile-fake.ts`, gemeinsames Schreib-Log mit Label und `pid` (Assertion „Fortsetzen schreibt
  nichts"). Für „Read halten" ein manuell auflösbares Promise (kein Timer).
- TZ-Läufe: je Schritt `TZ=Europe/Berlin` (CI), in Schritt 7 zusätzlich `UTC`, `America/Los_Angeles`, `Pacific/Auckland`.

## Implementierungsschritte (TDD-First)

### Schritt 1: Domain — `canResumeOpenEntry`
- [x] Tests (`open-entry.utils.spec.ts`):
  - Fr 22:00 offen, jetzt Sa 09:00, `todayId` `2026-10-03`, heute leer → `true`
  - heute nicht leer → `false`; Typ vacation/sick/holiday → `false`; ohne Start → `false`; mit Ende → `false`
  - `id == todayId` und `id > todayId` → `false` (nur Tage vor heute)
  - Alter genau 24 h → `true`; 24 h + 1 ms bzw. + 1 min → `false` (Grenze inklusiv wie `suggestOpenEntryEnd`)
  - Mitternachtsfall: jetzt 00:30, Start 23:30 am Vortag → `true`, TZ-invariant; Tag **nur aus `id`**: Eintrag mit `date` = UTC-Mitternacht, das in LA auf den Vortag fiele, bleibt am `id`-Tag
  - DST-Tag (2026-10-25 Berlin / 2026-03-29): Alter über absolute Differenz, kein Tag-Rechnen mit lokalen Stunden
- [x] Impl in `open-entry.utils.ts` (pure, Konstante nur im Funktionskörper).
- [x] Mutationen: `<=` → `<`; `todayIsEmpty` ignorieren; Typfilter entfernen; Tag aus `date` statt `id`.

### Schritt 2: Dashboard-Service — Grundlagen (`_loadOk`, `todayIsEmpty`)
- [x] Tests (`dashboard.resume.spec.ts`, Teil 1): `todayIsEmpty` ist `false` beim Laden, `true` nach erfolgreichem Laden mit leerem heutigem Eintrag, `false` mit heutigem Start, `false` bei heutigem Urlaub/Krank (`type != work`), **`false` nach Lesefehler in `_initInner`** (Status `ready`, aber `_loadOk` false), `false` bei laufendem Vortag; wechselt auf `false`, sobald heute gestartet wird; nach Tageswechsel (`vi.setSystemTime` + `TodayService.refresh`) bewertet gegen den neuen Tag.
- [x] Impl: `_loadOk`-Signal (Anfang `_initInner` false, Ende `true`, `catch` false), `todayIsEmpty`-Computed.
- [x] Regression: bestehende Dashboard-Specs unverändert grün.
- [x] Mutation: `_loadOk` im `catch` nicht zurücksetzen → Fehlerfall rot.

### Schritt 3: Dashboard-Service — Pinning und `resumePastEntry`
- [x] Tests (`dashboard.resume.spec.ts`, Teil 2; Fr-Eintrag 22:00 offen im Fake-Repo, Uhr Sa 09:00, heute leer):
  - **Happy Path:** `resumePastEntry(entry, pid)` → `true`; `workEntry().id == '2026-10-02'`, `isTimerRunning`, nach sofortigem Tick `elapsedMs` = 11 h minus Pausen; `date` = lokales Datum aus der `id` (LA-Lauf: kein Vortag); `isExtraDay` und Soll vom **Starttag** (Fr Arbeitstag 8 h; zweiter Fall Sa-Start = Zusatztag, Soll 0)
  - **Saldo-Basis:** `initialOvertimeMs == gespeicherter Saldo`, auch wenn `lastUpdated == heute` (Heuristik-Falle); `totalOvertime = stored + (Netto − Soll(Fr) [+ manual])`
  - **Offene Pause** (Pause 23:00 ohne Ende): bleibt offen, Pausenzeit wächst mit der Uhr
  - **Über Mitternacht weiter:** `setSystemTime` auf den Folgetag + `TodayService.refresh` → kein Reinit, Eintrag/Timer bleiben (Regression #372), `getTodayEntry` nicht erneut aufgerufen
  - **Autosave:** nach 30 Tick-Sekunden wird der **Freitags**-Eintrag (`id` Freitag, `pid` des geladenen Profils) gespeichert, nicht Samstag
  - **Stop:** `startOrStopTimer` → Saldo `stored + Tagesanteil` im richtigen Profil, Eintrag am Freitag mit `workEnd`, danach Reinit auf heute (leerer Samstag, `initialOvertimeMs` = neuer Saldo); Schreib-Reihenfolge wie bisher
  - **Ablehnung ohne Zustandsänderung** (`false`, State/Timer/Schreib-Log/Reads unverändert, kein Ladezustand): heute schon Eintrag mit Start; heute `type == vacation`; Eintrag 24 h + 1 min alt; Typ ≠ work; `pid` ≠ geladenes/aktives Profil; Dashboard lädt noch (nach dem Warten auf den Lauf neu bewertet); vorheriger Ladefehler (`_loadOk` false)
  - **Frisch lesen:** Fake liefert den Eintrag inzwischen beendet (anderes Gerät) oder gelöscht → `false`, Dashboard zeigt heute (leer, Basis korrekt), Schreib-Log leer; Eintrag inzwischen > 24 h alt (anderer Start) → `false`
  - **Lesefehler beim Pin** (nur der Monats-Read des Pins schlägt fehl): `false`, Dashboard geladen (`_loadOk` true, `todayIsEmpty` true), kein Dauerspinner, nichts geschrieben
  - **Wartet auf Ladelauf:** `resumePastEntry` während laufendem `_init` (gehaltener Read) wartet ab und prüft danach „heute leer"; endet der Lauf mit heutigem Start, `false`
  - **Profilwechsel mitten im Pin** (gehaltener Pin-Read, Wechsel über `work-profile-fake`, Read freigeben): Ergebnis verworfen, `false`, State gehört Profil B, kein Timer aus A, Schreib-Log ohne Write
  - **Tageswechsel/Login mitten im Pin:** überholt → `false`, kein Zustand des Pins
  - **Doppelter Aufruf:** zweiter `resumePastEntry` direkt danach → `false` (heute nicht mehr leer), genau ein Timer, ein Pin-Read
  - **Service-Aufruf in der Ladelücke** (`startOrStopTimer` während des gehaltenen Pin-Reads): wartet auf den Pin, stoppt den gepinnten Lauf danach (festgeschriebene Grenze, siehe Mobile); im Template ist der Button wegen Spinner nicht erreichbar (Prüfung in Schritt 6)
  - **Folge `reloadAfterRetroClose(pid)`** mit gepinntem Vortag: nur Basis erneuert, kein `_init`, Timer läuft (Regression des bestehenden Zweigs)
  - **Profilwechsel-Guard (`stopRunningTimerForSwitch`)** mit gepinntem Vortag: stoppt und speichert im Starttag (kein Reinit, wie bisher)
  - Regression: `dashboard.service.spec.ts`, `.switch`, `.profile` unverändert grün
- [x] Impl in `dashboard.service.ts`: `pinned`-Option, `_pinnedGen`, Pin-Read mit eigenem try/catch und Fallback, `storedBase`, `date`-Normalisierung, `resumePastEntry` mit Sofort-Tick. `_ensureCurrentDay`/`_onDayChange`/Stop-Pfad/`reloadAfterRetroClose` **nicht** ändern.
- [x] Mutationen: (a) Basis ohne `storedBase` (Heuristik) → Saldo-Test rot; (b) Soll von „jetzt"/`date` statt `id`-Tag → rot (LA-Lauf); (c) 24-h-Prüfung im Service entfernen; (d) „heute leer" entfernen; (e) Frisch-Lesen-Validierung entfernen; (f) `_initGen`-Prüfung nach dem Pin-Read entfernen (Profilwechselfall); (g) Pin-Read-Fehler in den äußeren `catch` laufen lassen → Dauer-Platzhalter, rot; (h) Sofort-Tick weglassen → `elapsedMs`-Test rot.

### Schritt 4: `OpenEntryService` — `canResume`, `resume()`, Flash-Schutz, `busy`
- [x] Tests (`open-entry.spec.ts`, Dashboard-Fake mit `todayIsEmpty`/`resumePastEntry`/`workEntry`/`isLoading` als steuerbare Signals; Flush über Microtasks):
  - `canResume`: Fr offen, Sa 09:00, heute leer → `true`; > 24 h → `false` (Beenden bleibt); heute nicht leer → `false`; Dashboard lädt → `false` (`entries` leer); ältere Kandidaten nie; bezieht sich auf `current` (mehrere Kandidaten); Start heute (`todayIsEmpty` → false) blendet den Button aus, Stop heute lässt ihn aus; Uhrsprung über die 24-h-Grenze + Tageswechsel (`setSystemTime` + `refresh`) → `false`
  - `resume()` Erfolg: `resumePastEntry(entry, pid)` genau einmal mit `pid` des Kandidaten, Kandidat sofort aus `entries` entfernt, `closedCount` +1, **keine** zusätzlichen Monats-Reads, Später-Set unverändert, `busy` danach `false`
  - Frische Regelprüfung beim Tap (Uhr vorgestellt, Dashboard seitdem nicht leer): kein Aufruf des Dashboards, `false`, Banner neu bewertet
  - Ablehnung (Dashboard `false`): `busy false`, Neusuche (Lese-Log +2 Monats-Reads), Banner bleibt sichtbar bei weiter offenem Eintrag, verschwindet bei inzwischen beendetem; `canResume` neu berechnet, `saveError` bleibt `null`, `MatSnackBar`/Ansage nicht aufgerufen
  - Doppelklick: zweiter Aufruf bei `busy` → `false`, genau ein `resumePastEntry`
  - ohne Kandidat/ohne Eintrag in `_found` → `false`; nach „Später" (kein Kandidat sichtbar) → `false`
  - Profilwechsel mitten im `resume()` (gehaltenes `resumePastEntry`): kein Zustand im neuen Profil, kein `closedCount`, `busy` des neuen Profils bleibt unberührt, neuer Suchlauf für B; zusätzlich Regressionstest derselben Härtung für `endEntry` (überholter Lauf setzt `busy` von B nicht zurück)
  - **Flash-Schutz:** Pin (Dashboard-Fake setzt `workEntry` auf den Vortag) → Stop (Fake setzt `workEntry` auf heute, Folge-Read noch gehalten) → Vortag erscheint **nicht** kurz als Banner; nach dem Folge-Read bleibt er weg (Eintrag beendet). Vorheriger Tag wird nur beim Wechsel der Dashboard-Id entfernt (stiller Tageswechsel mit leerem Vortag ohne Wirkung)
  - nach Pin → Stop → nächster älterer offener Eintrag erscheint nach dem Re-Check (`current`), mit `canResume` nur wenn Regel erfüllt
- [x] Impl in `open-entry.ts`: `canResume`, `_clockTick`, `resume()`, Entfernen des Kandidaten, Flash-Schutz im Effect (vorherige Dashboard-Id merken), `busy`-Härtung (Reset nur bei gleichem Epoch, Reset im Kontextwechsel). Konstanten nie als Feldinitializer.
- [x] Mutationen: `canResume` ignoriert `todayIsEmpty`; `busy`-Guard entfernen; `epoch`-Prüfung nach dem `await` entfernen; Neusuche bei Ablehnung entfernen; Kandidat nach Erfolg nicht entfernen (Flash-Test rot); Flash-Schutz entfernen; zusätzlicher Read nach Erfolg → Read-Zähler rot; `busy`-Reset unbedingt → Härtungstest rot.

### Schritt 5: i18n
- [x] Tests zuerst in `core/i18n-open-entry.spec.ts`: Keys `openEntryContinue` und `openEntryContinueSemantics` in de/en vorhanden, nicht leer; Platzhalter `{{date}}` nur beim Semantics-Key und gleich in beiden Sprachen; den bisherigen Test „keine weiteren Keys (kein Fortsetzen, keine Semantics-Keys)" auf die erweiterte Key-Liste umstellen (Titel anpassen).
- [x] Texte (Deutsch duzend/neutral, minimal): `openEntryContinue` „Fortsetzen" / „Continue"; `openEntryContinueSemantics` „Eintrag vom {{date}} fortsetzen" / „Continue entry from {{date}}" (wie Mobile). Kein dritter Key (Ablehnung bleibt still, keine Ansage).
- [x] Der sichtbare Text („Fortsetzen"/„Continue") bleibt im Accessible Name enthalten (WCAG 2.5.3 Label in Name).

### Schritt 6: Banner + Dashboard-Einbindung
- [x] Tests zuerst:
  - `open-entry-banner.spec.ts` (`provideTranslateService`, de/en): `canResume` (Input, Default `false`, damit bestehende Specs unverändert grün) `true` → Button „Fortsetzen"/„Continue" neben „Beenden"/„Später", `false` → kein Button; Klick löst `resume` genau einmal aus; `busy` deaktiviert alle drei; `aria-label` des Fortsetzen-Buttons enthält das Datum (de/en) und ersetzt `aria-describedby` an diesem Button (kein Doppelvorlesen); Reihenfolge im DOM Später, Beenden, Fortsetzen; Icon weiter `aria-hidden`; `role="status"` weiter nur am Textblock; SCSS ohne Hex-Werte; Buttons umbrechen (`flex-wrap`) bei 320 px (Klassen-/Stil-Test wie bestehend, kein Layout-Test in jsdom)
  - `dashboard.spec.ts` (Stub `createFakeOpenEntry` erweitert): Banner bekommt `canResume`; Klick ruft `openEntry.resume(candidate)` genau einmal; kein Dialog, keine Snackbar, **kein** `LiveAnnouncer.announce` bei Fortsetzen (außer der bestehenden einmaligen Banner-Ansage); während der Fake-`resume`-Promise hängt (`busy`), sind die Buttons deaktiviert; Fokus nach Erfolg (`closedCount` +1, Dashboard rendert den Anker nach dem Spinner): Anker fokussiert bzw. nächster Banner (Microtask-/`TestBed.tick()`-Flush, kein Timeout); Dashboard bleibt bedienbar (Timer-Button erreichbar, nicht modal)
  - Ende-zu-Ende-Test (echter `DashboardService` + echter `OpenEntryService`, Fake-Repos, `createFakeOpenEntry` nicht verwenden): Banner mit Fortsetzen → Klick → Spinner → Dashboard zeigt laufenden Timer mit Starttag-Startzeit, Banner weg, Stop sichtbar; ohne Fortsetzen, wenn heute ein Eintrag existiert; Stop → Dashboard heute, Banner flackert nicht
- [x] Impl:
  - Banner: `canResume = input(false)`, `resume = output<void>()`; in `@if (canResume())` drei Buttons mit Hierarchie Später `mat-button` (Text), Beenden `mat-stroked-button`, Fortsetzen `mat-flat-button`; ohne `canResume` bleibt das heutige Aussehen (Später stroked, Beenden flat). Statisches Material-Attribut je Zweig, daher getrennte `@if`/`@else`-Zweige, keine `ngClass`. Endgültige Wahl im Review der UI.
  - Dashboard: `[canResume]="openEntry.canResume()"`, `(resume)="onResumeOpenEntry(ob.candidate)"`; `onResumeOpenEntry` ruft `openEntry.resume(...)`. Kein neuer Dialog.
- [x] Mutationen: `canResume`-Bindung entfernen; Button auch bei `busy` aktiv; `aria-label` ohne Datum.

### Schritt 7: Doku und Gesamtvalidierung
- [x] `web/CLAUDE.md`, Abschnitt „Offene Einträge vor heute (#385)": Unterabschnitt „Fortsetzen" (Regel `canResumeOpenEntry`, `todayIsEmpty`/`_loadOk`, Pinning in `_initInner`, Basis gespeicherter Saldo, `date` aus `id`, kein Write/kein `ActionCtx`, Frisch-Lesen inkl. 24 h, stille Ablehnung mit Neusuche, Flash-Schutz, `busy`-Härtung); in „Grenzen" „Fortsetzen folgt mit Mobile PR 1b" ersetzen (Fortsetzen nur für den neuesten Eintrag, nur bei leerem heutigem Tag und ≤ 24 h, stiller Fehlschlag, Service-Aufruf in der Ladelücke stoppt den gepinnten Lauf); in „Tageswechsel (#372)" ein Satz, dass ein laufender Vortag auch über „Fortsetzen" ins Dashboard kommt; Layer-Tabelle (Banner-Beschreibung, `OpenEntryService`).
- [x] Vollläufe aus `web/`: `TZ=Europe/Berlin npm test -- --watch=false`, dann `UTC`, `America/Los_Angeles`, `Pacific/Auckland`; mehrfach Vollauf auf Flakes (Vite-SSR-Falle, Fake-Timer).
- [x] `npm run build -- --configuration production`.
- [x] Mutationstabellen der Schritte 1–4 und 6 abgearbeitet, Ergebnis in `web/thoughts/385-pr-fortsetzen.md`.
- [ ] Manuelle Prüfung (Liste unten) nur, soweit lokal möglich; Rest in den PR-Body.

## PR-Zuschnitt
Ein PR gegen `develop`, Commits je Schicht: (1) Utils, (2) Dashboard-Service (`todayIsEmpty` + Pinning), (3) `OpenEntryService`, (4) i18n, (5) UI, (6) Doku. Größe M, kein Split nötig. PR-Text: Parität zu Mobile #422, Abweichungen (Pin-Lesefehler fällt auf heute zurück statt `_loadOk=false`; 24-h-Re-Check am frischen Eintrag; `busy`-Härtung auch für Beenden; Flash-Schutz), keine API-/Deploy-Abhängigkeit, Grenzen.

## Manuelle Prüfliste (PR-Body)
- [ ] Mitternachtslauf: Timer vor Mitternacht, Tab zu, nach Mitternacht öffnen → Banner mit „Fortsetzen"; klicken → Timer läuft ab dem Starttag-Beginn, Saldo/Soll stimmen (Soll Starttag), über weitere Mitternacht kein Reinit; Stop → Eintrag am Starttag, Dashboard leer auf heute
- [ ] Heute schon gestartet / Urlaub eingetragen → kein „Fortsetzen", „Beenden" bleibt; Eintrag älter als 24 h → nur „Beenden"/„Später"
- [ ] Zweiter Tab/Gerät beendet den Eintrag, dann Fortsetzen → nichts passiert, Banner verschwindet
- [ ] Profilwechsel mitten im Pin (Throttling im DevTools); Offline: Fortsetzen scheitert still, Dashboard zeigt heute
- [ ] Tastatur und Screenreader: Reihenfolge, Name „Eintrag vom … fortsetzen", Fokus danach auf dem Timer-Bereich; axe, 320 px, 200 % Zoom, Hell/Dunkel, de/en

## Risiken
| Risiko | Umgang |
|---|---|
| Race-sensibler `DashboardService` (#372/#380) | Eine neue Methode + optionaler `pinned`-Parameter; Prüfung und `_init` ohne `await`; alle bestehenden Dashboard-Specs als Regression |
| Ladefehler sieht wie „heute leer" aus | `_loadOk`-Signal; Test + Mutation |
| Zwei laufende Einträge (Start heute parallel zum Pin) | Spinner während Pin (Buttons nicht erreichbar), `todayIsEmpty` vor `_init` ohne `await`, Test „Service-Aufruf in der Ladelücke" legt Verhalten fest |
| Falsches Soll/`isExtraDay` westlich von UTC | `date` aus `id`, LA-Lauf, Mutation (b) |
| Saldo falsch durch `lastUpdated`-Heuristik | `storedBase`, Test mit `lastUpdated == heute`, Mutation (a) |
| Banner flackert nach Stop | Flash-Schutz, Test + Mutation |
| Veralteter Button (24 h läuft ab, Tab offen) | Re-Check beim Tap, bei Ablehnung Neusuche + Uhr-Signal; kein Timer (Grenze dokumentiert) |
| Flakes im Vollauf | Test-Rahmen (keine Timeouts, Literale statt importierter Feldinitializer, 4 Zonen) |

## Offene Fragen
Keine blockierenden. Zur Kenntnis (Plan-Defaults, bei Einwand bitte melden):
1. Dashboard zeigt während des Pins den Spinner (Mobile: `isLoading`); Alternative ohne Spinner wäre ein Race mit Start-Tap, daher nicht gewählt.
2. Härtung `busy` auch für `endEntry` (kleine Änderung am bestehenden Pfad, mit Regressionstest) ist Teil dieses PR.
3. Button-Hierarchie (Später Text, Beenden stroked, Fortsetzen flat) nur bei `canResume`, sonst Aussehen unverändert.
