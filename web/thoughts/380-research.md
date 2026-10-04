# Web-Research: #380 — Dashboard: Profilwechsel wird nicht behandelt (Autosave kann ins neue Profil schreiben)
Datum: 2026-10-04
Typ: BUG-Analyse (kein Flutter-Port). Nur Code-Analyse, Browser-Reproduktion steht aus (siehe Abschnitt 9).
Feature-Ordner: web/src/app/features/dashboard/ (+ core/services/work-profile.ts, ggf. shared/components/work-profile-switcher/)

## Quellen
- Issue #380 (Label `bug`, 2 Kommentare: Auto-Bugfix hat das Issue zurückgestellt, weil das Verhalten bei laufendem Timer eine Produktentscheidung ist).
- `web/thoughts/372-research.md`, `372-plan.md`, `372-pr.md` (Reinit-Mechanismus; Profilwechsel dort bewusst als Folge-Issue ausgeklammert).
- Web: `features/dashboard/dashboard.service.ts` (568 Z.), `core/services/work-profile.ts`, `work-entry.ts`, `overtime.ts`, `settings.ts`, `leave-balance.ts`, `features/reports/reports.service.ts`, `features/settings/settings.service.ts`, `shared/utils/work-profile-path.util.ts`, `shared/components/work-profile-switcher/*`.
- Mobile: `presentation/view_models/dashboard_view_model.dart`, `core/providers/providers.dart` (`activeWorkProfileIdProvider`, `workRepositoryProvider`, `overtimeRepositoryProvider`, `settingsRepositoryProvider`).

## 1. Wie das aktive Profil im Web bestimmt wird
- `WorkProfileService` (root): `_activeProfileId = signal('default')`; öffentlich `activeProfileId` (Signal, readonly) und `activeProfileId$ = toObservable(_activeProfileId)`.
- Wichtig: `toObservable` ist ein `ReplaySubject(1)`, der **über einen `effect` befüllt wird**. Nach `signal.set()` hält er bis zum nächsten Effect-Flush noch den **alten** Wert.
- `activeProfileIdForApi` ist ein Getter, der das **Signal direkt** liest (`undefined` für `'default'`, sonst die ID) und für `ApiClient`-Aufrufe (`?profileId=`) genutzt wird. Er ist also immer aktuell, `activeProfileId$` kann hinterherhinken.
- Ein Constructor-`effect` auf `auth.user()`: ohne uid -> `'default'`, mit uid -> Wert aus `localStorage['active_work_profile_<uid>']` (sonst `'default'`), danach `refreshProfiles()`.
- `setActiveProfile(id)` setzt das Signal synchron und schreibt `localStorage`. Aufrufer: `WorkProfileSwitcherComponent.select()`, `addProfile()` (wechselt nach dem Anlegen **automatisch** ins neue Profil), `deleteProfile()` (wechselt auf `'default'`, wenn das aktive Profil gelöscht wird).
- Wechsler sitzt im Header (`main-shell.html`, zwei Stellen), ist also **auf jeder Seite, auch bei laufendem Timer**, bedienbar.
- Es gibt keinen Wechsel-Hook (kein Guard, kein „beforeSwitch“): der Wechsel ist sofort und unbedingt.

## 2. Wie Dashboard und Core-Services den Profil-Scope nutzen
| Service | Lesen | Schreiben | Reagiert auf Profilwechsel? |
|---|---|---|---|
| `WorkEntryService.getTodayEntry()` | `combineLatest([auth.user$, activeProfileId$])` -> `switchMap` -> Firestore `onSnapshot` auf `profileScopedPath(uid, 'work_entries', profileId)/{yyyy-MM}` | `api.saveWorkEntry(entry, activeProfileIdForApi)` (Getter beim **Aufruf**) | Observable ja, aber der Dashboard-Konsument nimmt nur `firstValueFrom` |
| `WorkEntryService.getEntriesForMonth()` | wie oben | — | ja (Reports) |
| `SettingsService.getSettings()` | `combineLatest([user$, activeProfileId$])`, Pfad `profileScopedPath(uid,'settings',profileId)/current` | `api.saveSettings(..., activeProfileIdForApi)` | ja |
| `OvertimeService.getOvertime()/getLastUpdateDate()` | `api.getOvertimeMs/-LastUpdate(activeProfileIdForApi)` (Promise, einmalig) | `api.saveOvertimeMs(ms, activeProfileIdForApi)`; `saveLastUpdateDate` ist eingeloggt ein No-op (Backend setzt `lastUpdated = jetzt`) | **nein** (kein Observable) |
| Firestore-Pfad | Standard `users/{uid}/…`, sonst `users/{uid}/profiles/{id}/…` | Backend `ProfileScope` analog | — |

Der Eintrags-`id` ist der Datumsschlüssel (`yyyy-MM-dd`) und in **allen Profilen identisch**. Ein Eintrag des Profils A, der unter Profil B gespeichert wird, überschreibt dort den Tageseintrag desselben Tages vollständig.

## 3. Profilabhängige Zustände im Dashboard (`DashboardState` + Cache)
| Zustand | Quelle beim `_init` | Profilabhängig |
|---|---|---|
| `workEntry` (Eintrag heute, Zeiten, `manualOvertimeMinutes`) | `getTodayEntry()` | ja |
| `breaks` | im Eintrag | ja |
| `initialOvertimeMs` (Basis), `totalOvertimeMs`, `dailyOvertimeMs` | `getOvertime()` + `getLastUpdateDate()` + Eintrag | ja |
| `_settingsCache` (`weeklyTargetHours`, `workdays`) -> Soll, `isExtraDay`, `expectedEnd*` | `getSettings()` (reaktiv über `switchMap`, siehe unten) | ja |
| Timer (`_timerUnsub`, `_autoSaveTick`) | aus dem Eintrag | ja (läuft nur, wenn der Eintrag läuft) |
| `holidayToday` (`_holidaySettings` -> `bundesland`) | `getSettings()` reaktiv | ja, wechselt korrekt |
| `isLoggedIn`, `todayService.today()` | Auth / Uhr | nein |

## 4. Warum nur der Auth-Effect `_init` auslöst
- `_init` ist ein **imperativer Einmal-Lauf** (`firstValueFrom(getTodayEntry())`, `await getOvertime()`, `await getLastUpdateDate()`, `firstValueFrom(getSettings())`). Der Reinit-Auslöser ist ein `effect` auf `authSvc.user()` (Flow 11) und seit #372 zusätzlich der Tageswechsel-Effect.
- Das Profil wurde später (#138/#244) in die Core-Services als `activeProfileId$` eingebaut. Die Reaktivität dieser Observables kommt im Dashboard nie an (nur `firstValueFrom`), und `OvertimeService` hat gar keine reaktive API. Das Dashboard wurde beim Profil-Port schlicht nicht angefasst.
- Nur der Settings-Teil ist zufällig reaktiv: `settingsSvc.getSettings().subscribe(...)` im Constructor läuft über `switchMap` und aktualisiert `_settingsCache` beim Wechsel, ruft dann `_recalculateOvertime()` auf. Folge: **alter Eintrag + neue Settings** (gemischter Zustand, bis zum nächsten `_init`).
- `_init(_uid, opts)` ignoriert sein `uid`-Argument (Parameter heißt `_uid`), die Services lesen Auth/Profil selbst.

## 5. Ist-Verhalten nach Profilwechsel A -> B (Code-Analyse)
Direkt nach `setActiveProfile('B')`:
1. Kein `_init`. `_s` bleibt der Zustand von A: Eintrag, Pausen, Basis, Überstunden. UI zeigt weiter A.
2. `_settingsCache` wird auf die Settings von B umgestellt (Soll/Arbeitstage von B), `_recalculateOvertime()` rechnet mit **A-Eintrag und B-Soll**.
3. Alle Schreibpfade nehmen `activeProfileIdForApi` **zum Aufrufzeitpunkt** -> `B`. `ReportsService`/`LeaveBalanceService` laden dagegen B korrekt.

### 5.1 Konkrete Race: laufender Timer
Zustand: Eintrag A läuft (`workStart` gesetzt, kein `workEnd`), Tick `interval(1000)` aktiv.
1. User wählt B im Header. Das Signal ist sofort `B`. Der Tick läuft weiter, `_tick` rechnet auf dem A-Eintrag.
2. Spätestens nach 30 Ticks (`_autoSaveTick >= 30`) -> `_autoSave()` -> `workSvc.saveEntry(A-Eintrag)` -> `api.saveWorkEntry(entry, 'B')`. Der Backend-`PUT work-entries?profileId=B` ersetzt den **Tageseintrag von B** (gleiches Datum, gleicher Tag-Schlüssel) durch den laufenden A-Eintrag. Eine bereits erfasste B-Zeit des heutigen Tages geht verloren (Datenverlust in B), A bekommt kein Update mehr.
3. Weiterer Tick/Autosave alle 30 s wiederholt das. Die UI zeigt weiterhin A-Daten unter dem B-Profil-Haken.
4. **Stop** (oder jede andere Aktion, die `_recalculateState(.., true)` aufruft): `saveEntry(updated)` -> B (überschreibt B-Tag mit A-Eintrag inkl. Pflichtpausen), danach `_saveOvertime()` -> `saveOvertimeMs(totalOvertimeMs, 'B')`: der **Überstundensaldo von B wird durch den Saldo von A (Basis A + Daily A) ersetzt**. Das Backend setzt dabei `lastUpdated = jetzt` für B. Beim nächsten `_init` im Profil B hält `calculateInitialOvertime` den Stand für „heute gespeichert“ und zieht den Tages-Daily ab -> auch die Basis ist falsch (Folgefehler).
5. Profil A bleibt mit einem **ewig laufenden** Eintrag zurück (`workStart` gesetzt, `workEnd` fehlt, letzter Autosave vor dem Wechsel). Beim Zurückwechseln und nächsten `_init` läuft der Timer „weiter“, die Brutto-Dauer enthält die gesamte B-Zeit. In Reports erscheint A als offener Tag.

### 5.2 In-flight-Race ohne Wechsel-Bug (auch ein korrekter Reinit löst sie nicht)
`_recalculateState(entry, true)` macht `await saveEntry(entry)` und danach `await _saveOvertime()`. Der Eintrag nimmt das Profil beim Aufruf (A), `saveOvertime` aber erst **nach** dem ersten `await` (Profil dann evtl. B). Wechselt der User in dem Netzwerkfenster (Stop-Klick, Backend-Latenz) das Profil, landet der Eintrag in A, der Saldo in B. Gleiches im Stop-Pfad (`await _recalculateState` -> `await _saveOvertime()`) und bei `updateInitialOvertime` (Settings -> Überstunden manuell: schreibt den im Dashboard geladenen A-Wert/Basis in B).
Folgerung: es genügt nicht, nur „bei Wechsel reinit“ zu bauen. Die Schreibpfade müssen das Profil **einmal am Aktionsanfang festhalten** oder nach jedem `await` prüfen, ob das Profil noch das geladene ist.

### 5.3 Weitere Wechsel-Auslöser (alle gehen durch `setActiveProfile`)
- **Seitenreload mit gemerktem Zweitprofil**: `WorkProfileService`-Effect setzt B (aus `localStorage`) erst, wenn `auth.user()` gesetzt ist. Der Dashboard-Auth-Effect startet `_init` im selben Flush. Je nach Effect-Reihenfolge liest `_init` `getTodayEntry()` über das noch alte `activeProfileId$` (`'default'`) und `getOvertime()` über den bereits aktuellen Getter (`B`) -> **gemischtes Laden** (Eintrag Standard, Saldo B). Nicht verifiziert (Reihenfolge ist Angular-Implementierungsdetail), Reproduktion im Browser/Test nötig.
- **`addProfile()`**: wechselt automatisch ins neue Profil (laufender Timer in A -> Autosave schreibt in das gerade angelegte Profil).
- **`deleteProfile(active)`**: wechselt auf `'default'`. Der Timer des gelöschten Profils würde danach in `default` schreiben.
- **Logout**: Effect setzt `'default'`; hier greift bereits der Auth-Effect (`_init` mit `user = null`), der Timer wird beim `_init` gestoppt. Unkritisch.

### 5.4 Nebenbefund (nur melden): `_recalculateOvertime` bei abgeschlossenem Eintrag
`_recalculateOvertime()` prüft nur `!e.workStart`, nicht `e.workEnd`. Bei jeder Settings-Emission (also auch beim Profilwechsel) rechnet sie für einen **gestoppten** Eintrag mit `now` statt `workEnd` (Daily/Total/`expectedEnd` springen). Das ist unabhängig von #380 schon bestehendes Verhalten bei Settings-Änderungen. Nicht verifiziert, ggf. eigenes Issue.

## 6. Stolperstein beim Reinit: `activeProfileId$` hinkt dem Signal hinterher
Ein Reinit, der auf `workProfile.activeProfileId()` (Signal) per `effect` hört und dann `_init` startet, ruft `getTodayEntry()` auf, das über `activeProfileId$` (ReplaySubject, per Effect gespeist) kombiniert. Läuft der Dashboard-Effect **vor** dem `toObservable`-Effect, liefert der Replay noch das alte Profil: `firstValueFrom` erhält den A-Eintrag, `getOvertime()` (Getter) dagegen den B-Saldo -> genau die gemischte Ladung aus 5.3.
Empfehlung: Auslöser **aus `activeProfileId$` selbst** ableiten (`activeProfileId$.pipe(distinctUntilChanged(), …)`, erste Emission = Startzustand überspringen oder Vergleich mit zuletzt geladenem Profil), nicht aus einem Signal-Effect. Dann ist der Replay beim Abonnieren von `getTodayEntry()` garantiert schon neu. Alternativ ein expliziter Parameter `profileId` an `getTodayEntry()`/`getOvertime()`. Das ist im Test mit **echtem** `WorkProfileService` (nicht Fake) zu belegen.

## 7. Weitere Stellen mit demselben Problem (nur melden)
| Stelle | Reagiert auf Profilwechsel? | Befund |
|---|---|---|
| `ReportsService` (`_monthlyEntries` über `getEntriesForMonth`, `_apiDaily/_apiWeekly/_apiMonthly` mit `activeProfileId$` in `combineLatest`, `_settings`) | ja | ok. Der `activeProfileIdForApi`-Getter wird in `switchMap` gelesen (Signal ist da bereits aktuell). |
| `LeaveBalanceService` (`combineLatest([uid$, activeProfileId$, year$])`) | ja | ok. Lädt neu, `target.set(loading)` |
| `SettingsService.getSettings()` | ja | ok |
| `SettingsPageService._loadOvertime()` | **nein** | Effect hört nur auf `authService.user()`. Nach Profilwechsel zeigt die Settings-Seite weiter den Überstundensaldo (`overtimeMs`, `lastOvertimeUpdate`) von A. `setOvertime(ms)` ruft `dashboardSvc.updateInitialOvertime(ms)` -> `saveOvertime` ins neue Profil mit dem im Dashboard geladenen Basiswert. Gehört in denselben Fix (Profil als zusätzlicher Auslöser, oder gemeinsame Quelle `OvertimeService` reaktiv). |
| `DashboardService.updateInitialOvertime` | **nein** | siehe 5.2 |
| `DashboardService._holidaySettings` | ja | ok |
| `DataSyncService` | n/a | arbeitet nur Standard-Pfad (anonyme Daten -> Login), kein Profilbezug; nicht untersucht |
| `EditEntryDialog` / Kalender-Edits | nicht untersucht | Schreiben über `WorkEntryService` (Getter zum Aufrufzeitpunkt); Dialog selbst schließt bei Wechsel nicht |

## 8. Mobile-Referenz
- Mobile hat **dieselbe Architektur, aber der Auslöser ist eingebaut**: `DashboardViewModel.build()` macht `ref.watch(getTodayWorkEntryUseCaseProvider)`, `getOvertimeUseCaseProvider`, `settingsRepositoryProvider`. Diese hängen über `workRepositoryProvider`/`overtimeRepositoryProvider`/`settingsRepositoryProvider` an `ref.watch(activeWorkProfileIdProvider)`. Ein Profilwechsel invalidiert damit das ViewModel: Rebuild, neuer State, `Future.microtask(_init)`.
- Bei laufendem Timer: `ref.onDispose` bricht `_timer` und `_autoSaveTimer` ab und erhöht `_initGen`. Der laufende Eintrag wird dabei **weder gestoppt noch gespeichert**, er bleibt im alten Profil serverseitig „laufend“ (jede Aktion hat sofort gespeichert, der Autosave schreibt kein neues Datum). Das neue Profil lädt seinen eigenen Eintrag. Beim Zurückwechseln `_init` -> `_startTimerIfNeeded` -> Timer läuft ab dem gespeicherten `workStart` weiter (also inkl. der Zeit im anderen Profil).
- Es werden **nie Daten des alten Profils in das neue geschrieben**, weil die Repos mit der `profileId` **gebaut** werden (Konstruktor-gebunden), nicht beim Aufruf aufgelöst. Das ist der eigentliche Unterschied zum Web-Getter-Muster.
- Kein UI-Hinweis oder Dialog bei Wechsel mit laufendem Timer, keine Tests dazu (`dashboard_view_model*_test.dart` ohne Profil-Szenario). Mobile-Rest-Risiko: In-flight `await saveWorkEntry` + `ref.read(overtimeRepositoryProvider)` danach (liest nach dem `await` neu, nicht untersucht; Rebuild-Race analog 5.2). Nur melden, kein Scope.
- Folge: Mobile ist Variante (d) unten („einfrieren“), nicht (a)/(b)/(c).

## 9. Reproduktion (im Browser, vor dem Fix durchzuführen; im Cloud-Container nicht möglich)
Voraussetzung: Premium-User mit Zweitprofil „B“, API/Firestore-Emulator oder Staging.
1. Profil Standard, „Zeiterfassung starten“. In B vorher einen Eintrag für heute anlegen (z. B. 08:00–12:00).
2. Im Header auf B wechseln, Network-Tab offen halten. Erwartet (Bug): Dashboard zeigt weiter den laufenden Timer; nach <= 30 s `PUT /api/work-entries?profileId=B` mit dem Standard-Eintrag; B-Eintrag in Firestore überschrieben.
3. In B „Beenden“ klicken: `PUT work-entries?profileId=B` + `PUT overtime?profileId=B` mit dem Saldo des Standard-Profils.
4. Zurück auf Standard: Eintrag ohne `workEnd`, Timer „läuft“ seit dem Start.
5. Variante Reload: Zweitprofil aktiv lassen, Seite neu laden, beobachten, ob das Dashboard Standard- oder B-Daten zeigt (5.3).
6. Variante `addProfile` mit laufendem Timer; Variante Löschen des aktiven Profils mit laufendem Timer.

## 10. Lösungsrichtung (zwei Stufen)
**Stufe 1 — Korrektheit (immer nötig, unabhängig von der Timer-Entscheidung):**
- Profil als Reinit-Auslöser: `activeProfileId$` (distinct) im `DashboardService` -> `_init(…)` (ohne `dayChange`, mit Lade-Zustand), Generationszähler `_initGen` aus #372 verwirft überholte Läufe; `_init` stoppt den Timer ohnehin zuerst. Eintrag, Pausen, Basis, Settings-Cache, Timer werden neu aufgebaut. Tageswechsel- und Auth-Reinit bleiben unverändert.
- Schreib-Isolation: Profil am Anfang jeder Aktion/jedes `_autoSave` festhalten (`const pid = workProfile.activeProfileId()`), nach jedem `await` im Schreibpfad (`saveEntry` -> `saveOvertime`) prüfen, ob `pid` noch das **geladene** Profil ist, sonst abbrechen. Sauberer, aber größer: `saveEntry(entry, profileId?)`/`saveOvertime(ms, profileId?)` mit explizitem Profil (der `ApiClient` nimmt es schon als Parameter); das Dashboard gibt dann immer sein **geladenes** Profil mit. Das macht die Race strukturell unmöglich (analog Mobile: Profil an das Repo gebunden). Empfehlung: explizites Profil in `WorkEntryService.saveEntry`/`OvertimeService.saveOvertime`/`saveLastUpdateDate` (optional, Default = aktiv) plus Test, dass das Dashboard immer sein `loadedProfileId` übergibt.
- `_ensureCurrentDay()` bleibt; zusätzlich Guard „geladenes Profil == aktives Profil“ (sonst Reinit abwarten), analog dem Tag-Guard.
- `SettingsPageService._loadOvertime()` an das Profil koppeln (Nachbefund 7).
- Stufe 1 allein entspricht dem **Mobile-Verhalten** (Option d).

**Stufe 2 — Nutzerverhalten bei laufendem Timer (Produktentscheidung, siehe 11).**

## 11. Optionen für den laufenden Timer beim Profilwechsel
| Option | Verhalten | Aufwand | Risiko | Bewertung |
|---|---|---|---|---|
| (a) Stoppen + im alten Profil speichern, dann wechseln | Wechsel läuft über eine async Prüfung **vor** dem Setzen des Profils: Timer stoppen (STOP-Pfad mit Pflichtpausen, Eintrag + Saldo speichern, alles im alten Profil), danach `setActiveProfile`. Erfordert einen Wechsel-Hook (`WorkProfileService.requestSwitch(id): Promise<boolean>` mit registrierbaren Guards, Dashboard registriert sich; Core darf Feature nicht importieren) | M | Mittel: stilles Beenden der Arbeitszeit, auch wenn der User nur kurz ins andere Profil „gucken“ wollte; Pflichtpausen werden angewendet; Speicherfehler muss den Wechsel abbrechen; nach Rückwechsel muss der User eine neue Session starten | gut, aber nur mit Bestätigung |
| (b) Wechsel blockieren / bestätigen lassen | Bei laufendem Timer: Dialog „Zeiterfassung läuft“ mit „Abbrechen“ und „Beenden und wechseln“ (= a). Alternativ nur Snackbar und Wechsel verweigern | S–M (Guard-Hook + kleiner Confirm-Dialog + i18n) | Niedrig: expliziter Nutzerwille, keine stille Datenänderung | **empfohlen** (als Dialog-Variante, enthält (a)) |
| (c) Timer läuft im alten Profil weiter, getrennt | Pro-Profil-Zustand im Dashboard (Map `profileId` -> State/Timer), Autosave mit explizitem Profil, globale Anzeige „Timer läuft in Profil A“, Stoppen aus B-Sicht | L–XL | Hoch: Doppelbelegung der Zeit (zwei Profile gleichzeitig), neue UI, Reports/Soll-Logik unklar, Tageswechsel-Logik (#372) pro Profil, kein Mobile-Pendant | nicht empfohlen; falls gewünscht als eigenes Feature-Issue |
| (d) „Einfrieren“ wie Mobile (Stufe 1 ohne Hook) | Timer-Ticks stoppen, Eintrag in A bleibt laufend, B lädt neu; Zurückwechseln setzt den Timer fort | S (nur Stufe 1) | Mittel: A zählt die Zeit in B mit, bei Nichtrückkehr ewig offener Eintrag; dafür null Datenänderung beim Wechsel | **Fallback** für nicht interaktive Wechsel (siehe unten) |

**Empfehlung:** Stufe 1 immer (macht Option d zum sicheren Boden, Mobile-Parität, schließt alle Korruptionspfade, auch ohne Dialog). Zusätzlich Stufe 2 = **Option b als Bestätigungsdialog** (Abbrechen / „Beenden und wechseln“, beendet im alten Profil nach Option a). Für nicht-interaktive oder bereits entschiedene Wechsel (Reload mit gemerktem Profil, Logout, `deleteProfile(active)`; hier ist der Eintrag ohnehin weg) gilt die Stufe-1-Semantik (d), kein Dialog. `addProfile()` läuft durch denselben Guard wie ein Klick im Header (User löst es aus). Falls die Hauptsession den kleineren Schnitt will: Stufe 1 jetzt, Stufe 2 als Folge-Issue (dann ist der Bug „Datenvermischung“ geschlossen und nur das UX-Detail offen).

## 12. UI-Texte / i18n (nur Stufe 2 benötigt neue Texte)
Neue Texte in `web/public/i18n/de.json` + `en.json` (Namespace `shared`, wo auch der Wechsler liegt; `common.cancel` existiert bereits):
| Key | de | en |
|---|---|---|
| `shared.switchWhileRunningTitle` | Zeiterfassung läuft | Time tracking is running |
| `shared.switchWhileRunningText` | Im Profil „{{from}}“ läuft noch eine Zeiterfassung. Sie wird beendet und gespeichert, bevor du in das Profil „{{to}}“ wechselst. | A time entry is still running in profile “{{from}}”. It will be stopped and saved before you switch to profile “{{to}}”. |
| `shared.stopAndSwitchButton` | Beenden und wechseln | Stop and switch |
| `shared.switchSaveFailed` | Wechsel abgebrochen: Die Zeiterfassung konnte nicht gespeichert werden. | Switch cancelled: the time entry could not be saved. |
Abbrechen: `common.cancel`. Fokus-/ARIA: Dialog über `MatDialog` (wie `ConfirmDeleteProfileDialogComponent`), initialer Fokus auf „Abbrechen“ (sicherere Aktion). Stufe 1 braucht **keine** neuen Texte (stiller Reload, ggf. Lade-Spinner).

## 13. Tests (Vitest; Muster aus `dashboard.service.spec.ts`)
Voraussetzung: das bestehende `create()` nutzt Fakes und **kein** `WorkProfileService`. Für #380 ein Profil-Fake mit **steuerbarem** `activeProfileId` (Signal) und `activeProfileId$` (BehaviorSubject/ReplaySubject, getrennt auslösbar, um das Hinterherhinken 5.3/6 nachzustellen) plus `activeProfileIdForApi`-Getter. Zusätzlich ein Spec mit **echtem** `WorkProfileService` und Fake-`ApiClient`/`AuthService`.
- Fest: `vi.useFakeTimers()`, `vi.setSystemTime(new Date(2026, 9, 3, 12, 0))` (lokale Konstruktoren), `advanceTimersByTimeAsync`; nichts von echter Uhr/Wochentag abhängig (Soll-Werte über feste Settings, `[1..5]`/40 h). Läufe wie #372: `TZ=Europe/Berlin` (CI), zusätzlich `America/Los_Angeles`, `Pacific/Auckland`, `UTC`.
- Rot-vor-grün (Reproduktion der Race):
  1. Laufender Timer in A, Profilwechsel auf B, `advanceTimersByTimeAsync(31_000)`: es gibt **keinen** `saveEntry` mit dem A-Eintrag unter B (Spy mit Profil-Argument/Fake-API).
  2. Nach Wechsel zeigt `workEntry()` den Eintrag von B (Fake liefert je Profil unterschiedliche Einträge), `isTimerRunning()` entspricht B, `vi.getTimerCount()` = Timer nur falls B läuft.
  3. Basis/Total nach Wechsel aus dem Saldo von B (Fakes je Profil: A = 120 min, B = 30 min).
  4. Settings-Cache von B (z. B. andere `workdays`/`weeklyTargetHours`) bestimmt Soll nach Wechsel.
  5. In-flight: `saveEntry` mit manuell auflösbarem Promise, während der Wartezeit Profilwechsel, danach darf `saveOvertime` **nicht** für B laufen (bzw. wird mit Profil A aufgerufen, je nach gewählter Lösung).
  6. Überholter Lauf: Wechsel A -> B -> A schnell hintereinander, `getTodayEntry`/`getOvertime` verzögert auflösen: Endzustand = A, kein Timer von B (Generationszähler).
  7. Hinterherhinkendes `activeProfileId$` (Fake löst erst nach dem Signal aus): `_init` lädt nie „Eintrag A + Saldo B“ (Test mit echtem `WorkProfileService` und `TestBed.flushEffects()`).
  8. Seitenreload: Auth-User gesetzt, `localStorage['active_work_profile_<uid>'] = 'B'`: nach Flush ist Zustand vollständig B (kein Mix).
  9. `addProfile` / `deleteProfile(active)` mit laufendem Timer -> kein Write ins falsche Profil.
  10. Tageswechsel-Interaktion: Profilwechsel um 23:59:50 + Mitternacht, genau ein gültiger Endzustand; `dayChange`-Basis nur bei Tageswechsel, nicht beim Profilwechsel (Profilwechsel nutzt die `lastUpdated`-Heuristik).
  11. `updateInitialOvertime` nach Wechsel schreibt in das **geladene** Profil bzw. bricht ab.
- Stufe 2: Guard lehnt ab -> Profil bleibt A, kein Write; „Beenden und wechseln“ -> Reihenfolge `saveEntry(A)`, `saveOvertime(A)`, dann `setActiveProfile(B)`; Speicherfehler -> Wechsel abgebrochen, Snackbar-Key `shared.switchSaveFailed`; ohne laufenden Timer kein Dialog; DOM-Test des Dialogs (Fokus, de/en, ARIA).
- Aufräumen: `TestBed.resetTestingModule()` -> `vi.getTimerCount()` = 0, Subscription auf `activeProfileId$` per `takeUntilDestroyed` beendet.
- Mutationsprüfung wie in #372 (Auslöser entfernen, Profil-Capture entfernen, Generationsprüfung entfernen -> jeweils rot).

## 14. Offene Fragen (mit Empfehlung)
1. Welches Verhalten bei laufendem Timer? Empfehlung: Stufe 1 immer (Reinit + Schreib-Isolation, entspricht Mobile) und Stufe 2 als Bestätigungsdialog „Beenden und wechseln“ / „Abbrechen“ (Option b mit a). Nicht (c).
2. Soll Stufe 2 im selben PR kommen? Empfehlung: **nein, zwei PRs/Issues**: PR 1 = Stufe 1 (schließt die Datenkorruption, keine neuen Texte), PR 2 = Dialog + i18n. Falls ein PR gewünscht ist, beides zusammen, aber Stufe 1 zuerst commiten/testen.
3. Explizites `profileId`-Argument in `WorkEntryService.saveEntry` / `OvertimeService.saveOvertime` (Core-API-Erweiterung, abwärtskompatibel optional) oder reine Prüfung nach jedem `await` im Dashboard? Empfehlung: explizites Argument (strukturell sicher, entspricht Mobile-Repo-Bindung), Prüfung zusätzlich als Defense-in-Depth beim Laden.
4. Wechsel-Hook im Core (`WorkProfileService.requestSwitch` + Guard-Registry) oder Guard im Switcher-Component (shared -> Dashboard-Import, Layering-Verstoß)? Empfehlung: Hook im Core, Dashboard registriert sich (kein Feature-Import im Core).
5. Nicht-interaktive Wechsel (Reload, `deleteProfile(active)`, Logout): Stufe-1-Semantik ohne Dialog, bei `deleteProfile` den Timer des gelöschten Profils verwerfen (kein Save). OK? Empfehlung: ja.
6. Nachbefund `SettingsPageService._loadOvertime` (reagiert nicht aufs Profil) im selben Fix? Empfehlung: ja (kleiner Zusatz, gleiche Ursache, sonst falscher Saldo/Schreibweg in den Einstellungen).
7. Nachbefund 5.4 (`_recalculateOvertime` bei abgeschlossenem Eintrag mit `now`) separat anlegen? Empfehlung: erst per Test bestätigen, dann eigenes Issue.
8. Reload-Race (5.3): vor dem Fix im Browser/Test mit echtem `WorkProfileService` bestätigen? Empfehlung: ja, als erster roter Test.
9. Mobile-Rest-Risiken (in-flight Race, kein Profil-Test, Timer-Verhalten „einfrieren“ nicht explizit entschieden) als eigenes Mobile-Issue? Empfehlung: ja, niedrige Priorität.

## 15. Risiken
- Lade-Flackern: Profilwechsel setzt `initialState()` (Spinner) wie Auth-Reinit. Akzeptabel, da bewusst sichtbarer Wechsel.
- Firestore-`onSnapshot`-Erstemission pro Profil kann aus Cache kommen; `firstValueFrom` nimmt den ersten Wert (wie heute).
- `lastUpdated`-Heuristik pro Profil: nach Profilwechsel kein `dayChange`, also normale Heuristik. Korrekt, solange vorher nichts ins falsche Profil geschrieben wurde. **Bereits verfälschte Daten** (durch den Bug) werden vom Fix nicht repariert; Hinweis für die Release Notes, keine automatische Korrektur möglich.
- Dialog-Pfad: Stopp-Fehler (Offline/API) darf den Wechsel nicht still ausführen.
- i18n: nur Stufe 2, Rechtstexte unberührt. Premium: Profile sind Premium (`maxProfileCount`), kein zusätzliches Gate nötig.
- Keine neue Firestore-Regel, kein neuer Backend-Endpunkt (`?profileId=` existiert bereits an allen Endpunkten); Backend-Änderung nur, falls Stufe 2 serverseitige Absicherung wünscht (nicht nötig).

## Entscheidungen zu den offenen Fragen (Hauptsession)

Alle Empfehlungen übernommen, mit klarer PR-Aufteilung. **PR 1 (dieser Plan, `Closes`-Teil 1 von #380): Stufe 1 = Datenintegrität**, keine neuen Texte: (1) Reinit des Dashboards bei Profilwechsel; Trigger aus `activeProfileId$` (nicht aus einem Signal-Effect, da `toObservable` dem Signal hinterherhinkt: sonst „Eintrag A + Saldo B"), Test mit echtem `WorkProfileService`; (2) Schreib-Isolation: `saveEntry`/`saveOvertime` bekommen ein explizites optionales `profileId`-Argument, das pro Aktion festgehalten wird (in `_recalculateState`, `_autoSave`, Stop, Pausen, `saveOvertime` — profileId wird einmal zu Beginn der Aktion bestimmt und für alle Schreibvorgänge der Aktion verwendet), zusätzlich Prüfung nach jedem `await`; überholte Läufe (Generationszähler `_initGen`/`_initRun` aus #372) dürfen nichts mehr schreiben; (3) laufender Timer beim Wechsel: „Einfrieren" wie Mobile — Timer/Autosave im Dashboard stoppen **ohne** Speichern ins neue Profil, der Eintrag bleibt im alten Profil als laufend gespeichert und läuft beim Zurückwechseln weiter; (4) nicht-interaktive Wechsel (Reload mit gemerktem Zweitprofil, Logout, `addProfile()` wechselt automatisch, `deleteProfile(active)` wechselt auf default) mit Stufe-1-Semantik ohne Dialog, beim Löschen des aktiven Profils wird der Timer verworfen; (5) `SettingsPageService._loadOvertime` und `updateInitialOvertime` im selben Fix ans Profil koppeln; (6) Nebenbefund `_recalculateOvertime` ohne `workEnd`-Prüfung zuerst per Test bestätigen, dann falls echt als eigenes Issue melden (nicht in PR 1); (7) Reload-Race mit gemerktem Zweitprofil als erster roter Test mit echtem `WorkProfileService`. Tests: Profil-Fakes mit getrennt steuerbarem Signal/Observable, feste Daten, Fake-Timer, `TZ=Europe/Berlin`, die 11 roten Fälle aus Abschnitt 9. **PR 2 (separat, nach Merge von PR 1, braucht neue i18n-Keys de/en, `Closes #380`): Stufe 2** = Bestätigungsdialog „Abbrechen / Beenden und wechseln" bei laufendem Timer über einen Guard-Hook im Core (`WorkProfileService.requestSwitch` + Guard-Registry, kein Feature-Import im Core), Keys `shared.switchWhileRunningTitle/Text`, `stopAndSwitchButton`, `switchSaveFailed`. Option c (parallele Timer in mehreren Profilen) wird nicht umgesetzt. Mobile-Restrisiken (In-flight-Race, kein Profil-Test, „Einfrieren" nicht explizit entschieden) werden ein eigenes Mobile-Issue mit niedriger Priorität (von der Hauptsession angelegt).
