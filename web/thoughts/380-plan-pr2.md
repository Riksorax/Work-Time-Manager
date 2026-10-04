# Web-Plan: #380 — PR 2 (Stufe 2): Bestätigungsdialog beim Profilwechsel mit laufendem Timer
Erstellt: 2026-10-04
Research: web/thoughts/380-research.md (inkl. „Entscheidungen zu den offenen Fragen (Hauptsession)")
Vorgänger: web/thoughts/380-plan.md + 380-pr.md (PR 1 = #389, gemergt: Reinit, Schreib-Isolation, „Einfrieren")
UI-Report: entfällt (ein kleiner Bestätigungsdialog nach Vorlage `ConfirmDeleteProfileDialogComponent`, Mockup nicht nötig)
Branch-Ziel: `Closes #380`

## Ziel
Wechselt der Nutzer interaktiv das Profil (Header-Wechsler, `addProfile()`), während im Dashboard ein Timer läuft, erscheint ein
Dialog „Abbrechen" / „Beenden und wechseln". „Beenden und wechseln" stoppt und speichert den Timer im alten Profil (Eintrag +
Saldo) und wechselt erst danach; schlägt das Speichern fehl, wird nicht gewechselt und eine Fehlermeldung gezeigt. „Abbrechen"
(auch Esc/Backdrop) ändert nichts. Der Core kennt das Dashboard nicht (Guard-Registry statt Import).

## Befunde aus dem Code (verändern/präzisieren die Vorgaben)
- **Einziger interaktiver Auslöser außer `addProfile`:** `WorkProfileSwitcherComponent.select()` (zweimal in `main-shell.html`,
  Z. 37/71, derselbe Component). Die Settings-Seite hat **keine** Profilauswahl (Grep `setActiveProfile`/`app-work-profile-switcher`).
- `DashboardService` ist `providedIn: 'root'` und wird auch von `SettingsPageService` injiziert. Ein laufender Timer kann daher
  existieren, **ohne dass `DashboardComponent` je gerendert wurde** (Start auf /settings). Die Guard-Registrierung muss deshalb im
  `DashboardService`-Constructor stattfinden (nicht in der Component, nicht in einem lazy Service, den niemand instanziert).
- Der laufende Timer ist nur dem `DashboardService` bekannt (`isTimerRunning()`). Läuft ein Eintrag serverseitig, aber das
  Dashboard wurde in dieser Sitzung nie instanziert, gibt es weder Timer noch Autosave noch Guard: Wechsel ohne Dialog ist dann
  korrekt (es kann nichts ins falsche Profil geschrieben werden).
- STOP-Logik steckt heute inline in `startOrStopTimer()` (`_stopTimer` → Pflichtpausen → `_recalculateState(updated, true, ctx)` →
  `_saveOvertime(ctx.pid, totalMs)` → ggf. `_init({dayChange})`). Dort ist **kein Rollback**: `_recalculateState` setzt den State
  *vor* dem Speichern, ein Fehler lässt den Timer gestoppt, aber ungespeichert zurück. Für den Wechsel braucht es Rollback.
- `WorkProfileService.setActiveProfile` bleibt der unbedingte Wechsel (Reload/Logout-Effect, `deleteProfile`, Test-Fake).
- Layering: Core darf kein Feature/Shared-UI importieren. Dialog + `MatDialog`/`TranslateService` gehören nach `shared/`, die
  Orchestrierung in den `DashboardService` (Feature → Shared ist erlaubt).
- `TranslateService` ist nicht root-bereitgestellt (`provideTranslateService`). Würde `DashboardService` ihn im Constructor injizieren,
  bräche jede `create()`-Helper-Konstruktion der Dashboard-Specs. Lösung: **Lazy-Auflösung** über `Injector` erst im Guard-Aufruf.

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Hook im Core | `WorkProfileService.registerSwitchGuard(guard): () => void` (liefert Abmelde-Funktion) + `requestSwitch(id): Promise<boolean>` | Registry statt Import (Entscheidung Hauptsession); `() => void` passt zu `DestroyRef.onDestroy` |
| Guard-Signatur | `type ProfileSwitchGuard = (req: { from: string; to: string }) => boolean \| Promise<boolean>`; `false` = Wechsel abgelehnt | Profil-IDs (nicht Namen); Namen löst der Dialog selbst über `profiles()` auf |
| `requestSwitch`-Semantik | `id === active` → `true`, keine Guards. Sonst Guards **sequenziell**, bei erstem `false` Abbruch → `false`, **kein** `setActiveProfile`. Wirft ein Guard → `false` (Wechsel bleibt aus, Fehler wird gelogged nicht geworfen). Alle `true` → `setActiveProfile(id)`, `true` | Sicherer Default: im Zweifel nicht wechseln |
| Parallele Anfragen | Flag `_switchPending`: weitere `requestSwitch`-Aufrufe während einer laufenden Prüfung → `false`, Guards nicht erneut | Doppelklick/zweiter Wechsler während Dialog oder Speichern darf nicht doppelt stoppen |
| Wer registriert | `DashboardService`-Constructor, Abmeldung via `destroyRef.onDestroy` | siehe Befunde |
| Wer zeigt den Dialog | neuer Root-Service `ProfileSwitchConfirmService` (`shared/components/work-profile-switcher/`) mit `confirmStopAndSwitch({from, to}): Promise<boolean>` und `notifySaveFailed(): void` (Snackbar `shared.switchSaveFailed`, 5000 ms, „OK") | Dialog/Snackbar/Translate bleiben aus `DashboardService` heraus; in Tests durch Fake ersetzbar |
| Auflösung im Dashboard | `inject(Injector)`; im Guard erst bei **laufendem Timer** `this.injector.get(ProfileSwitchConfirmService)` | Bestehende `create()`-Helper brauchen keine neuen Provider (Dialog-Service wird nur im Dialogfall gebraucht) |
| Stop-Logik | STOP-Zweig aus `startOrStopTimer` in private `_stopRunning(ctx, { reinitAfterMidnight })` extrahieren; `startOrStopTimer` ruft sie mit `true` (Verhalten unverändert), der Wechsel-Pfad mit `false` | Identisches Pflichtpausen-/Saldo-Verhalten wie der Stop-Button; `_init({dayChange})` nach Mitternacht entfällt im Wechsel-Pfad (der Profilwechsel lädt ohnehin neu) |
| Neue öffentliche Methode | `DashboardService.stopRunningTimerForSwitch(): Promise<boolean>` — `true` = nichts (mehr) läuft oder erfolgreich gestoppt+gespeichert, `false` = Speichern fehlgeschlagen/überholt | Guard bleibt dünn und testbar |
| Rollback bei Fehler | Snapshot von `_s()` vor dem Stop; bei Exception (und `_isCurrent(ctx)`): `_s.set(snapshot)`, `_startTimerIfNeeded()`, `false` | Sonst steht das Dashboard gestoppt, aber ungespeichert; der Timer läuft für den Nutzer wie vorher weiter |
| Vorbedingung | `await _ensureCurrentDay()`-Äquivalent: bei `status === 'loading'` auf `_initRun` warten; danach `isTimerRunning()` **neu prüfen** (Dialog war offen) | Reload-Wechsel während Laden; Timer wurde evtl. zwischenzeitlich manuell gestoppt → dann kein Stop, einfach `true` |
| Dialog bei Laden | Im Lade-Zustand ist `isTimerRunning()` false (leerer Initialzustand): Wechsel ohne Dialog, überholter Lauf schreibt nichts (PR-1-Semantik „Einfrieren") | Kein Write möglich; akzeptiert |
| `addProfile()` | **läuft durch den Guard**: `api.addWorkProfile` → `refreshProfiles` → `requestSwitch(created.id)` statt `setActiveProfile`; Rückgabe weiter `created`. Lehnt der Guard ab, bleibt das Profil angelegt, aktiv bleibt das alte | User-ausgelöst, sonst umginge man den Dialog (siehe O1: weicht von Entscheidung 4 der Research ab) |
| `deleteProfile(aktiv)` | **bleibt ohne Guard** (`setActiveProfile(default)` direkt) | Eintrag + Saldo des Profils werden ohnehin gelöscht (eigener Bestätigungsdialog „unwiderruflich"); „Beenden und speichern" wäre sinnlos. PR-1-Verhalten (Timer verworfen, Wechsel vor API-Call) unverändert |
| Reload mit gemerktem Profil / Logout | **ohne Guard** (Auth-Effect setzt Signal direkt) | Nicht interaktiv, kein Timer im Dashboard zu diesem Zeitpunkt bzw. Logout stoppt per `_init` (PR 1) |
| Header-Wechsler `select(id)` | `void workProfile.requestSwitch(id)`; Haken im Menü folgt `activeProfileId()` ohnehin reaktiv | Einziger Aufrufer neben `addProfile` |
| Abbrechen × PR-1-Einfrieren | Abbrechen → `requestSwitch` = `false` → `setActiveProfile` wird **nie** aufgerufen → kein `activeProfileId$`-Event → kein `_init`, kein Timer-Stopp, kein Write; Timer läuft ungestört weiter | Einfrieren (PR 1) greift nur noch bei nicht-interaktiven Wechseln (Reload, `deleteProfile`, Logout) |
| Bestätigen × Lag-Fenster | Guard läuft **vor** dem Signal-Wechsel: der Stop schreibt mit `ctx.pid` = geladenes Profil, es gibt kein Lag-Fenster; danach löst `setActiveProfile` den Reinit aus | PR-1-Garantien bleiben unberührt |
| Neue Texte | ja: 4 Keys `shared.*`, de + en | siehe i18n |
| Premium-Gate, Routing, API-Endpunkt, Firestore-Pfad/Rules, Backend | nein | Profile sind bereits Premium-gated; keine neuen Daten |
| Shared Component | ja, aber nur im Switcher-Ordner (`confirm-switch-while-running-dialog.ts`) | Wie `ConfirmDeleteProfileDialogComponent` |

## Neue / geänderte Dateien

### Core Layer
```
web/src/app/core/services/
├── work-profile.ts        # GEÄNDERT: ProfileSwitchGuard-Typ, registerSwitchGuard, requestSwitch, addProfile via requestSwitch, Doku-Kommentar an setActiveProfile
└── work-profile.spec.ts   # NEU (bisher kein Spec): requestSwitch/Guards/addProfile/deleteProfile/Effect-Bypass
```
Vite-Falle: neue Felder nur ohne nackte Import-Referenz als Initializer (`_guards = new Set<ProfileSwitchGuard>()` ist ok, `_switchPending = false` ok). Kein `= DEFAULT_WORK_PROFILE_ID`-Feld.

### Shared Layer
```
web/src/app/shared/components/work-profile-switcher/
├── work-profile-switcher.ts                    # GEÄNDERT: select() -> requestSwitch
├── confirm-switch-while-running-dialog.ts      # NEU: ConfirmSwitchWhileRunningDialogComponent (OnPush, inline Template)
├── profile-switch-confirm.ts                   # NEU: ProfileSwitchConfirmService (root)
└── profile-switch-confirm.spec.ts              # NEU: DOM-/Service-Test des Dialogs (inkl. de/en, Fokus, ARIA)
web/src/app/shared/testing/work-profile-fake.ts # GEÄNDERT: registerSwitchGuard + requestSwitch im Fake (ohne vi, Plain-TS)
```
`createFakeWorkProfile`: speichert Guards in einem Array; `requestSwitch(id)` = gleiche Semantik wie Core (gleich → true; Guards sequenziell; ablehnen → false; sonst `set(id)` → true). Dadurch greifen alle bestehenden `create()`-Helper (`dashboard.service.spec.ts`, `dashboard.profile.spec.ts`, Settings) ohne weitere Änderung, obwohl `DashboardService` jetzt `registerSwitchGuard` im Constructor aufruft. **Alle Specs, die einen echten `DashboardService` mit handgebautem Profil-Fake konstruieren, müssen auf diesen Fake oder die neue Methode umgestellt werden** (Schritt 0: Grep `provide: WorkProfileService` in den 8 Spec-Dateien prüfen).

### Feature Layer
```
web/src/app/features/dashboard/
├── dashboard.service.ts               # GEÄNDERT: Guard-Registrierung, stopRunningTimerForSwitch, _stopRunning-Extraktion
└── dashboard.switch.spec.ts           # NEU: Guard-/Stop-/Rollback-Fälle (Fake-Profil + echter WorkProfileService)
web/src/app/features/dashboard/dashboard.profile.spec.ts   # GEÄNDERT: Fall 9a (addProfile) an Guard anpassen
```
`dashboard.ts/.html/.scss` unverändert (kein UI im Dashboard).

### i18n (`web/public/i18n/de.json` + `en.json`, Namespace `shared`)
Minimale Diffs: im Block `shared` hinter `"profileCreateFailed"` (letzter Eintrag) Komma ergänzen und die 4 Keys anhängen, sonst nichts anfassen. Escaping wie im Bestand (`\"{{name}}\"`).
| Key | de (duzen) | en |
|---|---|---|
| `shared.switchWhileRunningTitle` | Zeiterfassung läuft | Time tracking is running |
| `shared.switchWhileRunningText` | Im Profil \"{{from}}\" läuft noch eine Zeiterfassung. Sie wird beendet und gespeichert, bevor du in das Profil \"{{to}}\" wechselst. | A time entry is still running in profile \"{{from}}\". It will be stopped and saved before you switch to profile \"{{to}}\". |
| `shared.stopAndSwitchButton` | Beenden und wechseln | Stop and switch |
| `shared.switchSaveFailed` | Wechsel abgebrochen: Die Zeiterfassung konnte nicht gespeichert werden. | Switch cancelled: the time entry could not be saved. |
„Abbrechen" = `common.cancel` (existiert). Ein Spec-Test sichert, dass beide JSON-Dateien dieselben `shared.*`-Keys haben (falls ein solcher Paritäts-Test existiert, sonst im Dialog-Spec beide Dateien laden und die 4 Keys prüfen).

### Doku
`web/CLAUDE.md`: Abschnitt „Profilwechsel (#380)": letzten Satz zu „Stufe 2 folgt" ersetzen durch Guard-Hook (`registerSwitchGuard`/`requestSwitch`, wer ihn nutzt, welche Wege bewusst ohne Guard laufen); `core/services`-Baum Zeile `work-profile.ts` ergänzen; Tabelle Feature-Services unverändert (`DashboardService` aggregiert `Injector` nur lazy).

## Test-Konventionen
- `vi.useFakeTimers()` + `vi.setSystemTime(new Date(2026, 9, 5, 12, 0))` (Mo, lokale Konstruktoren), `advanceTimersByTimeAsync`, Dauern aus Differenzen; kein Test hängt von echter Uhr/Wochentag/Zeitzone ab. Läufe: `TZ=Europe/Berlin`, `America/Los_Angeles`, `Pacific/Auckland`, `UTC` (aus `web/`: `npm test -- --watch=false`).
- Specs mit echtem `WorkProfileService`: Fake-`AuthService` (`user`-Signal, `uid`), Fake-`ProfileService`, Fake-`ApiClient`; `ProfileSwitchConfirmService` immer als Fake (`confirmStopAndSwitch` mit `deferred()`/`vi.fn()`, `notifySaveFailed` als `vi.fn()`), `localStorage.clear()` in `beforeEach/afterEach`, `TestBed.resetTestingModule()` danach `vi.getTimerCount() === 0`.
- Vite-Test-Falle (`web/CLAUDE.md`): in Components/Services/Specs keine nackten importierten Konstanten als Klassenfeld-Wert (`readonly x = IMPORT;`); Konstanten im Constructor zuweisen oder in Ausdrücke einbetten (`signal(X)`, `[...X]`). Gilt besonders für den Dialog (`MAT_DIALOG_DATA`-Injection über `inject(...)` im Feld ist ok, das ist ein Aufruf, keine nackte Referenz).
- Rot-Nachweis vor Impl: rote Fälle mit Fehlermeldung in `380-pr.md` notieren (Abschnitt „PR 2").

## Implementierungsschritte (TDD-First, Layer-Reihenfolge)

### Schritt 0: Baseline
- [ ] Alle Specs mit `provide: WorkProfileService` listen (8 Dateien); prüfen, welche einen echten `DashboardService` bauen (nur dashboard.service.spec, dashboard.profile.spec).
- [ ] Baseline `npm test -- --watch=false` grün (Ausgangsstand notieren).

### Schritt 1: Core — Guard-Registry (`core/services/work-profile.spec.ts`, neu; Fakes für Auth/Profile/ApiClient)
Tests zuerst (alle ROT, Methoden existieren nicht):
- [ ] `requestSwitch(sameId)` → `true`, Guards **nicht** aufgerufen.
- [ ] Ohne Guards: `requestSwitch('B')` → `true`, `activeProfileId() === 'B'`, `localStorage['active_work_profile_<uid>'] === 'B'`.
- [ ] Guard liefert `false` → Ergebnis `false`, aktives Profil unverändert, localStorage unverändert, `activeProfileId$` emittiert nicht.
- [ ] Guard bekommt `{from: 'default', to: 'B'}`.
- [ ] Async-Guard (via `deferred()`): Wechsel erst nach Auflösung; vorher noch altes Profil.
- [ ] Mehrere Guards: sequenziell in Registrierungsreihenfolge; erster `false` → weitere nicht aufgerufen.
- [ ] Guard wirft/rejected → `false`, kein Wechsel, kein ungefangener Fehler.
- [ ] Abmelde-Funktion: nach Aufruf wird der Guard nicht mehr gefragt; doppelte Abmeldung ist harmlos.
- [ ] Parallelität: zweites `requestSwitch` während ein Guard noch aussteht → `false`, Guard nur einmal gerufen; danach (nach Auflösung) wieder ein Wechsel möglich (Flag zurückgesetzt, auch nach Ablehnung und nach Exception).
- [ ] `addProfile('Neu')`: Guard bekommt `to = created.id`; Guard `true` → aktiv = neu, Rückgabe `created`; Guard `false` → Profil angelegt (API aufgerufen, `profiles()` enthält es), aktiv bleibt, Rückgabe `created`, kein Wurf.
- [ ] `deleteProfile(aktiv)` ruft Guards **nicht** (Guard-Spy `0` Aufrufe), wechselt auf `default` (GRÜN-Regression des PR-1-Verhaltens inkl. Rückwechsel bei API-Fehler).
- [ ] Auth-Effect (Reload mit gemerktem Profil, `user.set(null)` Logout): Guards **nicht** gerufen (`TestBed.flushEffects()`).
- [ ] `setActiveProfile` selbst ruft keine Guards (Dokumentationstest, damit der Bypass bewusst ist).
- [ ] Impl: Typ + Registry (`Set`), `requestSwitch`, `_switchPending` mit `try/finally`, `addProfile` → `requestSwitch`.

### Schritt 2: Shared — Fake, Dialog, Confirm-Service
- [ ] Fake `createFakeWorkProfile` um `registerSwitchGuard`/`requestSwitch` erweitern (ohne `vi`); `tsconfig.app` baut ihn mit (`npm run build -- --configuration production` in Schritt 6).
- [ ] Test `profile-switch-confirm.spec.ts` (echtes `MatDialog` im TestBed, `provideTranslateService` mit de/en-JSON aus `public/i18n/` geladen, Fake-`WorkProfileService` mit `profiles()` `[Standard, Firma B]`):
  - [ ] Dialog zeigt Titel, Text mit Namen **„Standard"/„Firma B"** (nicht IDs), beide Buttons (`de` und `en`).
  - [ ] „Beenden und wechseln" → `confirmStopAndSwitch` resolved `true`; „Abbrechen" → `false`; Esc → `false`; Backdrop-Klick → `false`.
  - [ ] Initialer Fokus liegt auf „Abbrechen" (`cdkFocusInitial`), Dialog hat `role="dialog"` + `aria-labelledby` auf den Titel.
  - [ ] Unbekannte Profil-ID (Profil in der Zwischenzeit gelöscht) → Fallback-Name = ID, kein Wurf.
  - [ ] `notifySaveFailed()` öffnet Snackbar mit dem übersetzten Text von `shared.switchSaveFailed`.
  - [ ] i18n-Parität: die 4 Keys existieren in `de.json` und `en.json`, nicht leer.
- [ ] Impl: Dialog-Component (Titel `shared.switchWhileRunningTitle`, Text mit `{from,to}`, Buttons `common.cancel` mit `cdkFocusInitial` + `mat-dialog-close`, `mat-flat-button` `shared.stopAndSwitchButton` ohne Warnfarbe → `close(true)`), Service, i18n-Keys.
- [ ] `work-profile-switcher.ts`: `select(id)` → `void this.workProfile.requestSwitch(id)`; Test in einem kleinen Switcher-Spec (falls keiner existiert, in `profile-switch-confirm.spec.ts` oder neu `work-profile-switcher.spec.ts`): Klick auf anderes Profil ruft `requestSwitch(id)`, nicht `setActiveProfile`.

### Schritt 3: Dashboard — Stop-Refactor + Guard (`dashboard.switch.spec.ts`)
Tests zuerst; Fake-Profil (`createFakeWorkProfile`) bzw. echter Service je Fall; Fake-Services protokollieren Writes mit Profil-Argument (Muster `dashboard.profile.spec.ts`); Confirm-Fake via `{ provide: ProfileSwitchConfirmService, useValue: fake }`:
- [ ] **Registrierung**: `DashboardService`-Konstruktion registriert genau einen Guard; nach `TestBed.resetTestingModule()` (Destroy) ist er abgemeldet (Registry-Größe/Verhalten: `requestSwitch` ruft den Guard nicht mehr).
- [ ] **Kein Timer**: leerer/gestoppter Eintrag → `requestSwitch('B')` → `true`, `confirmStopAndSwitch` **nicht** gerufen, Wechsel + Reinit auf B (Grün-Regression PR 1).
- [ ] **Timer läuft, „Abbrechen"** (Fake → `false`): `requestSwitch` = `false`, aktiv bleibt A, **keine** Writes (Fake-Protokoll leer), `isTimerRunning()` true, `vi.getTimerCount()` = 1, `getTodayEntry`/`getOvertime` nicht erneut aufgerufen (kein Reinit), nach `advanceTimersByTimeAsync(31_000)` schreibt der Autosave weiter ausschließlich mit Profil A (Timer lief ungestört).
- [ ] **Timer läuft, „Beenden und wechseln"**: Reihenfolge der Aufrufe `saveEntry(A-Eintrag mit workEnd, 'A')` → `saveOvertime(A-Saldo, 'A')` → erst **danach** `activeProfileId()` = B (Reihenfolge über gemeinsamen Call-Log inkl. Profilwechsel-Event); danach lädt das Dashboard B (Eintrag/Saldo von B, Fall-9-Muster), `vi.getTimerCount()` nur falls B läuft; `workEnd` des A-Eintrags ist im Fake-A-Speicher gesetzt (nicht mehr laufend → Rückwechsel setzt **keinen** Timer fort).
- [ ] **Pflichtpausen identisch zum Stop-Button**: Sitzung > 6 h Brutto (Differenz aus Fake-Zeit, nicht hart kodiert): gespeicherter Eintrag enthält die automatische Pause, Saldo entspricht dem Ergebnis von `startOrStopTimer()` im selben Szenario (Vergleichstest beider Pfade).
- [ ] **Speichern schlägt fehl** (`saveEntry` rejected): `requestSwitch` = `false`, aktiv bleibt A, `notifySaveFailed` genau einmal, **kein** `saveOvertime`; Rollback: `isTimerRunning()` true, `workEntry().workEnd` undefined, Timer läuft wieder (`getTimerCount()` 1), kein Reinit; Folge-Versuch (Fake wieder ok) funktioniert und wechselt.
- [ ] **Speichern des Saldos schlägt fehl** (`saveEntry` ok, `saveOvertime` rejected): wie oben `false` + Meldung + Rollback; dokumentierter Rest: Eintrag liegt serverseitig bereits mit `workEnd`, der nächste Autosave überschreibt ihn wieder mit dem laufenden Eintrag (Test: nach 31 s Autosave mit `workEnd === undefined`).
- [ ] **Timer wurde während des Dialogs manuell gestoppt** (Confirm-Fake löst erst nach `startOrStopTimer()` auf): `stopRunningTimerForSwitch` erkennt „läuft nicht mehr", **kein** zweiter Stop/Write, Wechsel erfolgt.
- [ ] **Profil wechselte während des Dialogs** (aktiv ≠ `from` nach Bestätigung): kein Stop, `false` (defensiv, kann nur durch nicht-interaktive Pfade passieren).
- [ ] **Lade-Zustand** (Reload mit Wechsel, `getTodayEntry` hängt per `deferred()`): Wechsel ohne Dialog, überholter Lauf schreibt nichts (Writes leer), Endzustand B.
- [ ] **Tageswechsel im Stop** (Timer über Mitternacht, `vi.setSystemTime` nach 00:00): Wechsel-Pfad stoppt im alten Profil, löst **keinen** `dayChange`-Reinit aus (genau ein `_init`: der des Profilwechsels, Aufrufzähler `getTodayEntry`).
- [ ] **Doppelte Anfrage** (zweimal `requestSwitch('B')` bei offenem Dialog): Dialog/Stop genau einmal, zweite Anfrage `false`.
- [ ] **Echter `WorkProfileService`** (`dashboard-first`/`profile-first`-Provider-Reihenfolge wie PR-1-Test Z. 682): der End-zu-End-Pfad „Timer läuft → `requestSwitch` → bestätigen → B geladen" und der Abbrechen-Pfad (kein `activeProfileId$`-Event, `TestBed.flushEffects()`).
- [ ] **`addProfile` mit laufendem Timer (Fall 9a ersetzt/ergänzt, `dashboard.profile.spec.ts` Z. 721)**: Confirm → `true`: A gestoppt/gespeichert, dann B (neu) aktiv und leer, nie A-Eintrag unter B; Confirm → `false`: A läuft weiter, Profil trotzdem angelegt, kein Write. Der bestehende Fall erhält dafür einen Confirm-Fake (sonst `injector.get` auf nicht bereitgestellten Service → `NullInjectorError`, im Guard als „Ablehnung" abgefangen; Test explizit auf das gewollte Verhalten umschreiben statt auf diesen Zufall zu bauen).
- [ ] **Guard-Fehlerpfad**: `injector.get(ProfileSwitchConfirmService)` wirft → Wechsel abgelehnt, keine Writes (deckt Fehlkonfiguration ab).
- [ ] Bestandstests `startOrStopTimer` (Start/Stop/Restart-Dialog/Midnight/Pflichtpausen/In-flight) **unverändert grün** nach der `_stopRunning`-Extraktion (reiner Refactor, vorher Lauf notieren).
- [ ] Impl: `_stopRunning(ctx, { reinitAfterMidnight })` extrahieren, `startOrStopTimer` delegiert; `stopRunningTimerForSwitch` (Warten auf `_initRun` bei `loading`, Re-Check `isTimerRunning`, Snapshot/Rollback, `_isCurrent(ctx)`-Prüfung vor Rollback); Constructor: `const unregister = this.workProfile.registerSwitchGuard(req => this._confirmSwitch(req)); this.destroyRef.onDestroy(unregister);` (Zuweisung im Constructor, keine Klassenfeld-Referenz); `_confirmSwitch`: `!isTimerRunning()` → `true`; sonst `confirm = injector.get(ProfileSwitchConfirmService)`; `!(await confirm.confirmStopAndSwitch(req))` → `false`; `ok = await stopRunningTimerForSwitch(req.from)`; `!ok` → `confirm.notifySaveFailed()`; return `ok`.
- [ ] Mutationsprüfung (Quelle ändern, mit `cmp` zurücksetzen): (a) Guard-Registrierung entfernen → Dialog-/Stop-Fälle rot; (b) Stop-Pfad speichert ins aktive statt festgehaltene Profil → rot; (c) `setActiveProfile` vor dem Stop → Reihenfolge-Test rot; (d) Rollback entfernen → Fehlerfall rot; (e) Re-Check `isTimerRunning` entfernen → „Timer manuell gestoppt" rot; (f) `_switchPending` entfernen → Doppelanfrage rot; (g) `requestSwitch` ignoriert `false` → Abbrechen-Fall rot; (h) `addProfile` nutzt wieder `setActiveProfile` → Fall 9a rot; (i) `deleteProfile` über Guard → Bypass-Test rot.

### Schritt 4: Integration
- [ ] Kein neuer Route-/Shell-Eintrag. Manuell prüfen, dass beide Header-Instanzen (Desktop/Mobil, `main-shell.html` Z. 37/71) denselben Pfad nutzen.
- [ ] `addProfile`-Aufrufer `work-profile-switcher.ts handleAdd()`: Snackbar „Profil angelegt" bleibt auch bei abgelehntem Wechsel korrekt (Profil existiert). Test im Switcher-Spec (kein Wurf bei Ablehnung).

### Schritt 5: Doku
- [ ] `web/CLAUDE.md` wie oben; `380-pr.md` um Abschnitt „PR 2" (rote Fälle, Mutationstabelle, i18n-Keys, `Closes #380`, manuelle Browser-Prüfung).

### Schritt 6: Gesamtlauf
- [ ] `npm test -- --watch=false` unter `TZ=Europe/Berlin`, `America/Los_Angeles`, `Pacific/Auckland`, `UTC` (mehrfach wegen der dokumentierten Vollauf-Flakes); `npm run build -- --configuration production` (Test-Helper ohne `vi`).
- [ ] Manuelle Browser-Verifikation (nicht automatisierbar): Timer im Standard-Profil, im Header zu B wechseln → Dialog; „Abbrechen": Timer läuft, Haken bleibt bei Standard; „Beenden und wechseln": Eintrag in Standard gestoppt (Reports prüfen), B geladen; Offline/blockierter `PUT` → Fehler-Snackbar, kein Wechsel, Timer läuft weiter; Dialog in de und en; Tastatur (Fokus auf „Abbrechen", Esc); `addProfile` mit laufendem Timer; Löschen des aktiven Profils bei laufendem Timer (kein Dialog); Start auf /settings mit laufendem Eintrag → Dialog erscheint trotzdem.
- [ ] Commit/PR übernimmt die Hauptsession.

## Signal-/Ablauf-Design (Skizze, kein Code)
- `WorkProfileService`: `requestSwitch(id)` → `id === active`? `true` : `_switchPending`? `false` : (`_switchPending = true`; für Guard in Registrierungsreihenfolge `await guard({from, to})`, Ausnahme/`false` → `false`; `setActiveProfile(id)`; `true`; `finally _switchPending = false`).
- `DashboardService._confirmSwitch(req)`: kein laufender Timer → `true`. Sonst Dialog → bestätigt → `stopRunningTimerForSwitch` → Fehler: Snackbar via Confirm-Service → `false`.
- `stopRunningTimerForSwitch`: auf `loading` warten → läuft nichts? `true` → `ctx = _ctx()`, Snapshot → `_stopRunning(ctx, { reinitAfterMidnight: false })` → Fehler: Rollback (nur wenn `_isCurrent(ctx)`) → `false`.
- Kein neuer öffentlicher Signal-Typ im Dashboard; der Dialog hält keinen Zustand außer `MAT_DIALOG_DATA {fromName, toName}`.

## Risiken
- **Teilfehler Stop** (Eintrag gespeichert, Saldo nicht): siehe Test; selbstheilend beim nächsten Stop/Autosave, aber bei geschlossenem Tab bleibt ein Eintrag mit `workEnd` ohne Saldo-Update (Saldo-Heuristik beim nächsten `_init` rechnet über `lastUpdated`, daher begrenzter Schaden). Alternative wäre ein Backend-Endpunkt „stop+saldo atomar"; nicht Scope.
- Stop im Wechsel-Pfad dauert eine Netzwerkrunde: Menü ist zu, kein Busy-Indikator → optional Dialog-Button während des Speicherns deaktivieren (nicht geplant, siehe O3).
- Zwei Wechsler im DOM (Desktop/Mobil): nur einer sichtbar; `_switchPending` verhindert Doppelausführung.
- `addProfile` bei abgelehntem Wechsel lässt Profil angelegt: Nutzer sieht „angelegt", bleibt in A (gewollt, sonst API-Rollback nötig).
- `Injector.get` zur Laufzeit statt Constructor-Injection: Fehlkonfiguration fällt erst beim Wechsel mit laufendem Timer auf; durch den Guard-Fehlerpfad-Test und den End-zu-End-Test mit echtem Service abgesichert.
- Dokumentierte PR-1-Entscheidung „Einfrieren" bleibt für Reload/Logout/`deleteProfile`; ein dort laufender Timer in A bleibt serverseitig als laufend gespeichert (bekannt, wie Mobile).

## Offene Fragen an die Hauptsession
- **O1 (Abweichung):** Entscheidung 4 der Research ordnete `addProfile()` der „Stufe-1-Semantik ohne Dialog" zu, Research 11 und der Auftrag sagen „gleicher Guard wie ein Klick im Header". Plan: `addProfile` läuft durch den Guard (Profil wird zuerst angelegt, bei Ablehnung bleibt es angelegt, aktiv bleibt A). Alternative: Guard **vor** `api.addWorkProfile` (kein verwaistes Profil bei „Abbrechen", aber Timer wird ggf. gestoppt, obwohl das Anlegen danach scheitert). OK mit der Plan-Variante?
- **O2:** `deleteProfile(aktiv)` bewusst **ohne** Guard (Eintrag wird gelöscht, eigener Löschdialog). Bestätigen?
- **O3:** Busy-Zustand während des Speicherns („Beenden und wechseln" speichert nach dem Dialog-Close, ohne Spinner): ausreichend, oder Dialog bis zum Speicherergebnis offen halten (Button disabled/Spinner, Fehler im Dialog statt Snackbar)? Plan nimmt die einfache Variante (Dialog schließt, Snackbar nur im Fehlerfall; `shared.switchSaveFailed` als Snackbar wie vorgegeben).
- **O4:** Neue Methode `stopRunningTimerForSwitch` extrahiert die STOP-Logik (reiner Refactor von `startOrStopTimer`). Akzeptabel, oder lieber `startOrStopTimer()` unverändert aufrufen und den Rollback außen bauen (weniger Refactor, aber Doppelanzeige/Midnight-`_init` nicht unterdrückbar)?
- **O5:** Läuft ein Eintrag serverseitig, ohne dass `DashboardService` in der Sitzung instanziert wurde (nur Reports/Kalender geöffnet), erscheint kein Dialog (es gibt keinen Timer, nichts wird geschrieben). Als gewollt akzeptieren?
- **O6:** Namensgebung/Ablage: `ProfileSwitchConfirmService` + Dialog in `shared/components/work-profile-switcher/` (kein neuer Ordner). Recht so, oder Dialog als eigene `shared/components/`-Unterkomponente?
- **O7 (Hinweis):** Teilfehler Stop (Eintrag ok, Saldo fehlgeschlagen) wird nur durch Rollback + Autosave geheilt; kein atomarer Backend-Weg. Falls gewünscht, eigenes Issue.

## Entscheidungen zu den offenen Fragen (Hauptsession)

- **O1:** Der Guard läuft in `addProfile` **vor** dem API-Aufruf. Bei „Abbrechen" wird kein Profil angelegt (kein verwaistes Profil). Der Plan ist entsprechend anzupassen.
- **O2:** `deleteProfile(aktiv)` bleibt ohne Guard, bestätigt (PR 1 schaltet dort schon vor dem API-Aufruf um; das Einfrieren greift).
- **O3:** Kein Busy-Zustand, nur Snackbar im Fehlerfall. `_switchPending` verhindert parallele Anfragen. Ausreichend.
- **O4:** Refactor `_stopRunning` ist akzeptiert, solange das Verhalten von `startOrStopTimer` unverändert bleibt (bestehende Tests grün, keine Anpassung außer Fall 9a).
- **O5:** Akzeptiert (ohne `DashboardService` läuft kein Timer).
- **O6:** Ablage im Switcher-Ordner akzeptiert.
- **O7:** Eigenes Issue (legt die Hauptsession an); in PR-Body unter „Bekannte Grenzen" erwähnen.
