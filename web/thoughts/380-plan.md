# Web-Plan: #380 — PR 1 (Stufe 1, Datenintegrität): Dashboard bei Profilwechsel
Erstellt: 2026-10-04
Research: web/thoughts/380-research.md (inkl. „Entscheidungen zu den offenen Fragen")
Referenz: web/thoughts/372-plan.md, 372-pr.md, `features/dashboard/dashboard.service.ts` (`_initGen`/`_initRun`, `_ensureCurrentDay`, `TodayService`)
UI-Report: entfällt (kein UI, keine neuen Texte). **Stufe 2 (Dialog, Guard-Hook, i18n-Keys) ist NICHT Teil dieses Plans (PR 2).**

## Ziel
Ein Profilwechsel (Header-Wechsler, Reload mit gemerktem Profil, `addProfile()`, `deleteProfile(active)`) lädt das Dashboard
vollständig für das neue Profil neu, und kein Schreibvorgang landet je im falschen Profil. Ein laufender Timer wird „eingefroren"
(wie Mobile): im Dashboard gestoppt, nichts ins neue Profil geschrieben, Eintrag bleibt im alten Profil laufend und läuft beim
Zurückwechseln weiter. `SettingsPageService` (Saldo-Anzeige/-Schreiben) hängt am Profil.

## Befunde aus dem Code (verändern den Plan gegenüber der Research)
- `ApiClient.saveWorkEntry/saveOvertimeMs/getOvertimeMs/getOvertimeLastUpdate` nehmen `profileId?` **bereits** als Parameter
  -> **keine Änderung an `api-client.ts`**; die Erweiterung liegt nur in `WorkEntryService`/`OvertimeService`.
- Alle Dashboard-Specs injizieren heute **kein** `WorkProfileService`; sobald `DashboardService` ihn injiziert, würde der echte
  (mit `ProfileService`/`ApiClient`) gezogen. Alle `create()`-Helper in `dashboard.service.spec.ts` und der Provider-Block in
  `settings.service.spec.ts` brauchen deshalb einen Profil-Fake (Schritt 0).
- `tsconfig.app.json` kompiliert alle Nicht-Spec-`.ts` unter `src/` mit `types: []`: ein gemeinsamer Test-Helper darf **kein `vi`**
  und keine Vitest-Importe enthalten (nur `signal`, `ReplaySubject`, Plain-TS).
- Der Wert-Parameter ist eine **Profil-ID** (`'default'` oder ID), nicht die API-Form (`undefined` für Standard), sonst wäre
  „nicht übergeben" nicht von „Standard" unterscheidbar. Umrechnung in die API-Form über eine reine Util-Funktion.

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Hybrid-Service nötig? | nein (bestehende erweitert) | `WorkEntryService.saveEntry(entry, profileId?)`, `OvertimeService.saveOvertime(ms, profileId?)`; zusätzlich Lese-Argumente `getTodayEntry(profileId?)`, `getOvertime(profileId?)`, `getLastUpdateDate(profileId?)` (siehe unten, Abweichung von der Minimal-Vorgabe) |
| Rückwärtskompatibilität | `profileId` optional, `undefined` = aktives Profil zum Aufrufzeitpunkt (heutiges Verhalten) | Aufrufer `ReportsService`, `DataSyncService`, Reports-Komponente, EditEntryDialog bleiben unverändert; ein Test sichert „ohne Argument = aktives Profil" |
| Umrechnung ID -> API | neue pure Funktion `profileIdForApi(id)` in `shared/utils/work-profile-path.util.ts` (`'default'` -> `undefined`) | Kein neues Methoden-Mock-Erfordernis in fremden Specs (kein neuer `WorkProfileService`-Member) |
| Anonym (kein uid) | `profileId` wird ignoriert (localStorage kennt nur Standard) | unverändert |
| Trigger | `workProfile.activeProfileId$.pipe(distinctUntilChanged(), takeUntilDestroyed)` -> `_onProfileChange(id)`; **kein** Signal-`effect` | `toObservable` hinkt dem Signal hinterher; aus dem Observable abgeleitet ist der Replay von `getTodayEntry()` beim Abonnieren garantiert neu (Research 6) |
| Idempotenz | `_onProfileChange(id)`: `id === _loadedProfileId` -> nichts; sonst `_init(uid, {})` (**ohne** `dayChange`, mit Lade-Zustand) | Erste Replay-Emission beim Start und Doppel-Auslöser (Auth-Effect + Profil) erzeugen keinen zweiten Lauf; `_initGen` verwirft Überholer |
| Geladenes Profil | neues Feld `_loadedProfileId` (Start `DEFAULT_WORK_PROFILE_ID`), in `_initInner` **synchron direkt nach `++_initGen`** aus `workProfile.activeProfileId()` gesetzt | Das neueste `_init` gewinnt; zwischen Signal-Wechsel und Observable-Emission bleibt `_loadedProfileId` = altes Profil, also schreibt ein Autosave in diesem Fenster **explizit ins alte** Profil (korrekt, nie ins neue) |
| Explizite Lese-Argumente in `_init` | `getTodayEntry(pid)`, `getOvertime(pid)`, `getLastUpdateDate(pid)` mit demselben `pid`; `getSettings()` bleibt reaktiv | Verhindert „Eintrag A + Saldo B" auch bei Auth-getriggertem `_init` im Lag-Fenster. Settings heilen sich über die bestehende reaktive Subscription (Cache + `_recalculateOvertime`); Test 7 deckt den Endzustand ab |
| Schreib-Isolation | Pro Aktion **einmal** `const pid = this._loadedProfileId; const gen = this._initGen;` **nach** `_ensureCurrentDay()`, an `_recalculateState(entry, save, ctx)`, `_saveOvertime(ctx, ms)`, `_autoSave` weitergereicht; alle Writes mit explizitem `pid` | Mobile-Pendant: Profil an Repo gebunden |
| Werte vor `await` einfrieren | `totalOvertimeMs` wird **synchron vor** dem ersten `await` in einer lokalen Variable festgehalten und an `_saveOvertime` übergeben (nicht nach dem `await` aus `_s()` gelesen) | Sonst läse der Saldo-Write nach dem Wechsel den Zustand des neuen Profils |
| Prüfung nach jedem `await` | `ctx.gen !== this._initGen` (= Profil/Reinit überholt) -> **keine zustandsändernden Folgeschritte** (`_startTimerIfNeeded`, Reinit nach Stop, `_s`-Updates). Die **Writes derselben Aktion** (Eintrag, dann Saldo) werden mit den festgehaltenen Werten **vollständig ins festgehaltene Profil** durchgeführt | Abbruch zwischen Eintrag und Saldo ließe das alte Profil inkonsistent (Stop gespeichert, Saldo nicht). Falls die Hauptsession „Abbrechen statt Abschließen" will, ändert sich nur Erwartung Test 5 |
| Überholte `_init`-Läufe | unverändert (`gen`-Prüfung nach jedem `await`), zusätzlich: Reads nutzen `pid` | Zählerlogik aus #372 bleibt |
| Timer „einfrieren" | `_init` stoppt den Timer ohnehin zuerst (synchron); kein Save beim Wechsel; Eintrag bleibt im alten Profil laufend | Option (d) / Mobile |
| `deleteProfile(active)` / `addProfile()` | kein Sonderpfad im `WorkProfileService`: beides geht durch `setActiveProfile` -> Observable -> Reinit. Gelöschter Eintrag wird nicht gespeichert (Timer verworfen) | Entscheidung 4 der Hauptsession. **Restfenster:** zwischen `await api.deleteWorkProfile` und `setActiveProfile` kann ein Autosave (30 s) den Eintrag in das gerade gelöschte Profil zurückschreiben; akzeptiert, in PR-Beschreibung nennen |
| `_ensureCurrentDay()` | unverändert, ruft `_init` mit `dayChange:true` (nimmt `pid` aus Signal); zusätzlich Guard: `_loadedProfileId !== activeProfileId()` -> auf laufenden `_initRun` warten, dann Aktion abbrechen falls weiter ungleich | Analog Tag-Guard (Research 10) |
| `updateInitialOvertime(ms, profileId?)` | ohne Argument: `pid = _loadedProfileId`. Mit Argument (Settings-Seite übergibt das Profil, dessen Saldo der User sah): schreibt dorthin; `_s` (Basis/Total) nur aktualisieren, wenn dieses Profil == `_loadedProfileId` und `gen` unverändert | Schließt Settings-Dashboard-Lag-Fenster; schreibt nie den Wert des einen in das andere Profil. Interpretation von Test 11: „geladenes Profil bzw. das übergebene" |
| `SettingsPageService` | Overtime-Effect liest zusätzlich `workProfile.activeProfileId()`; `_loadOvertime` übergibt diese ID an `getOvertime`/`getLastUpdateDate` und verwirft überholte Antworten (Zähler); `_overtimeProfileId` merkt das angezeigte Profil, `setOvertime` reicht es an `updateInitialOvertime` | Research 7 / Entscheidung 5 |
| Neuer Domain-Service | nein | |
| Premium-Gate / Routing / API-Endpunkt / Firestore-Pfad / Rules | nein | `?profileId=` existiert an allen Endpunkten |
| Neue Texte | **nein** | Stufe 1 braucht keine Keys (Lade-Spinner wie Auth-Reinit) |
| Shared Component | nein | |
| Nebenbefund 5.4 (`_recalculateOvertime` ohne `workEnd`-Prüfung) | **nicht in PR 1**; in Schritt 2 nur ein Bestätigungstest (Charakterisierung, `it.fails` o. Ä. nicht committen, Ergebnis an Hauptsession melden) | Entscheidung 6 |

## Neue / geänderte Dateien

### Shared Layer
```
web/src/app/shared/utils/
├── work-profile-path.util.ts        # GEÄNDERT: + profileIdForApi(id): string | undefined
└── work-profile-path.util.spec.ts   # GEÄNDERT bzw. NEU falls nicht vorhanden
web/src/app/shared/testing/
└── work-profile-fake.ts             # NEU: Test-Helper OHNE vi/Vitest-Import (wird von tsconfig.app mitkompiliert)
```
`createFakeWorkProfile(initial = 'default')` liefert `{ activeProfileId: Signal, activeProfileId$: Observable, activeProfileIdForApi, setSignalOnly(id), emitObservable(id), set(id) /* beides, Signal zuerst */ , setActiveProfile(id) }`. `setSignalOnly`/`emitObservable` getrennt = stellt das Hinterherhinken nach. Das Observable ist ein `ReplaySubject(1)` (wie `toObservable`).

### Core Layer
```
web/src/app/core/services/
├── work-entry.ts          # GEÄNDERT: saveEntry(entry, profileId?), getTodayEntry(profileId?)
├── work-entry.spec.ts     # NEU (nur Profilargument-Tests; Firestore/ApiClient/Auth/WorkProfile als Fakes)
├── overtime.ts            # GEÄNDERT: getOvertime/getLastUpdateDate/saveOvertime mit profileId?
└── overtime.spec.ts       # NEU
```
Unverändert: `api-client.ts`, `work-profile.ts` (Logik), `settings.ts`, `leave-balance.ts`.
`getTodayEntry(profileId?)`: ohne Argument wie heute (`combineLatest` mit `activeProfileId$`); mit Argument `auth.user$` + festes Profil (keine Abhängigkeit vom Replay).

### Feature Layer
```
web/src/app/features/dashboard/
├── dashboard.service.ts           # GEÄNDERT (Trigger, _loadedProfileId, Kontext-Weitergabe, explizite Reads/Writes)
├── dashboard.service.spec.ts      # GEÄNDERT: Profil-Fake in allen create()-Helpern (Schritt 0)
└── dashboard.profile.spec.ts      # NEU: Fake-basierte Fälle 1-11 (+ Zusatzfälle)
web/src/app/features/dashboard/dashboard.profile.real.spec.ts   # NEU: Fälle mit ECHTEM WorkProfileService (Reload, Lag, add/delete)
web/src/app/features/settings/
├── settings.service.ts            # GEÄNDERT
└── settings.service.spec.ts       # GEÄNDERT: Profil-Fake in Providern + neue Fälle
```
`dashboard.ts/.html/.scss` und `dashboard.spec.ts` unverändert (Fake-Service).

### Doku
```
web/CLAUDE.md   # GEÄNDERT:
                #  - core/services-Baum: work-entry.ts / overtime.ts: "optionales profileId-Argument bei Writes/Reads (#380)"
                #  - shared/utils-Baum: work-profile-path.util.ts + profileIdForApi (Zeile ergänzen)
                #  - Tabelle Feature-Services: DashboardService + WorkProfileService; SettingsPageService + WorkProfileService
                #  - neuer Kurzabschnitt "Profilwechsel (#380)" nach "Tageswechsel (#372)":
                #    Trigger aus activeProfileId$ (nicht Signal-Effect), _loadedProfileId, Profil pro Aktion festgehalten
                #    und explizit an saveEntry/saveOvertime, Timer wird eingefroren (kein Save ins neue Profil),
                #    Rückwechsel setzt fort; Stufe 2 (Dialog) folgt in eigenem PR
```

## Test-Konventionen (alle Schritte)
- `vi.useFakeTimers()` + `vi.setSystemTime(new Date(2026, 9, 3, 12, 0))` (lokale Konstruktoren), `advanceTimersByTimeAsync`; Dauern aus Differenzen, nie hart kodierte UTC-/ISO-Strings; Soll über feste Settings (`[1..5]`, 40 h; Profil B z. B. `[1,2,3]`, 24 h). Samstag-Fixdatum 2026-10-03 aus #372 genügt nicht für Soll > 0 -> für Soll-Fälle Mo 2026-10-05 12:00 nutzen (Konstante im Spec, lokal gebaut).
- Profil-Fakes: Fake-`WorkEntryService`/`OvertimeService`/`SettingsService`, die **je Profil-ID** unterschiedliche Daten liefern (A/Standard: Saldo 120 min, B: 30 min; B mit eigenem Eintrag 08:00-12:00) und **jeden Write mit Profil-Argument protokollieren** (`calls: { profileId, entry|ms }[]`). Manuell auflösbare Promises (`deferred()`) für In-flight-Fälle.
- Zwei Spec-Typen: (a) Fakes mit getrennt steuerbarem Signal/Observable (`setSignalOnly` vs. `emitObservable`), (b) **echter `WorkProfileService`** (+ Fake-`AuthService` mit steuerbarem `user`-Signal und `uid`, Fake-`ProfileService`, Fake-`ApiClient`), `TestBed.flushEffects()`.
- Aufräumen: `TestBed.resetTestingModule()`, danach `vi.getTimerCount()` = 0, `localStorage.clear()` in `beforeEach/afterEach`, Subscription auf `activeProfileId$` per `takeUntilDestroyed` (Test: nach Reset löst `emitObservable` keinen Fake-Aufruf mehr aus).
- Läufe aus `web/`: `npm test -- --watch=false` unter `TZ=Europe/Berlin` (CI) sowie lokal `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland`, `TZ=UTC`. Keine TZ-Annahme im Spec/Code, kein `process.env.TZ` im Spec.
- Rot-Nachweis: vor jeder Impl-Änderung Test laufen lassen, **rote Fälle mit Fehlermeldung notieren** (in `380-pr.md`); danach grün.

## Implementierungsschritte (TDD-First, Layer-Reihenfolge)

### Schritt 0: Baseline + Profil-Fake in Bestandstests (alles grün, kein Fix)
- [x] `shared/testing/work-profile-fake.ts` anlegen (ohne `vi`), Test-Selbstprüfung nicht nötig, wird in Schritt 1/2 durch Nutzung geprüft.
- [x] In `dashboard.service.spec.ts` (alle `create()`/Provider-Blöcke, Z. 21-44 und ~238-254) `{ provide: WorkProfileService, useValue: fake }` ergänzen; `settings.service.spec.ts` (beide Provider-Blöcke) ebenso. **Erst nach Schritt 2 sind sie zwingend**, aber hier schon, damit Schritt 2 den Bestand nicht bricht.
- [x] Baseline in 4 Zeitzonen = grün (Ausgangsstand notieren).

### Schritt 1: Shared-Util + Core-Services (`profileId` explizit, abwärtskompatibel)
Tests zuerst:
- [x] `profileIdForApi`: `'default'` -> `undefined`, `'abc'` -> `'abc'`, `''`-Verhalten dokumentieren (wie `profileScopedPath`).
- [x] `overtime.spec.ts` (Auth-Fake mit `uid`, ApiClient-Fake `vi.fn()`, WorkProfile-Fake aktiv = B):
  - ROT: `saveOvertime(ms, 'A')` ruft `api.saveOvertimeMs(ms, 'A')`; `saveOvertime(ms, 'default')` -> `(ms, undefined)` (aktiv ist B, wird ignoriert).
  - ROT: `getOvertime('A')`/`getLastUpdateDate('A')` analog.
  - GRÜN (Kompatibilität, vor und nach Fix): ohne Argument -> `activeProfileIdForApi` (= B).
  - Anonym (uid null): Argument ignoriert, localStorage-Pfad unverändert.
- [x] `work-entry.spec.ts` (Firestore-Fake `{}`, ApiClient-Fake):
  - ROT: `saveEntry(e, 'A')` -> `api.saveWorkEntry(e, 'A')` bei aktivem B; `'default'` -> `undefined`.
  - GRÜN: ohne Argument -> aktives Profil. Anonym: `_localSave`, Argument ignoriert.
  - ROT: `getTodayEntry('A')` greift auf Pfad `users/{uid}/profiles/A/work_entries/...` zu, **unabhängig** vom Wert des `activeProfileId$`-Fakes (Firestore-Fake `doc`-Pfad prüfen, Muster der Reports-Tests).
- [x] Impl: Util, `saveEntry`, `getTodayEntry`, `getOvertime`, `getLastUpdateDate`, `saveOvertime` (`saveLastUpdateDate` bleibt: eingeloggt No-op, anonym Standard-localStorage). Keine Änderung an `deleteEntry`/`getEntriesForMonth`.
- [x] Gesamtlauf grün (Reports/Data-Sync-Specs unverändert grün = Kompatibilitätsbeleg).

### Schritt 2: Dashboard-Reinit bei Profilwechsel (Trigger + Laden)
Tests zuerst (`dashboard.profile.spec.ts`, Fake-Profil; **alle ROT vor Fix**):
- [x] **Fall 8 (Reload-Race, erster roter Test, echtes `WorkProfileService`, in `dashboard.profile.real.spec.ts`)**: `localStorage['active_work_profile_<uid>'] = 'B'`, `user` auf `{uid}` setzen, `flushEffects`, `advanceTimersByTimeAsync`: `workEntry()` = B-Eintrag, Saldo-Basis = B (30 min), Soll aus B-Settings; **kein** gemischter Zustand (Fake protokolliert, dass jeder Read B nutzte oder der Endzustand reiner B-Stand ist); Variante mit vertauschter Provider-/Effect-Reihenfolge (Dashboard zuerst injizieren / `WorkProfileService` zuerst).
- [x] **Fall 7 (Lag)**: Fake-Profil `setSignalOnly('B')` -> `flush` -> `emitObservable('B')`: `_init` lädt nie „Eintrag A + Saldo B" (Fake wirft/protokolliert gemischte Reads); Endzustand = B. Zusätzlich mit echtem `WorkProfileService` + `TestBed.flushEffects()`.
- [x] **Fall 9 (Wechsel ohne Timer, Eintrag/Saldo/Soll)**: A stoppt-Eintrag/leer; Wechsel auf B: `workEntry()` = B-Eintrag, `breaks()` aus B, Basis/Total aus B-Saldo (120 -> 30 min), Soll/`isExtraDay` aus B-Settings (`workdays`/`weeklyTargetHours` je Profil verschieden), `isLoading()` zwischenzeitlich true.
- [x] **Fall 10 (Tageswechsel-Interaktion)**: Profilwechsel um 23:59:50 + Mitternacht: genau ein gültiger Endzustand; Profilwechsel nutzt `lastUpdated`-Heuristik (kein `dayChange`-Pfad: Basis nicht blind `stored`), Tageswechsel-Reinit danach nutzt `dayChange`.
- [x] **Fall 6 (überholter Lauf)**: A -> B -> A schnell, `getTodayEntry(B)`/`getOvertime(B)` mit `deferred()` verzögert, danach auflösen: Endzustand = A, `vi.getTimerCount()` zeigt nur A-Timer (falls A läuft), B-Timer nie gestartet, `status` ready genau einmal.
- [x] **Fall 3 (Rückwechsel setzt fort)**: Timer in A läuft (Fake-A-Eintrag `workStart` ohne `workEnd`), Wechsel auf B (`isTimerRunning()` entspricht B, `vi.getTimerCount()` = 0 wenn B nicht läuft), Zurück auf A: `isTimerRunning()` true, Daily/Total wachsen, Timer-Anzahl 1; `workEnd` von A blieb unverändert `undefined` (kein Save beim Wechsel).
- [x] Idempotenz GRÜN-Test: erste Replay-Emission mit Profil = geladenem Profil löst **kein** zweites `getTodayEntry` aus (Aufrufzähler = 1).
- [x] Charakterisierung Nebenbefund 5.4 (nicht committen, Ergebnis melden): Settings-Emission bei **gestopptem** Eintrag ändert `dailyOvertime`? Befund in `380-pr.md`.
- [x] Impl: Feld `_loadedProfileId`, `inject(WorkProfileService)`, Subscription `activeProfileId$` + `distinctUntilChanged` + `takeUntilDestroyed` im Constructor, `_onProfileChange`, `_initInner` setzt `_loadedProfileId` nach `++_initGen` und nutzt `pid` für `getTodayEntry(pid)`/`getOvertime(pid)`/`getLastUpdateDate(pid)`; `_init(uid, opts)` bleibt Signatur-kompatibel (`opts.dayChange`).
- [x] Mutationsprüfung: Trigger entfernen -> Fälle 3/6/7/8/9/10 rot; `pid`-Argumente der Reads entfernen -> Fälle 7/8 rot; Generationsprüfung entfernen -> Fall 6 rot.

### Schritt 3: Schreib-Isolation (Autosave, Aktionen, Stop, In-flight, `updateInitialOvertime`)
Tests zuerst (**ROT vor Fix**, außer markiert):
- [x] **Fall 1 (Autosave nie ins neue Profil)**: Timer in A läuft, Wechsel auf B (Signal + Observable, flush), `advanceTimersByTimeAsync(31_000)`: kein `saveEntry`-Aufruf mit Profil `B` (Fake protokolliert Profil-Argument), insgesamt **keine** Writes; Variante im Lag-Fenster (`setSignalOnly('B')`, 31 s weiter ohne Observable-Emission): Autosave schreibt **mit `profileId = A`** (nie B).
- [x] **Fall 2 (Zustand nach Wechsel)**: `workEntry()`/`isTimerRunning()`/Timerzahl entsprechen B (Überschneidung mit Schritt 2, hier mit laufendem A-Timer als Ausgangslage).
- [x] **Fall 4 (Stop nach Wechsel)**: im Lag-Fenster (`setSignalOnly('B')`) Stop-Klick (`startOrStopTimer()`): `saveEntry(..., 'A')` und `saveOvertime(A-Saldo, 'A')`, **nie** `'B'`; nach `flush` + Reinit: B-Saldo unverändert (Fake-B-Saldo = 30 min bleibt).
- [x] **Fall 5 (In-flight Race)**: `saveEntry` über `deferred()` hängen lassen, während des Wartens Profil auf B wechseln (Signal + Observable), dann `saveEntry` auflösen: `saveOvertime` wird mit Profil `A` und dem **vor dem `await`** festgehaltenen A-Saldo aufgerufen (nie `B`, nie B-Zustandswert); danach **kein** `_startTimerIfNeeded`/`_s`-Update (B-Zustand bleibt unverändert, `vi.getTimerCount()` nur B). Gleiches für Stop-Pfad (`await _recalculateState` -> `_saveOvertime`) und Pause-/Start-Pfad (`startOrStopBreak`, `startNewSession`, `clearEndTime` mit Folge-`_startTimerIfNeeded`: kein Timer-Start nach Überholung).
- [x] **Fall 11 (`updateInitialOvertime`)**: nach Wechsel A -> B (geladen B): `updateInitialOvertime(ms)` ohne Argument schreibt `(ms, 'B')` nur für B-Basis; mit Argument `'A'` (Settings sah A): schreibt `(ms, 'A')`, `_s` (B) unverändert; während **in-flight** Wechsel wird nie ein A-Wert unter B geschrieben.
- [x] Defensivtests (`it.each` über alle Aktionen: `startOrStopTimer`, `startNewSession`, `startOrStopBreak`, `setManualStartTime`, `setManualEndTime`, `clearEndTime`, `updateBreak`, `deleteBreak`): Alle Writes tragen `profileId === _loadedProfileId` zum Aktionsbeginn (Spy-Assert auf Argument), auch wenn das Profil während der Aktion wechselt. **GRÜN-nach-Fix**, ROT vor Fix (Argument fehlt).
- [x] `_ensureCurrentDay`-Guard: `_loadedProfileId !== activeProfileId()` (Lag-Fenster) -> wartet auf Reinit, Aktion läuft danach auf B bzw. bricht ab; kein Write mit Eintrag A unter B.
- [x] Bestehende #372-Tests (Aktionen-Guard, Autosave nach Reinit, Tageswechsel) grün lassen: Fake-Profil bleibt `default`, erwartete `saveEntry`-Aufrufe jetzt mit zweitem Argument `'default'`; Assertions dort von `toHaveBeenCalledWith(entry)` auf `(entry, 'default')` anpassen (reiner Mechanikschritt, vorher notieren, welche Specs betroffen sind).
- [x] Impl: Kontext (`pid`, `gen`) pro Aktion; `_recalculateState(entry, save, ctx?)` friert `totalOvertimeMs`-Wert vor dem ersten `await` ein; `_saveOvertime(pid, ms)` mit explizitem Profil und ohne Lesen aus `_s()` nach `await`; `_autoSave` mit `pid = _loadedProfileId` und `gen`; Prüfung `ctx.gen !== _initGen` vor `_startTimerIfNeeded`/Reinit-nach-Stop; `updateInitialOvertime(ms, profileId?)`.
- [x] Mutationsprüfung: `pid`-Argument bei `saveEntry` entfernen -> Fälle 1/4 rot; Wert-Einfrieren entfernen -> Fall 5 rot; `gen`-Prüfung vor `_startTimerIfNeeded` entfernen -> Variante Fall 5 rot.

### Schritt 4: `addProfile` / `deleteProfile` (Echt-`WorkProfileService`, `dashboard.profile.real.spec.ts`)
Tests zuerst (**ROT vor Fix**; Fake-`ApiClient`: `addWorkProfile` -> `{id:'B'}`, `getWorkProfiles`, `deleteWorkProfile`):
- [x] **Fall 9a `addProfile()` mit laufendem Timer in A**: `await workProfile.addProfile('B')`, `advanceTimersByTimeAsync(31_000)`: Dashboard lädt B (leer), **kein** Write des A-Eintrags unter `B`; A-Eintrag bleibt laufend (kein Write überhaupt).
- [x] **Fall 9b `deleteProfile(active)` mit laufendem Timer**: aktives B läuft, `await deleteProfile('B')` -> aktiv `default`: Timer verworfen (`vi.getTimerCount()` = 0 bis default-Eintrag läuft), **kein** `saveEntry`/`saveOvertime` mit B-Eintrag unter `default`; das Restfenster (Autosave zwischen API-Delete und Wechsel) wird als Kommentar im Test dokumentiert, nicht abgesichert.
- [x] Logout (`user.set(null)`): `default`, Timer gestoppt, kein Write (GRÜN-Regression).
- [x] Impl: keine neue Logik (Trigger aus Schritt 2 genügt); nur Test-Verdrahtung. Falls rot: Ursache in `_onProfileChange`/Reihenfolge klären, nicht im `WorkProfileService` patchen.

### Schritt 5: `SettingsPageService` ans Profil koppeln
Tests zuerst (**ROT vor Fix**, `settings.service.spec.ts`, Profil-Fake steuerbar, `OvertimeService`-Fake je Profil):
- [x] Nach Wechsel A -> B zeigt `overtimeMs()`/`lastOvertimeUpdate()` den Wert von B (heute: bleibt A).
- [x] Überholte Antwort: A -> B schnell, A-Antwort via `deferred()` zuletzt: Anzeige bleibt B.
- [x] `getOvertime`/`getLastUpdateDate` werden mit explizitem Profil aufgerufen (Argument-Assert).
- [x] `setOvertime(ms)` reicht das **angezeigte** Profil an `dashboardSvc.updateInitialOvertime(ms, profileId)` durch (Fake-Dashboard `vi.fn()`), auch wenn das Profil gerade gewechselt wurde (Lag).
- [x] Bestandstests (Settings-Setter) grün: `DashboardService`-Fake bleibt `{}`/mit `updateInitialOvertime`.
- [x] Impl: `inject(WorkProfileService)`, Effect liest `activeProfileId()` (untracked für den async Teil), `_overtimeGen`, `_overtimeProfileId`, `setOvertime`.

### Schritt 6: Doku + Gesamtlauf
- [x] `web/CLAUDE.md` wie oben.
- [x] `npm test -- --watch=false` unter `TZ=Europe/Berlin`, `America/Los_Angeles`, `Pacific/Auckland`, `UTC`; `npm run build -- --configuration production` (prüft, dass der Test-Helper ohne `vi` baut). Aus `web/`.
- [ ] Manuelle Browser-Verifikation (nicht automatisierbar, Research 9): Timer in Standard, B mit Heute-Eintrag, wechseln, 30 s warten, Network-Tab: kein `PUT ...?profileId=B`; Zurückwechseln: Timer läuft weiter; Reload mit B; `addProfile`/Löschen mit Timer.
- [ ] `380-pr.md`: rote Fälle vor Fix (Fehlermeldungen), Nebenbefund 5.4, Hinweis „bereits verfälschte Daten werden nicht repariert", Restfenster `deleteProfile`.
- [ ] Commit/PR übernimmt die Hauptsession (`Closes`-Teil 1 von #380, **nicht** `Closes #380`); kein Commit durch den Planer.

## Zuordnung der roten Fälle (Nummern nach Research Abschnitt 13) -> Schritt
| # | Fall | Schritt | Spec |
|---|---|---|---|
| 1 | Autosave nach Wechsel nie unter B | 3 | dashboard.profile |
| 2 | `workEntry()`/Timer = B nach Wechsel | 2/3 | dashboard.profile |
| 3 | Basis/Total aus B-Saldo (+ Rückwechsel setzt Timer fort) | 2 | dashboard.profile |
| 4 | Soll/`workdays` aus B-Settings (+ Stop nach Wechsel schreibt nie A-Saldo nach B) | 2/3 | dashboard.profile |
| 5 | In-flight `saveOvertime` im Netzwerkfenster | 3 | dashboard.profile |
| 6 | Überholter Lauf A -> B -> A | 2 | dashboard.profile |
| 7 | Lag: nie „Eintrag A + Saldo B" | 2 | dashboard.profile + real |
| 8 | Reload mit gemerktem Zweitprofil (erster roter Test) | 2 | real |
| 9 | `addProfile()` wechselt automatisch / `deleteProfile(active)` verwirft Timer | 4 | real |
| 10 | Tageswechsel-Interaktion, `dayChange` nur bei Tageswechsel | 2 | dashboard.profile |
| 11 | `updateInitialOvertime` nach Wechsel | 3 | dashboard.profile |
Zusätzlich rot/neu: Core-Argument-Tests (Schritt 1), Settings-Seite (Schritt 5), Wechsel ohne Timer lädt Eintrag/Saldo/Soll (Schritt 2).

## Signal-/Ablauf-Design (Skizze, kein Code)
- `DashboardService`: `_loadedProfileId: string`; Subscription `activeProfileId$ -> distinctUntilChanged -> _onProfileChange`; `_initInner`: `gen = ++_initGen` -> `_stopTimer()` -> `_loadedProfileId = activeProfileId()` -> `_s.set(initialState())` -> Reads mit `pid`.
- Aktion: `ensureCurrentDay` -> `ctx = { pid: _loadedProfileId, gen: _initGen }` -> State sync -> Writes mit `ctx.pid` und eingefrorenen Werten -> Folgeschritte nur wenn `ctx.gen === _initGen`.
- Kein neuer öffentlicher Signal-Typ; `updateInitialOvertime` bekommt optionalen zweiten Parameter.

## Risiken
- Doppel-Reinit beim Start/Reload (Auth + Profil): durch `_loadedProfileId`-Vergleich und `_initGen` unschädlich; Lade-Flackern akzeptiert (Research 15).
- `getSettings()` bleibt reaktiv/Replay-basiert: in extremen Lag-Fenstern kurz Settings des alten Profils im Cache, bis die Subscription nachzieht (Test 7 prüft Endzustand).
- Bereits verfälschte Daten werden nicht repariert (PR-Hinweis).
- Restfenster `deleteProfile` (siehe Tabelle).

## Offene Fragen an die Hauptsession
- O1: Zusätzliche optionale Lese-Argumente (`getTodayEntry`/`getOvertime`/`getLastUpdateDate`) sind **über die genannten Schreib-Argumente hinaus** geplant (verhindern gemischte Reads auch bei Auth-getriggertem `_init`). Akzeptabel, oder strikt nur Schreib-Argumente + Trigger aus Observable?
- O2: Nach einer Überholung während einer Aktion werden die **Writes der laufenden Aktion** (Eintrag, dann Saldo) vollständig ins festgehaltene alte Profil geschrieben und nur Folgeschritte abgebrochen (Konsistenz des alten Profils). Alternative „komplett abbrechen" möglich. OK?
- O3: `updateInitialOvertime(ms, profileId?)` schreibt mit übergebenem Profil in dieses (Settings-Sicht), nicht blind ins geladene. OK?
- O4: Gemeinsamer Test-Helper `shared/testing/work-profile-fake.ts` (ohne `vi`, wird mit der App typgeprüft) oder lieber je Spec dupliziert?

## Umsetzungsstand (Implementierung)
Schritte 0-6 umgesetzt (außer manuelle Browser-Verifikation, `380-pr.md`, Commit/PR: Hauptsession/Review). Abweichungen: Fall-Specs in einer Datei `dashboard.profile.spec.ts` (Fake + echter WorkProfileService); `getTodayEntry`-Profiltest über Spy auf `_firebaseToday` (`doc`/`onSnapshot` sind im gebündelten Test nicht mockbar); `_ensureCurrentDay` wartet auf laufenden Ladevorgang statt bei Profil-Mismatch abzubrechen (Fall 4 verlangt Stop im Lag-Fenster ins alte Profil); Auth-Effect ruft `_init` in `untracked`; `_settingsMaybeStale` löst bei Lag-Init einen zweiten Lauf aus.
