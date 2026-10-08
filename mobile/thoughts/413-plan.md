# Mobile-Plan: #413 — Reentranz-Sperre für Schreibaktionen im DashboardViewModel (PR 1 von 2)
Research: mobile/thoughts/412-413-research.md
Folge-PR: #412 (Reihenfolge Eintrag vor Saldo, Kompensation) baut auf diesem PR auf, ist hier **nicht** enthalten.

## Ziel
Überlappende Schreibaktionen (Doppeltippen, Tap im Ladefenster, Tap während Autosave) werden im `DashboardViewModel` serialisiert: ein zweiter Aufruf wird still verworfen. Autosave überlappt nie mit einer Aktion. Ein nie zurückkehrender Write sperrt das Dashboard höchstens 30 s je Write. **Die Schreibreihenfolge (Saldo -> State -> Eintrag) und alle Schreibergebnisse bleiben unverändert.**

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Neue Entity / Feld? | Nur `DashboardState.isSaving` (bool, Default `false`, in `props`/`copyWith`). Kein Entity-/Model-Feld. | Sichtbarer Zustand für deaktivierte Buttons. |
| Repository-Interface ändern? | Nein. Hybrid-/Firebase-/Local-/ApiDataSource unberührt. | Reine ViewModel-Logik. |
| Neuer Provider? | Nein. `dashboardViewModelProvider` bleibt manuell registriert; kein `@riverpod`, **kein build_runner**, keine Mocks neu. | Felder im Notifier. |
| Premium-Gate? | Nein. | Kein Feature. |
| Pro Arbeitszeit-Profil? | Ja, indirekt: Flag/Wartefuture sind Notifier-Felder und werden in `build()` zurückgesetzt (Profilwechsel). `_ActionCtx`/`_beginAction` unverändert. | #388. |
| Backend-Änderung? | Nein. Web: kein Anteil (Folge-Issue laut Research E6a). | |
| Neue Texte? | Nein. Verworfene Taps still; Timeout nutzt vorhandenes `dashboardSaveError`. Kein ARB-Change, kein `gen-l10n`. | Entscheidung Hauptsession. |
| Sperrmodell | Busy-Flag `_busy` im VM, kein Queue. Neuer privater Wrapper `_runAction(body)`; Flag wird **synchron als erste Anweisung** gesetzt, vor Autosave-Wait und `_ensureCurrentDay`. Zweiter Aufruf: sofort `true`, kein Log-Spam (nur `logger.i`), kein State-Update. | Entscheidung Hauptsession, schließt die Ladelücke. |
| Besitz des Flags | Jede Aktion erhält ein Token (`Object`/Zähler, Feld `_actionToken`). `finally` gibt Flag/Completer/`isSaving` **nur frei, wenn das Token noch das aktuelle ist**. | Nach Profilwechsel (`build()`) darf eine alte, spät endende Aktion das Flag einer neuen Aktion nicht löschen. |
| Wartefuture | `_actionDone` (`Completer<void>?`, nie mit Fehler beendet), wird im `finally` (wenn Token aktuell) **und** in `ref.onDispose` beendet; `build()` setzt `_busy=false`, `_actionToken` neu, `_actionDone=null`, `_autoSaveRun=null`. | Wartende (`stopRunningForSwitch`) hängen nie an einer überholten Aktion. |
| Rückgabe | Verworfen: `true`. `!ref.mounted` beim Aufruf: `false` (wie bisher über `_ensureCurrentDay`). Sonst Ergebnis des Bodys; Exceptions aus dem Body (z. B. `toggleBreak`) werden unverändert weitergereicht, Flag wird im `finally` frei. | Vertrag aus #402 bleibt. |
| Struktur der neun Aktionen | Jede öffentliche Aktion wird Einzeiler `=> _runAction(_xxxBody)`; der bisherige Rumpf wandert unverändert (inkl. `_ensureCurrentDay` + `_beginAction` direkt danach) in `_xxxBody`. Keine Logikänderung in den Rümpfen. | Kleinster Diff, `_beginAction`-Regel (#388) bleibt gültig. |
| Autosave | Läuft nur, wenn weder `_busy` noch `_autoSaveRun != null`. Beim Überspringen wegen Aktion bleibt `_tickCounter` auf >=30 (Retry im nächsten Tick, kein 30-s-Loch). Autosave läuft über `_autoSaveRun` (Future, `whenComplete` räumt nur bei Identität). Der Wrapper wartet nach dem Flag-Setzen auf `_autoSaveRun` (nur wenn nicht `null`, sonst kein zusätzlicher Microtask-Sprung), **vor** `_ensureCurrentDay` und damit vor jedem Write. | Voraussetzung für #412/PR 2; Autosave kann den frischen Eintrag nie überholen. |
| Timeout | Konstante `_writeTimeout = 30 s`, 3 Stellen, je Write-Block einzeln: (a) Saldo-Block (`saveOvertime` + `saveLastUpdateDate` + Warnprüfung als ein Block), (b) Eintrag-Write in `_recalculateStateAndSave`, (c) Eintrag-Write im Autosave. Nicht abgedeckt: `_ensureCurrentDay`-Lesezugriffe, `toggleBreak.call` (Bestand, siehe Grenzen). | Bounded Wait: Aktion max. ~60 s, Autosave max. 30 s. |
| Verhalten bei Timeout | (a) Saldo: wie Saldo-Fehler (#402): `catch` loggt `TimeoutException`, **`false`**, State/Timer/Eintrag unverändert, Flag frei. Ein lokales `timedOut`-Flag verhindert, dass die weiterlaufende Schließung später `saveLastUpdateDate`/Warnung nachholt (ein spät landender `saveOvertime` selbst ist nicht abbrechbar = bekannter "unbekannter Ausgang", Wiederholen ist idempotent). (b) Eintrag: wie Eintrag-Fehler (#336, PR 1 unverändert): geloggt, geschluckt, State bleibt, Ergebnis `true`, `saved=false` (kein Reinit); Autosave heilt. PR 2 ändert das auf `false` + Kompensation. (c) Autosave: geloggt, Lauf endet, nächster Autosave möglich. | Reihenfolge/Ergebnisse bleiben exakt die der bisherigen Fehlerpfade (keine neue Semantik). |
| Sichtbarer Zustand | `isSaving = _busy`, gesetzt/gelöscht im Wrapper (nur wenn `ref.mounted` und Token aktuell). `_init` baut den State per Konstruktor und gibt `isSaving: _busy` mit. Timer-Ticks nutzen `copyWith` (behalten es). | Reinit mitten in der Aktion darf die UI nicht entsperren. |
| UI | Start/Stop-Button, Pausen-Button, Pause-löschen-Icon, beide `_TimeInputField` (`enabled`) und "Speichern" im `EditBreakModal` sind bei `isSaving` deaktiviert. Kein Spinner, kein neuer Text. Programmatische Aufrufer ohne Button sind durch den VM-Guard geschützt. | Entscheidung Hauptsession. |
| `stopRunningForSwitch` | Wartet auf laufenden Ladelauf (Bestand), dann `while (_actionDone != null) await _actionDone!.future` (mit `ref.mounted`-Check), dann **ohne weiteres `await`** Profilprüfung, `isTimerRunning`, `startOrStopTimer()` (Wrapper setzt Flag synchron: keine Lücke). | Parallel getippter Stop darf den Wechsel nicht fälschlich ablehnen und nie doppelt stoppen. |
| `resumePastEntry` | Liefert `false`, wenn `_busy`: Prüfung (1) am Anfang vor `await pending`, (2) erneut direkt nach dem `await`, vor der `todayIsEmpty`-Prüfung. Setzt selbst kein Flag (schreibt nichts). Bestandsverhalten "Tap in der Ladelücke wartet auf den Pin" bleibt (Tap nach dem Pin-Start, Prüfung (2) liegt davor). | Kollision mit parallelem Start vermeiden. |
| Nicht gesperrt | `reloadAfterRetroClose`, `updateOvertimeFromSettings`, `recalculateOvertimeFromSettings`, `_onDayChange`, `_load`/`_recalculateStateAndSave(save:false)`. | Schreiben nichts bzw. Selbstblockade (Load ruft `_recalculateStateAndSave`). |

## Dateien
| Datei | neu/geändert | Zweck |
|---|---|---|
| `mobile/lib/presentation/state/dashboard_state.dart` | geändert | `isSaving` (Feld, Konstruktor, `copyWith`, `props`; `initial` default false) |
| `mobile/lib/presentation/view_models/dashboard_view_model.dart` | geändert | `_runAction`, Flag/Token/Completer, `build()`-Reset, `onDispose`, `_init`/`_load` mit `isSaving`, Autosave-Guard/-Run/-Timeout, Saldo-/Eintrag-Timeout, `stopRunningForSwitch`, `resumePastEntry`, neun Einzeiler + `_xxxBody` |
| `mobile/lib/presentation/screens/dashboard_screen.dart` | geändert | Buttons/Felder/Löschen-Icon bei `isSaving` deaktiviert |
| `mobile/lib/presentation/widgets/edit_break_modal.dart` | geändert | "Speichern" bei `isSaving` deaktiviert (sonst würde ein verworfenes Update still verloren gehen, Modal schließt sofort) |
| `mobile/test/presentation/view_models/dashboard_view_model_busy_test.dart` | neu | Kernsuite B1-B17 (Harness `profiles: true`) |
| `mobile/test/presentation/view_models/dashboard_view_model_switch_test.dart` | geändert | + B12 (Wartet auf laufende Aktion) |
| `mobile/test/presentation/view_models/dashboard_view_model_resume_test.dart` | geändert | + B13 (`false` bei laufender Aktion), nutzt dessen Konstanten (`friOpen`, `satMorning`, `fri`, `sat`) |
| `mobile/test/presentation/state/dashboard_state_test.dart` | neu bzw. erweitert (falls vorhanden) | `isSaving` in `copyWith`/Gleichheit |
| `mobile/test/presentation/screens/dashboard_screen_save_error_test.dart` | geändert | + Widget-Tests: Buttons deaktiviert, kein Snackbar bei Doppeltipp (de/en) |
| `mobile/test/presentation/widgets/edit_break_modal_test.dart` | geändert | + "Speichern" deaktiviert bei `isSaving` |
| `mobile/CLAUDE.md` | geändert | Abschnitt "Reentranz-Sperre (#413)", Streichung der Grenze (2) im #402-Abschnitt, Testliste |
| `mobile/thoughts/413-pr.md` | neu (Review-Phase) | Rot-Nachweise, Mutationsergebnisse, TZ-Läufe |
| `test/support/*`, ARB, `providers*` | **unverändert** | Fakes reichen (`holdSaves`/`pendingSaves`, `holdSaveOvertime`/`pendingOvertimeSaves`, `holdReads`, `failSaveOvertime`, `FakeClock.jumpTo`). `failSaveCalls` kommt erst in PR 2. |

## Verhalten im Detail (Referenz für die Umsetzung)

`_runAction(body)`, Ablauf in dieser Reihenfolge, **kein `await` vor Schritt 3**:
1. `!ref.mounted` -> `false`.
2. `_busy` -> `true` (verworfen, `logger.i` ohne Inhalte).
3. Token neu, `_busy = true`, `_actionDone = Completer`, `state = state.copyWith(isSaving: true)`.
4. `try`: wenn `_autoSaveRun != null` -> `await` darauf (beschränkt durch Autosave-Timeout). Dann `return await body()`.
5. `finally`: nur wenn Token noch aktuell: `_busy=false`, `_actionDone` beenden und auf `null`, bei `ref.mounted` `state = copyWith(isSaving:false)`. Ist das Token überholt (Rebuild), nichts anfassen (Completer wurde in `onDispose` beendet).

Autosave-Tick: `if (_tickCounter >= 30) { if (_busy || _autoSaveRun != null) { /* Zähler behalten */ } else { _tickCounter = 0; _autoSaveRun = _autoSave().whenComplete(räume bei Identität); } }`.

Saldo-Block: in `_recalculateStateAndSave` als lokale async-Closure mit `timedOut`-Check nach jedem `await`; `await closure().timeout(_writeTimeout)`; bestehender `catch` bleibt (fängt auch `TimeoutException`, setzt vorher `timedOut = true`), Rückgabe `false`.

Eintrag-Write: `await ctx.saveWorkEntry.call(updatedEntry).timeout(_writeTimeout)` im bestehenden `try/catch` (Logtext unverändert; `runtimeType`/Meldung ohne Eintragsinhalte).

## Schritte (TDD, jeder Schritt beginnt mit dem Test)

Layer-Reihenfolge: domain/data/core-providers/l10n haben **keine** Änderungen (Schritte entfallen). Presentation in vier Schritten, dann Doku.

### Schritt 1: Presentation — `DashboardState.isSaving` (inert, nötig damit Tests kompilieren)
- [x] Test: `dashboard_state_test.dart` — Default `false`; `copyWith(isSaving: true)`; Gleichheit unterscheidet `isSaving`; `copyWith()` ohne Argument behält den Wert; `initial()` ist `false`.
- [x] Impl: Feld + Konstruktor + `copyWith` + `props`. Sonst nichts (das VM nutzt es noch nicht).
- [x] Danach: bestehende Suite grün (Fakes, die `DashboardState(...)` bauen, sind durch den Default nicht betroffen).

### Schritt 2: Presentation — Kern: Wrapper, Flag, Token, Reset, Spiegelung
- [x] Test (zuerst, **Rot-Nachweis**): `dashboard_view_model_busy_test.dart`. Gemeinsames Setup wie `dashboard_view_model_save_error_test`: Mo 2026-10-05, Uhr 17:00, Soll 8 h, Saldo 120 min, `running` = Start 08:00, Stop schreibt `['A:overtime:135','A:lastUpdate','A:entry:<moKey>:08:00-17:00']` (`stopWrites`). Hilfen: `tap(h, action)` liefert `Result` mit `done()`/`value()` (Muster aus `dashboard_view_model_switch_test`), `release(h)` für Holds. Jeder Hold wird vor Szenario-Ende freigegeben (offene Completer + Timeout-Timer würden den Timer-Leak-Check von `scenario` auslösen).
  - **B1 Doppel-Start** (leerer Eintrag, `holdSaves`): zwei `startOrStopTimer`. Erwartet: `pendingSaves.length == 1`, zweites Ergebnis sofort `true`, State laufend (`workStart == 17:00`, `workEnd == null`), nach Freigabe genau ein `A:entry:<moKey>:17:00--`, `periodicTimerCount == 1`, **kein** Saldo-Write. Rot heute: zweiter Tap stoppt (`pendingSaves == 2`).
  - **B2 Doppel-Stop** (`running`, `holdSaveOvertime`): `pendingOvertimeSaves == 1`, zweites Ergebnis sofort `true`; nach Freigabe `writeLog == stopWrites` (genau ein Saldo-/Eintrag-Write), `saveOvertimeCalls == 1`; danach wirkt ein weiterer Aufruf (`startNewSession`) normal (Flag frei).
  - **B3 Flag frei nach Misserfolg**: (a) Saldo-Fehler (`failSaveOvertime`): Ergebnis `false`, direkt danach Stop ohne Fehler -> `stopWrites`; (b) Body wirft (Test-`ToggleBreak`, in `dashboard_view_model_profile_test.dart` als privates `_HeldToggleBreak` vorhanden; hier eigene Variante nachbauen, die wirft): Exception erreicht den Aufrufer unverändert, danach `isSaving == false` und nächster Aufruf läuft. Erwartet: (a) schon heute grün (Regressionsschutz), (b) Rot-Nachweis nicht nötig, Wächter für `finally`.
  - **B4 Pause/Pause** (`running`, `holdSaves`): zwei `startOrStopBreak` -> eine Pause im State, `pendingSaves == 1`, zweites `true`; nach Freigabe genau ein Eintrag-Write mit laufender Pause.
  - **B5 Pause + Stop** und **Stop + Pause** (je erster Aufruf gehalten): zweiter verworfen `true`, State unverändert, kein zweiter Write.
  - **B6 Manuelle Zeit + Stop** (`setManualEndTime` auf `running`, `holdSaveOvertime`; dann `startOrStopTimer`): genau ein `A:overtime`.
  - **B7 Tabelle über alle neun Aktionen** (Seeds wie `S-4`/`S-6`-Tabellen in `save_error_test`: `startOrStopTimer`, `startNewSession`, `startNewSessionKeepBreaks`, `setManualStartTime`, `setManualEndTime`, `clearEndTime`, `startOrStopBreak`, `deleteBreak`, `updateBreak`): erste Aktion gehalten (`holdSaves` bzw. `holdSaveOvertime`, je nachdem, ob die Aktion einen Saldo-Block hat), dieselbe Aktion ein zweites Mal -> `true`, unverändert viele ausstehende Writes (1). Jede Wrapper-Auslassung färbt genau ihre Zeile rot.
  - **B8 Ladelücke** (`holdReads = true` vor `boot()`): Start-Tap wartet in `_ensureCurrentDay`, `state.isSaving == true` und `isLoading == true`; zweiter Tap sofort `true` (Ergebnis liegt vor, bevor die Reads freigegeben sind); nach Freigabe genau ein Start-Write, State laufend (nicht gestoppt).
  - **B14 Profilwechsel**: (a) Stop in A gehalten (`holdSaveOvertime`), `switchProfile('B')`: `isSaving == false` (frischer State), sofort `startOrStopTimer` in B wird **nicht** verworfen (B: leerer oder laufender Eintrag, `workB.holdSaves` hält diesen Write); `A`-Hold freigeben -> A schreibt zu Ende (Bestand), `isSaving` bleibt `true` (Token von B), zweiter B-Tap ist weiterhin verworfen; nach B-Freigabe `isSaving == false`. (b) Wechsel mitten in einer Aktion: `build()` hat Flag zurückgesetzt, ein Start in B funktioniert sofort. **Hinweis:** Wenn Riverpod pro Rebuild eine neue Notifier-Instanz liefert, ist der `build()`-Reset redundant und Mutation M5 überlebt; dann im PR dokumentieren (Annahme aus 388-Research per Test bestätigen).
  - **B15 Tageswechsel**: (a) Mo-Abend (Uhr 23:59:50), leerer Eintrag, `h.clock.jumpTo(DateTime(2026,10,6,0,0,10))`, `holdReads = true`, Start-Tap: `_ensureCurrentDay` löst Reinit (`dayChange`) aus; mitten drin `state.isSaving == true` (vom `_init`-Konstruktor übernommen), zweiter Tap verworfen; nach Freigabe Start-Write am **Di** (`A:entry:2026-10-06:...`), `isSaving == false`. (b) Laufender Vortag (Seed Start 22:00, Uhr 23:00), Stop mit `holdSaveOvertime`, `jumpTo(Di 01:00)` + `tick`, Freigabe: Reinit auf Di, während des Reinit bleibt `isSaving` `true`, danach `false`, `periodicTimerCount == 0`. Alle Daten als `DateTime(...)`-Konstanten, keine `DateTime.now()`.
  - **B16 Rückgabe**: Aufruf nach `dispose()` (Container disposed) -> `false` ohne Wurf; `_ensureCurrentDay`-Abbruch (`failReads` in Platzhalter-Fall, Bestand `dashboard_view_model_switch_test` S-Tests) bleibt `false`.
  - **B17 `isSaving`-Verlauf**: `false` nach Boot; `true` im Fenster; `false` nach Erfolg, nach `false`-Ergebnis, nach Exception, nach Reinit, nach Profilwechsel.
  - **Rot-Nachweis (Pflicht):** Tests und `isSaving`-Stub (Schritt 1) vorhanden, VM noch unverändert -> `flutter test test/presentation/view_models/dashboard_view_model_busy_test.dart` ausführen. Erwartet rot: B1, B2, B4, B5, B6, B7 (alle Zeilen), B8, B14a, B15, B17 (Verlauf `true`); erwartet grün von Anfang an: B3(a), B16-Teil `_ensureCurrentDay`. Ausgabe (Namen der roten Tests + je ein Assertion-Auszug) in `413-pr.md` festhalten.
- [x] Impl: `_runAction` + Felder (`_busy`, `_actionToken`, `_actionDone`), `build()`-Reset, `onDispose` beendet `_actionDone`, neun Einzeiler/`_xxxBody`, `_load`-Konstruktor mit `isSaving: _busy`.
- [x] Grün: Busy-Suite (ohne B9-B13) und gesamte Bestandssuite.

### Schritt 3: Presentation — Autosave serialisieren, Timeouts
- [x] Test (zuerst, **Rot-Nachweis**), weiter in `dashboard_view_model_busy_test.dart`:
  - **B9a Autosave im Fenster übersprungen** (`running`, Uhr bei 17:00 fest, Stop mit `holdSaveOvertime`): `tick(31 s)` -> `h.work.log` enthält kein `save:`, `h.work.saved` leer.
  - **B9b Zähler bleibt erhalten**: wie B9a, dann `failSaveOvertime = true`, Freigabe (Stop scheitert, Timer läuft, `false`), danach `tick(1 s)` -> **genau ein** Autosave (`h.work.saved.length == 1`, laufender Eintrag), nicht erst 30 s später.
  - **B10 Aktion wartet auf Autosave**: `running` (Beginn 17:00), `holdSaves = true`, `tick(30 s)` -> `pendingSaves == 1` (Autosave), dann `holdSaves = false` (der Autosave-Completer bleibt offen), nach `tick(2 s)` Stop-Tap: `saveOvertimeCalls == 0`, `writeLog` leer. Autosave-Completer beenden -> `writeLog.first == 'A:entry:<moKey>:08:00--'`, genau ein `A:overtime`, dessen Index **nach** dem Autosave-Eintrag liegt. Werte der Stop-Zeit nicht assertieren (Uhr läuft mit, Rundung), nur Struktur/Reihenfolge. Rot heute: Saldo-Write vor Autosave-Ende.
  - **B11-T1 Saldo-Timeout** (`running`, `holdSaveOvertime`): Stop; `tick(29 s)`: Ergebnis offen, `isSaving == true`, zweiter Tap verworfen; `tick(1 s)` (= 30 s): Ergebnis `false`, `isSaving == false`, State laufend, `periodicTimerCount == 1`, `writeLog` leer. Spät landender Saldo (Completer jetzt beenden): `A:overtime:<n>` erscheint (nicht abbrechbar), aber **kein** `A:lastUpdate`, **kein** Eintrag-Write, State unverändert (`timedOut`-Guard). Wiederholter Stop (ohne Hold) schreibt vollständig (`saveOvertimeCalls == 2`, danach `A:lastUpdate` und Eintrag). Der Log-Test aus `save_error_test` ("ohne Eintragsinhalte") wird für den Timeout-Fall wiederholt (Level error, enthält `TimeoutException`, enthält keinen `2026-10-05`).
  - **B11-T2 Eintrag-Timeout beim Stop** (`holdSaves`): Saldo geschrieben, State beendet, Eintrag-Write hängt; `tick(30 s)` -> Ergebnis `true` (PR-1-Verhalten, #336 unverändert), `workEnd` im State gesetzt, `periodicTimerCount == 0`, `isSaving == false`, kein Reinit-Schritt. Der Testname trägt den Zusatz "(PR 2 ändert dies)". Freigabe des Completers danach.
  - **B11-T3 Autosave-Timeout**: `holdSaves`, `tick(30 s)` -> Autosave hängt; Stop-Tap bei +35 s wartet; bei +60 s (Timeout) läuft der Stop weiter: `writeLog` ohne Autosave-Eintrag, danach `stopWrites`-Struktur. Rot heute (ohne Timeout) hängt der Stop bis zum Testende.
  - **B11-T4 Grenze exakt 30 s**: in T1 (29 s noch busy, 30 s frei); deckt Konstante ab.
  - **Rot-Nachweis:** B9a, B9b, B10, B11-T1..T3 rot gegen den Stand nach Schritt 2; Ausgaben in `413-pr.md`.
- [x] Impl: `_autoSaveRun`, Tick-Logik, `_autoSave` mit Timeout, Saldo-/Eintrag-Timeout in `_recalculateStateAndSave`, Autosave-Wait im Wrapper.
- [x] Grün: gesamte Suite; Bestandstests mit gehaltenen, nie freigegebenen Writes prüfen (siehe "Bestandstests").

### Schritt 4: Presentation — `stopRunningForSwitch`, `resumePastEntry`
- [x] Test (zuerst, **Rot-Nachweis**):
  - **B12a** (`dashboard_view_model_switch_test.dart`): laufender Stop (`holdSaveOvertime`) + `stopRunningForSwitch('default')` -> noch offen, `writeLog` leer; Freigabe -> Ergebnis `true`, `stopWrites` genau einmal (`saveOvertimeCalls == 1`). Rot heute: zweiter Saldo-Write bzw. Ergebnis `false`.
  - **B12b**: laufende Pause (`startOrStopBreak` mit `holdSaves`, vor Freigabe `holdSaves=false`): Switch wartet, stoppt danach, `true`, `!isTimerRunning`.
  - **B12c** wartender Switch + Profilwechsel: `switchProfile('B')` beendet den Completer (`onDispose`), Ergebnis `false` (Profil != from), keine B-Writes, kein Hängen.
  - **B12d** Bestandsszenarien S1-S9 bleiben unverändert grün (kein Anpassungsbedarf erwartet).
  - **B13a** (`dashboard_view_model_resume_test.dart`, `satMorning`, `friOpen()` geseedet): Start-Tap in der Ladelücke (`holdReads`, vor `boot()`), danach `resumePastEntry(friOpen())` -> Ergebnis `false` **bevor** Reads freigegeben sind; `pendingReads` wächst nicht (kein Pin-Read); nach Freigabe läuft Sa, Fr nicht gepinnt. (Deckt Prüfung (1).)
  - **B13b**: erst `resumePastEntry` (wartet auf Ladelauf), dann Start-Tap im Fenster; nach Freigabe `false`, Start läuft auf Sa, kein Pin. (Deckt Prüfung (2); Reihenfolge der Microtasks beim Schreiben des Tests per Debug-Lauf verifizieren.)
  - **B13c**: Bestand "Tap in der Ladelücke wartet auf den Pin und stoppt dann" und "gleichzeitiger Doppelaufruf ... ein Pin" bleiben unverändert.
  - **Rot-Nachweis:** B12a, B12c (hängt/falsch), B13a, B13b rot.
- [x] Impl: `stopRunningForSwitch` (Wait-Schleife, kein `await` zwischen Schleife und `startOrStopTimer()`), `resumePastEntry` (Doppelprüfung).
- [x] Grün: Suite.

### Schritt 5: Presentation — UI
- [x] Test (zuerst, **Rot-Nachweis**):
  - `dashboard_screen_save_error_test.dart` (echtes VM mit Fakes, `profiles`-fähiges Harness bzw. dortiges Muster; `locale: Locale('de')`, plus en-Lauf): Tap auf Start/Stop mit `holdSaves` -> `pump()`; Start/Stop-Button und Pausen-Button haben `onPressed == null`; weiterer Tap bleibt ohne Wirkung (`pendingSaves == 1`), **kein** `dashboardSaveError`-Snackbar; nach Freigabe sind die Buttons wieder aktiv. Entsprechend: Pause-löschen-Icon und Zeitfelder (`enabled == false`).
  - `edit_break_modal_test.dart`: State mit `isSaving: true` -> "Speichern" deaktiviert, "Abbrechen" aktiv.
  - Rot: Buttons sind heute aktiv.
- [x] Impl: `dashboard_screen.dart` (`final isSaving = dashboardState.isSaving;`, `onPressed: isSaving ? null : ...`; `_TimeInputField(enabled: !isSaving ...)` bzw. `workEntry.workStart != null && !isSaving` fürs Endefeld; Löschen-Icon; auch in `_showRestartDialog`-Pfaden nichts ändern, der VM-Guard greift). `edit_break_modal.dart`: `ref.watch(dashboardViewModelProvider.select((s) => s.isSaving))` für den Speichern-Button.
- [x] Grün: Screen-Tests, die `DashboardScreen` pumpen (Fakes mit überschriebenem `build()`) bleiben unverändert grün (Default `false`).

### Schritt 6: Doku, Checks, Mutationsproben
- [x] `mobile/CLAUDE.md`: neuer Abschnitt "Reentranz-Sperre (#413)" (Wrapper, Token, Verwerfen = `true`, Autosave-Regeln, Timeout-Verhalten pro Write, `isSaving`, `stopRunningForSwitch`/`resumePastEntry`, Tests); im #402-Abschnitt Grenze (2) streichen und auf den neuen Abschnitt verweisen (Grenze (1) und (3) bleiben bis PR 2); in #388 Satz "Neue Schreibaktionen müssen `_beginAction()` aufrufen" um "und über `_runAction` laufen" ergänzen; Testliste um `dashboard_view_model_busy_test`.
- [x] Checks (aus `mobile/`): `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-fatal-infos`, `dart run custom_lint`, `flutter test`. Neue/geänderte Testdateien zusätzlich unter `TZ=UTC`, `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland` (CI läuft in Europe/Berlin). `flutter gen-l10n`/`build_runner` nicht nötig (kein ARB-/Provider-Change).
- [x] Mutationsproben (jeweils Mutation einbauen, Zieltest muss rot werden, zurücknehmen; Ergebnisse in `413-pr.md`):
  | # | Mutation | Erwartet rot |
  |---|---|---|
  | M1 | Verwerfen-Zweig in `_runAction` entfernen | B1, B2, B4-B7 |
  | M2 | Flag erst nach `_ensureCurrentDay` setzen (nicht synchron) | B8 |
  | M3 | Freigabe im `finally` entfernen | B3, B2 (Folge-Aufruf) |
  | M4 | Token-Vergleich im `finally` entfernen | B14a |
  | M5 | Reset in `build()` entfernen | B14b (kann überleben, falls neue Instanz je Rebuild, dann dokumentieren) |
  | M6 | `ref.mounted`-Guard im `finally` entfernen | Bestand `profile_test` "Logout/Dispose: begonnene Aktion schreibt zu Ende" und "Dispose: scheiternder Write ..." (Bad state nach Dispose) |
  | M7 | Autosave-Skip bei `_busy` entfernen | B9a |
  | M8 | Autosave-Wait im Wrapper entfernen | B10 |
  | M9 | `_tickCounter` beim Überspringen zurücksetzen | B9b |
  | M10 | Autosave-Timeout entfernen | B11-T3 |
  | M11 | Saldo-Timeout entfernen | B11-T1 |
  | M12 | Eintrag-Timeout (Aktion) entfernen | B11-T2 |
  | M13 | `timedOut`-Guard in der Saldo-Closure entfernen | B11-T1 (spätes `A:lastUpdate`) |
  | M14 | Timeout 30 s -> 31 s / 29 s | B11-T1 (Grenze) |
  | M15 | Warte-Schleife in `stopRunningForSwitch` entfernen | B12a, B12b |
  | M16 | `onDispose`-Completer nicht beenden | B12c (hängt) |
  | M17 | `resumePastEntry`-Prüfung (1) entfernen | B13a |
  | M18 | `resumePastEntry`-Prüfung (2) entfernen | B13b |
  | M19 | `isSaving: _busy` im `_load`-Konstruktor entfernen | B15, B17 |
  | M20 | Verworfen liefert `false` statt `true` | B1, Widget-Test (Snackbar) |
  | M21 | Einen einzelnen Wrapper (je Aktion) weglassen | die zugehörige Zeile in B7 |
  | M22 | `onPressed` im Screen nicht deaktivieren | Widget-Tests Schritt 5 |
  | M23 (äquivalent) | `_autoSaveRun != null`-Guard im Tick entfernen | **nicht erkennbar**: Autosave-Timeout (30 s) = Autosave-Intervall, ein Überlappen ist nicht erreichbar. Guard bleibt als Verteidigung, Ergebnis als "äquivalent" dokumentieren, nicht jagen. |

## Bestandstests
Erwartet **keine** zwingende Anpassung. Einzeln geprüft:
- `dashboard_view_model_save_error_test`: S-1..S-7, S-10 starten nacheinander Aktionen mit Flush dazwischen oder geben Holds frei, bleiben grün. "Eintrag-Write scheitert nach Saldo: bleibt true (#412 offen)" bleibt unverändert (gehört PR 2).
- `dashboard_view_model_profile_test` (T1/T2/T6/O1/O4): Wechsel mitten in der Aktion, Aktion schreibt zu Ende, kein Flag-Konflikt (Token). O1 "Logout/Dispose" dient als Wächter für den `ref.mounted`-Guard im `finally`.
- `dashboard_view_model_resume_test`: "Tap in der Ladelücke wartet auf den Pin" bleibt (Prüfung (2) liegt vor dem Tap); "doppelter Aufruf: zweiter liefert false" unverändert.
- `dashboard_view_model_switch_test`: S1-S9 unverändert.
- `dashboard_view_model_day_change_test`, `_reload_test`, `_break_test`, `_overtime_test`, `dashboard_view_model_test`: unverändert.
- **Einzige realistische Zwangsanpassung (nur falls auftretend):** Tests, die einen Write per Hold offen lassen und das Szenario beenden, ohne ihn freizugeben, scheitern künftig am Timer-Leak-Check (`nonPeriodicTimerCount`, Timeout-Timer). Dann im Test den Completer freigeben; im PR einzeln benennen. Ebenso jeder Test, der absichtlich zwei Aktionen überlappen lässt und die zweite ausgeführt erwartet (bisher keiner gefunden): wäre ein Befund, kein Anpassungsfall, vorher mit Hauptsession klären.
- Fakes, die `DashboardViewModel` überschreiben (Screen-/Modal-Tests), bleiben kompatibel (öffentliche Signaturen unverändert).

## Bekannte Grenzen (in CLAUDE.md und PR festhalten)
1. Timeout deckt `_ensureCurrentDay`-Lesezugriffe und `toggleBreak.call` nicht ab; ein dort hängender Lesezugriff blockiert wie bisher, jetzt aber ohne queued Taps (Folge-Taps werden verworfen).
2. Ein per Timeout "abgebrochener" Write ist nicht abbrechbar und kann später landen (unbekannter Ausgang); Wiederholen/Autosave überschreibt.
3. Ein in der Zeit zwischen Tap und Aktionsbeginn verworfener Tap ist für den Nutzer nur an deaktivierten Buttons erkennbar (kein Hinweis, Entscheidung E4).
4. Teilfehler Saldo/Eintrag (#412) und Reihenfolge bleiben bis PR 2 unverändert, der Timeout im Eintrag-Write verhält sich wie ein Eintrag-Fehler (#336).
5. Web hat keine Reentranz-Sperre (Folge-Issue, nicht Teil).

## Validierung
- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze --no-fatal-infos`
- `dart run custom_lint`
- `flutter test` (gesamt) sowie die neuen/geänderten Dateien unter `TZ=UTC`, `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland`
- Rot-Nachweise je Schritt 2-5 und Mutationsproben M1-M23 in `mobile/thoughts/413-pr.md`
