# Mobile-Research: #402 und #410 — Teilfehler beim Saldo-Write (Stop-Pfad, nachträgliches Beenden)
Datum: 2026-10-04
Typ: Bug-Analyse (zwei Folge-Issues zu #388 bzw. #385). Kein Code geändert. Branch `claude/week-number-display-bug-x5xq8r` (auf `develop`, `2ebbaa5`).

## Aufgabe

**#402** (Label `bug`, keine Kommentare): Im Stop-Pfad des `DashboardViewModel` (`startOrStopTimer`) wird `_timer` vor `saveOvertime` abgebrochen. Wirft `saveOvertime`: Exception ungefangen beim Aufrufer, `periodicTimerCount == 0`, State `workStart != null && workEnd == null` ("läuft" ohne Timer), kein Eintrag-Write. Erwartet: konsistenter Zustand (Timer läuft weiter, Fehler behandelt/geloggt/angezeigt) **oder** zuerst speichern, dann Timer abbrechen. Mit Test (FakeClock, feste Daten, auch `TZ=Europe/Berlin`). Web-Gegenstück: #394.

**#410** (Label `bug`, keine Kommentare): `CloseOpenWorkEntry` schreibt erst den Saldo (Delta), dann den Eintrag. Scheitert der Eintrag-Write, bleibt der Saldo verschoben, der Eintrag offen, ein Wiederholen zählt das Delta doppelt. Erwartet: Saldo best-effort zurückschreiben (`keepLastUpdated: true`, #406) oder Reihenfolge/Idempotenz so, dass Wiederholen nicht doppelt zählt. Test mit `FakeOvertimeRepository`/`failSave`-Fake, feste Daten, auch unter `TZ=Europe/Berlin`. Web hat den Rollback bereits (PR #409).

Nicht Teil: Bestätigungsdialog "Beenden und wechseln" (#388 PR 2), Web-Änderungen (#394), Reports-Darstellung offener Einträge (#404), Heuristik `lastUpdated == heute` in `_load` ersetzen, Reparatur bereits verfälschter Daten.

## Betroffene Dateien

| Datei | Warum |
|---|---|
| `mobile/lib/presentation/view_models/dashboard_view_model.dart` | Stop-Pfad Z. 494-531 (`_timer?.cancel()` in Z. 506), `_recalculateStateAndSave` Z. 581-697 (Saldo-Block Z. 614-635, Eintrag-Write Z. 662-677), `_startTimerIfNeeded` Z. 319 (bricht beide Timer ab), `_ActionCtx`/`_beginAction` Z. 29/242 |
| `mobile/lib/presentation/screens/dashboard_screen.dart` | Aufrufer ohne `await`/Fehlerbehandlung: Stop/Start Z. 152, manuelle Zeiten Z. 126/139, Pause Z. 172, Pause löschen Z. 374, Neue Session Z. 399/406; Ort für ein Snackbar |
| `mobile/lib/presentation/widgets/edit_break_modal.dart` (Z. 126) | weiterer Aufrufer `updateBreak` |
| `mobile/lib/domain/usecases/close_open_work_entry.dart` | #410: Saldo-Write Z. ~79, Eintrag-Write danach, `catch` liefert `failed` |
| `mobile/lib/presentation/view_models/open_entry_view_model.dart` (Z. 180-225) | Aufrufer von `CloseOpenWorkEntry` (Banner bleibt bei `failed`, `saveError`, wiederholbar) |
| `mobile/lib/data/repositories/firebase_overtime_repository_impl.dart`, `hybrid_*`, `local_overtime_repository_impl.dart`, `data/datasources/remote/api_client.dart` | `saveOvertime(..., keepLastUpdated)`: Backend setzt `lastUpdated` bei jedem PUT, außer mit `keepLastUpdated: true`; Firebase-Repo setzt den Cache **vor** dem Write |
| `mobile/test/support/fake_repositories.dart` | `failSaveOvertime` (bool, alle Aufrufe), `holdSaveOvertime`, `failSaves`, `holdSaves`, `serverNow`, `savedKeepLastUpdated`; für #410 fehlt "n-ten Aufruf scheitern lassen" |
| `mobile/test/support/dashboard_harness.dart` | `scenario`, `act`, `tick`, `switchProfile`, `writeLog`, `profiles: true` |
| `mobile/test/domain/usecases/close_open_work_entry_test.dart` (Z. 326-370) | bestehende Fehlerpfade; `Entry-Save schlägt nach Saldo fehl ... Rest-Risiko` erwartet heute `savedOvertimes hasLength(1)` |
| `mobile/test/presentation/view_models/dashboard_view_model_profile_test.dart` (Z. 341-390) | O1-Tests: `ohne Ueberholung: Saldo-Fehler wird weitergereicht` pinnt das Rethrow (siehe unten) |
| `mobile/test/presentation/view_models/open_entry_view_model_test.dart` (Z. 247-285) | Fehler/Wiederholen beim Beenden |
| `mobile/lib/l10n/app_de.arb` / `app_en.arb` | nur #402, falls Snackbar (neuer Key, bestehend: `openEntrySaveError`) |
| `mobile/CLAUDE.md` (Abschnitte #388 Grenze (3), #385 "Beenden"), `web/CLAUDE.md` Z. ~207 ("Abweichung zu Mobile: ... Rollback") | Doku nachziehen |

## Datenfluss

Stop heute: `DashboardScreen` (Button) -> `startOrStopTimer()` (ohne `await`) -> `_ensureCurrentDay` -> `_beginAction` (`_ActionCtx`) -> **`_timer?.cancel()`** -> `_recalculateStateAndSave(ctx)` -> `ctx.overtimeRepository.saveOvertime(total)` -> `saveLastUpdateDate(now)` -> `_checkOvertimeWarning` -> `state = ...` -> `ctx.saveWorkEntry(entry)` (Fehler geschluckt, #336) -> `_startTimerIfNeeded()` (bricht Timer/Autosave ab, startet nur bei laufendem Eintrag).
Beenden (#385): `OpenEntryBanner` -> `OpenEntryViewModel.endEntry` -> `CloseOpenWorkEntry` -> `getWorkEntriesForMonth` (frisch) -> `ensureOvertimeLoaded` -> `saveOvertime(stored + net - soll, keepLastUpdated: true)` -> `saveWorkEntry` -> `closed`/`failed`.
Eingeloggt gehen beide Saldo-Writes über `PUT /api/overtime?profileId=` (auch zusätzliche Profile), ausgeloggt SharedPreferences.

## 1. #402 Stop-Pfad: Ist-Zustand und Ursache

Alle Aussagen aus dem Code gelesen; das Fehlerbild stammt aus der Probe in #388 (im Issue beschrieben, hier nicht erneut ausgeführt).

**Ursache:** Z. 506 `_timer?.cancel()` steht vor dem ersten Write. Der Saldo-Block (Z. 619-634) rethrowt bei nicht überholter Aktion. Der State wird erst nach dem Saldo-Block gesetzt (Z. 651), also bleibt er bei Fehler "läuft", der Timer ist aber weg. Autosave läuft ebenfalls nur im `_timer` (Tick 30), ist also auch tot: der Eintrag wird bis zur nächsten Aktion nicht mehr gespeichert (der zuletzt gespeicherte Stand bleibt aber vom letzten Autosave vorhanden).

**Wichtige Eingrenzung: nur der Stop-Pfad cancelt früh.** Die anderen Aktionen mit abgeschlossenem Eintrag laufen alle durch denselben Saldo-Block, setzen den State aber erst danach und fassen den Timer nicht an:
- `setManualEndTime` auf **laufendem** Eintrag: bei `saveOvertime`-Fehler bleibt State und Timer unverändert (konsistent), nur die Exception geht ungefangen an den Aufrufer.
- `setManualStartTime`, `updateBreak`, `deleteBreak`, `startOrStopBreak` auf beendetem Eintrag: State unverändert, Exception ungefangen.
- `startOrStopTimer` (Start), `startNewSession*`, `clearEndTime`, Pause auf laufendem Eintrag: kein Saldo-Write (`workEnd == null`), betroffen ist nur der Eintrag-Write, den #336 schluckt.

**Ungefangene Exception ist doppelt schlecht:** Die UI ruft `startOrStopTimer()` & Co. fire-and-forget; die Exception landet in `PlatformDispatcher.instance.onError` und wird in `main.dart` als **fatal** an Crashlytics gemeldet (Z. 57-58). Ein einfacher Netzfehler beim Stop erzeugt also einen "Absturz"-Eintrag, ohne dass der Nutzer etwas sieht. Genau deshalb wurde der Eintrag-Write in #336 abgefangen, der Saldo-Write seinerzeit vergessen.

**Teilfehler-Matrix Stop-Pfad** (Reihenfolge S1 `saveOvertime`, S2 `saveLastUpdateDate`, S3 Warnung (intern gefangen), S4 `saveWorkEntry`):

| Fehler bei | Zustand im Speicher | Heute | Bewertung |
|---|---|---|---|
| S1 | nichts geschrieben | Timer weg, Exception (#402) | sauber lösbar: nichts zurückzurollen |
| S2 (lokal praktisch nie; Cloud: `saveLastOvertimeUpdate` ist No-op) | Saldo neu, Eintrag offen | wie S1, aber Saldo schon verschoben | Teilfehler, siehe unten |
| S4 | Saldo neu (und Backend-`lastUpdated` = heute), Eintrag offen | **geschluckt**: UI zeigt "gestoppt", `_startTimerIfNeeded` hat Timer/Autosave abgebrochen, der Eintrag wird nie mehr geschrieben | stiller Teilfehler, **heute schon aktiv** und unabhängig von #402 |

Folge von S4 (aus dem Code abgeleitet, nicht per Test belegt): Der Eintrag liegt offen im Backend, der Saldo enthält den Tag schon. Nach Mitternacht oder Neustart erscheint der Eintrag im Banner (#385); "Beenden" addiert das Delta **ein zweites Mal** (`CloseOpenWorkEntry` rechnet inkrementell). Das ist dieselbe Fehlerklasse wie #410, nur über den Dashboard-Stop erreicht.

### 1.1 Warum ein Saldo-Rollback im Dashboard-Stop **nicht** tragfähig ist (neuer Befund)

Der Stop-Pfad schreibt den Saldo **ohne** `keepLastUpdated` (er braucht `lastUpdated = heute`, sonst zählt `_load` nach einem Reload den Tag doppelt: Basis = `stored`, Total = `stored + daily`). Eingeloggt setzt das Backend `lastUpdated` bei diesem PUT, und es gibt keinen Weg, den alten Wert wieder zu setzen (`ApiDataSource.saveLastOvertimeUpdate` ist No-op, Löschen auf `null` nicht möglich). Ein Rollback `saveOvertime(prev, keepLastUpdated: true)` stellt also `stored`, aber nicht `lastUpdated` her. Dann passt die Heuristik in `_load` (Zweig `isSameDay(lastUpdate, now)`: `Basis = stored - dailyNow`) nicht mehr zum Saldo:

- Rechenbeispiel (Soll 8 h, Start 08:00, fehlgeschlagener Stop 12:00, Reload 12:10): `dailyStop = -4 h`, `dailyLoad = -3 h 50`. Ohne Rollback: `stored = prev - 4 h`, Fehler beim späteren Stop `dailyStop - dailyLoad = -10 min`. Mit Rollback: `stored = prev`, Fehler `-dailyLoad = +3 h 50`. Der Rollback macht es hier **schlimmer** als das Liegenlassen.

Daraus folgt: Ein Saldo-Rollback ist nur dort sauber, wo `lastUpdated` nie angefasst wird (#410, `keepLastUpdated: true` im Vorwärts-Write). Im Dashboard-Stop gilt das nicht.

### 1.2 Wie das Web es macht (Vorlage, Abweichung)

- `DashboardService._recalculateState` schreibt **Eintrag zuerst, dann Saldo** (`saveEntry`, danach `_saveOvertime` = `saveOvertime` + `saveLastUpdateDate`). Umgekehrte Reihenfolge wie Mobile.
- `stopRunningTimerForSwitch` (Profilwechsel-Guard) macht bei Fehler einen **State-Snapshot-Rollback** (`_s.set(snapshot)`, `_startTimerIfNeeded()`), keinen Saldo-Rollback. Scheitert der Saldo nach dem Eintrag, liegt der Eintrag beendet vor; der nächste Autosave schreibt ihn wieder laufend (Test "Saldo schlägt fehl ... nächster Autosave überschreibt den Eintrag wieder laufend", dort als "Rest" markiert). Scheitert der Eintrag, wird kein Saldo geschrieben: nichts zurückzurollen.
- Einen **Saldo**-Rollback gibt es im Web nur in `OpenEntryCloseService` (= #410-Vorlage).
- Der Web-Stop-Button (`_stopRunning`) hat keine Fehlerbehandlung (`stopRunningTimerForSwitch` fängt, `startOrStopTimer` nicht); das ist #394.

Antwort auf "Rollback wie Web?": Für **#410 ja** (Web-Vorbild 1:1). Für den **Dashboard-Stop nein**: dort rollt das Web den State zurück und löst das Saldo-Problem über die Reihenfolge Eintrag, dann Saldo, nicht über einen Saldo-Rollback.

### 1.3 Optionen für #402

| Option | Inhalt | Wirkung | Aufwand/Risiko |
|---|---|---|---|
| **A (empfohlen)** | `_timer?.cancel()` in Z. 506 **entfernen** (der Timer wird in `_startTimerIfNeeded` nach erfolgreichem Setzen des States ohnehin abgebrochen). Saldo-Block: `catch` für **alle** Fälle loggen (`logger.e` ohne Eintragsinhalte) und die Aktion mit Fehlerergebnis beenden, **vor** jedem `state =`/Timer-Eingriff. Ergebnis an den Aufrufer (`Future<bool>`), UI zeigt Snackbar | S1: nichts geschrieben, State und Timer unverändert, Wiederholen gelingt (Saldo ist absolut: `base + daily`, also idempotent). Gilt einheitlich für alle Aktionen mit Saldo-Block. Kein Crashlytics-Fatal mehr | klein im VM (ca. 15 Zeilen), `Future<void>` -> `Future<bool>` an 9 Aktionen, ein ARB-Key, Snackbar im Screen. Mittleres Risiko nur wegen des zentralen Pfads |
| B | Early-Cancel behalten, bei Fehler `_startTimerIfNeeded()` aufrufen | funktional ähnlich | Restart setzt `_tickCounter`, überschreibt State, fängt andere Wurfstellen vor dem Block nur zufällig; A ist robuster (kein Zustand, der zurückgesetzt werden muss) |
| C | Reihenfolge wie Web (Eintrag, dann Saldo) | löst auch S4/S2 sauber (Fehler beim ersten Write: nichts geschrieben, State zurück) | größter Eingriff: ändert die Write-Reihenfolge **aller** Aktionen, verändert viele Bestandstests (`writeLog`-Reihenfolgen in den #388-Tests `A:overtime:135, A:lastUpdate, A:entry:...`, T1/T2, O1), widerspricht Entscheidung 2 aus #388 ("Reihenfolge Saldo/Eintrag beibehalten"). Nicht in diesen PR; als Folge-Issue prüfen |
| D | State-Snapshot-Rollback nach dem Fehler (wie Web) | wäre für S4 nötig | bei Option A für S1 unnötig, weil der State vor dem ersten Write nie angefasst wird |

**Empfehlung A.** S2/S4 bleiben ein dokumentierter Rest (siehe 1.1; Option C als Folge-Issue). Die Variante "zuerst speichern, dann Timer abbrechen" aus dem Issue ist mit A erfüllt: der Timer wird erst nach dem Setzen des States abgebrochen.

### 1.4 Wirkung von Option A auf Nachbarn

- **Timer-Ticks im Schreibfenster:** Ohne Early-Cancel tickt der Timer während der Saldo-Awaits weiter (State noch "laufend", Ticks korrekt). Nach dem Setzen des States (Eintrag beendet) und vor `_startTimerIfNeeded()` (während des Eintrag-Writes) tickt er weiter, rechnet aber seit #386 mit `workEnd` (`_calculationEnd`), das Ergebnis ist stabil. Auto-Save im Fenster (Tick 30) schreibt dann den **beendeten** Eintrag zusätzlich: harmlos (derselbe Stand). Ein Tick holt über `todayProvider.refresh()` einen verpassten Mitternachtswechsel nach; `_onDayChange` ignoriert nur *laufende* Einträge, in diesem Fenster ist der State schon beendet, also kann ein Reinit mit `dayChange: true` mitten in den Eintrag-Write laufen. Das Fenster ist schon heute vorhanden (der Mitternachts-Timer von `todayProvider` bleibt aktiv); durch Option A kommt nur der Standby-Nachholpfad hinzu. Im Plan mit einem Test absichern (Tick im Fenster).
- **Manuelle Endzeit (`setManualEndTime`):** unverändert gut: Timer läuft bei Fehler weiter. Neu: kein Wurf, Snackbar.
- **Pausen (`startOrStopBreak`, `deleteBreak`, `updateBreak`):** nur bei beendetem Eintrag mit Saldo-Write betroffen; State bleibt wie vor der Aktion, kein Wurf.
- **`startNewSession`/`startNewSessionKeepBreaks`:** `workEnd == null`, kein Saldo-Block. Eintrag-Write-Fehler bleiben geschluckt (#336). Nicht Teil von #402.
- **Autosave (`_autoSave`):** schreibt `state.workEntry`; bei S1-Fehler läuft der Timer weiter, der Autosave schreibt nach 30 s wieder den laufenden Eintrag (unverändert gut). Der Autosave selbst fängt Fehler schon (Z. 389).
- **Überholung/Dispose (#388, O1):** Die Regel "Fehler nur bei überholten Aktionen schlucken" entfällt: Künftig wird **immer** geloggt und mit Fehlerergebnis beendet (Vereinfachung, ein Zweig weniger). Überholte Aktionen liefern das Ergebnis an niemanden, mehr ändert sich nicht (kein State, kein Timer, kein Reinit; der Eintrag-Write wird bei Fehler im Saldo nicht versucht, wie heute). Die Tests O1 "Dispose: scheiternder Write wird geschluckt" und O4 bleiben grün. **Der Bestandstest `ohne Ueberholung: Saldo-Fehler wird weitergereicht` (profile_test Z. 349) pinnt das Rethrow und muss umgeschrieben werden** (Erwartung: kein Wurf, `false`, State/Timer unverändert, nichts geschrieben). Das ist eine bewusste Änderung eines Bestandstests und im PR zu benennen; seine Kommentarzeile "Fehlerbehandlung ein eigenes Thema" verweist ohnehin auf #402. Die dort erwähnte Mutation "immer schlucken" entfällt mit der Regel.
- **Doppeltippen:** Es gibt im Dashboard keine Reentranz-Sperre (anders als `OpenEntryViewModel.busy`). Zweiter Stop im Schreibfenster sieht den State noch "laufend" und schreibt ein zweites Mal (andere Minute möglich). Besteht schon heute, nicht Teil von #402; im PR als bekannte Grenze erwähnen.

### 1.5 UX bei Fehler (Frage: Fehlermeldung? bestehendes Muster?)

Bestehendes Muster: Aktionen mit Nutzerfeedback melden das Ergebnis an die UI, die ein Snackbar mit lokalisiertem Text zeigt (`OpenEntryBanner._end` mit `openEntrySaveError`, `work_profile_switcher`, `manage_work_profiles_dialog`, Reports/Settings). ViewModels loggen mit `logger.e` (Crashlytics), kein Snackbar im VM (kein Context). Das Dashboard hat bisher gar kein Fehlerfeedback; Eintrag-Fehler werden geschluckt.

Empfehlung: `Future<bool>` als Rückgabe (true = ok oder nichts zu tun, false = Speichern gescheitert), Snackbar im `DashboardScreen` an den Stellen, an denen ein Nutzer eine Aktion auslöst und das Ergebnis sieht (Start/Stop-Button, manuelle Start-/Endzeit, Pause, Pause löschen, Neue Session; `edit_break_modal` ignoriert den Rückgabewert oder zeigt dasselbe Snackbar). Neuer ARB-Key (de, duzend, `@key`-Beschreibung, en parallel), z. B. `dashboardSaveError`: "Speichern fehlgeschlagen. Bitte prüfe deine Verbindung und versuche es erneut." / "Saving failed. Please check your connection and try again." Alternative: einmaliges Fehlerflag im `DashboardState` (wie `OpenEntryState.saveError`), das die UI per `ref.listen` anzeigt: einheitlich für alle Aufrufer, aber mehr Zustand und ein Quittieren. Tests rufen `h.act(h.vm.startOrStopTimer)` (`Future<void> Function()`); `Future<bool> Function()` ist dort zuweisbar, keine Testumbauten nötig.

## 2. #410 `CloseOpenWorkEntry`

**Ist:** `call` validiert, liest frisch, schließt Pausen, wendet Auto-Pausen an, liest `stored = ensureOvertimeLoaded()`, `saveOvertime(stored + net - soll, keepLastUpdated: true)`, dann `saveWorkEntry(closed)`. Alles in einem `try`, jede Exception wird zu `failed` (nur geloggt). Scheitert der Eintrag-Write, bleibt der Saldo um das Delta verschoben, der Eintrag offen und der Banner sichtbar; "Beenden" erneut liest `stored` (jetzt inkl. Delta) und addiert es nochmal. Der Bestandstest `Entry-Save schlägt nach Saldo fehl: failed (Rest-Risiko Teilfehler)` erwartet `savedOvertimes hasLength(1)`.

**Warum hier der Rollback sauber ist:** Das Delta ist **inkrementell** (nicht idempotent wie der absolute Dashboard-Saldo), und `lastUpdated` wird nie angefasst (`keepLastUpdated: true`, lokal ohnehin nie geschrieben). Der Rückschreibwert `stored` ist der Stand, den dieser Aufruf kurz vorher gelesen hat; mit `keepLastUpdated: true` stellt der Rollback damit den Vorzustand **vollständig** her (Saldo und `lastUpdated`). Eine ältere API ohne #408 setzt `lastUpdated` weiterhin bei beiden Writes (bekannte Grenze, #406).

**Soll-Ablauf (Web-Vorbild `OpenEntryCloseService._end`):**
1. Saldo schreiben (außerhalb des Rollback-`try`: scheitert er, ist nichts geschrieben, kein Rollback).
2. Eintrag schreiben; bei Fehler: best-effort `saveOvertime(stored, keepLastUpdated: true)` in eigenem `try`; scheitert der Rollback, `logger.e` (nur `runtimeType`, keine Eintragsinhalte), nie weiterwerfen; Ergebnis `failed`.
3. Erfolgreicher Pfad, `alreadyClosed`, `invalidEnd`, `invalidEntry` unverändert (keine zusätzlichen Writes).

**Idempotenz beim Wiederholen:**
- Rollback gelungen: Eintrag offen, Saldo wie vorher; Wiederholen liest frisch und rechnet korrekt (kein Doppelzählen). Das ist der Zweck.
- Rollback gescheitert: Saldo bleibt inkl. Delta, Wiederholen zählt doppelt. Nicht lösbar ohne zusätzliche Persistenz (Marker) oder umgekehrte Reihenfolge (Eintrag zuerst würde bei Saldo-Fehler das Delta **verlieren**, denn danach ist der Eintrag `alreadyClosed`: stiller Unterzähler, schlechter). Web akzeptiert dasselbe (Kommentar "Nutzer korrigiert über Überstunden anpassen"). Bekannte Grenze, dokumentieren.
- Unklarer Ausgang des Vorwärts-Saldo-Writes (Timeout, aber serverseitig angewendet): kein Rollback (Parität zum Web, wir wissen es nicht). Optional wäre ein Rollback auch bei Fehler des ersten Writes möglich (absoluter Wert `stored`, bei nicht angewendetem Write wirkungslos, kostet bei Offline einen zweiten fehlschlagenden Request). Empfehlung: nicht in diesem PR (siehe Frage 4).
- Parallelnutzung (zweites Gerät schreibt dazwischen den Saldo): der absolute Rollback überschreibt dessen Wert; extrem selten, gleiche Grenze wie Web.

**`alreadyClosed`:** liefert vor dem ersten Write, keine Rollback-Fragen. Ein Rollback-Schreibzugriff darf in diesem Pfad **nie** auftreten (Test).

**Firebase-Cache (Nebenbefund, kein Fix nötig):** `FirebaseOvertimeRepositoryImpl.saveOvertime` setzt `_cachedOvertime` vor dem Netzwerk-Write. Nach einem fehlgeschlagenen Write steht der ungeschriebene Wert im Cache. In `lib/` liest nur `DataSyncService` den synchronen `getOvertime()`; die Dashboard-/Beenden-Pfade laden per `ensureOvertimeLoaded()` frisch. Wirkung für #402/#410 daher nicht erkennbar. Wer den Rollback-Wert aus `getOvertime()` statt aus `ensureOvertimeLoaded()` nähme, würde nach einem gescheiterten Vorwärts-Write falsch zurückrollen; deshalb den Wert aus `ensureOvertimeLoaded()` verwenden (so ist es heute schon `stored`).

**Web-Vergleich (`OpenEntryCloseService._end`):** gleiche Reihenfolge (Saldo, Eintrag), Rollback nur nach erfolgreichem Saldo, `keepLastUpdated: true`, Rollback-Fehler geschluckt, `failed`. Abweichungen, die bleiben dürfen: Web rechnet `manualOvertimeMinutes` ein, liest Einstellungen/Saldo je Profil explizit; Mobile bindet das Profil über die Repos. Nach #410 entfällt in `web/CLAUDE.md` die Zeile "und es gibt einen Rollback bei Eintrag-Fehler" unter "Abweichung zu Mobile".

## 3. Gemeinsamer Ansatz und PR-Aufteilung

**Gemeinsame Hilfsfunktion "Saldo schreiben, bei Folgefehler zurückrollen": nicht empfohlen.** Die Analyse in 1.1 zeigt, dass der Dashboard-Stop **keinen** Saldo-Rollback bekommen darf (`lastUpdated`-Kopplung). Der Rollback hätte nur einen Aufrufer (`CloseOpenWorkEntry`, ca. 8 Zeilen inline oder eine private Methode `_rollbackOvertime`). Eine geteilte Funktion wäre Abstraktion ohne zweiten Nutzer und würde den Dashboard-Code aufblähen.

Gemeinsam ist stattdessen nur das **Regelwerk**, das in `mobile/CLAUDE.md` stehen soll:
1. Nach dem ersten erfolgreichen Write nie weiterwerfen, sondern loggen (`logger.e`, nur `runtimeType`, keine Inhalte) und ein definiertes Ergebnis liefern.
2. Rollback des Saldos nur, wenn `lastUpdated` nie angefasst wurde (`keepLastUpdated: true`) und nur best-effort.
3. Fehler vor dem ersten Write lassen State, Timer und Daten unverändert.

Geteilt wird außerdem die **Testinfrastruktur**: Fehlerinjektion im `FakeOvertimeRepository` (siehe 4). #402 braucht davon nichts Neues (`failSaveOvertime` genügt), die Dateien überschneiden sich nicht.

**Empfehlung: zwei getrennte PRs.**
- Verschiedene Schichten und Risikoprofile: #410 ist ein kleiner Domain-Eingriff (ein Use Case, ein Fake, Doku); #402 berührt den zentralen Schreibpfad des Dashboards, den Rückgabetyp von 9 Aktionen, die UI und ARB-Keys.
- Unabhängig testbar und rückrollbar; ein Review-Befund zum Dashboard blockiert nicht den einfachen Fix.
- Reihenfolge: **#410 zuerst** (klein, entschärft das Doppelzählen sofort, korrigiert die Doku-Aussage "Rest-Risiko wie #402"), danach #402.
- Beide `Closes` (je Issue ein PR). Der Branch `claude/week-number-display-bug-x5xq8r` wird nach dem Merge/Auto-Delete des ersten PR für den zweiten neu von `develop` angelegt (Repo löscht Branches nach Merge).
- Doku-Überschneidung: beide ändern `mobile/CLAUDE.md` (verschiedene Absätze). Der zweite PR rebased trivial.

## 4. Testplan

Grundsätze (wie #379/#388): feste lokale Daten, Montag `DateTime(2026, 10, 5, ...)` (kein DST-Wechsel in der Nähe; Wochentag nur über Datum, nie `now`), `FakeClock` an `fakeAsync` gebunden (`scenario`/`Harness`), kein `DateTime.now()`, keine Zeitzonenannahme. CI läuft in `Europe/Berlin`; lokal zusätzlich `TZ=UTC`, `America/Los_Angeles`, `Pacific/Auckland`. Je Schritt Test und Fix im selben Commit (O2 aus #388), Rot-Nachweis (Fehlermeldungen) im PR-Text.

### 4.1 #410 (zuerst)

Testinfrastruktur (verhaltensneutral, Default = bisher): `FakeOvertimeRepository` bekommt einen Zähler `saveOvertimeCalls` und `Set<int> failSaveOvertimeCalls` (1-basiert, zählt auch Aufrufe, die scheitern). `failSaveOvertime` (alle Aufrufe) bleibt. `FakeWorkRepository.failSaves` genügt (Test setzt es vor dem Aufruf und danach zurück).

`test/domain/usecases/close_open_work_entry_test.dart`:
- **U1 (ROT)** Eintrag-Write scheitert: `result == failed`, `overtime.savedOvertimes == [alt + delta, alt]`, `savedKeepLastUpdated == [true, true]`, `overtime.stored == alt`, `work.saved` leer, Eintrag im Repo weiter offen. Rot heute: nur 1 Saldo-Write. Der bestehende Test `Entry-Save schlägt nach Saldo fehl ... (Rest-Risiko Teilfehler)` wird dazu **geändert** (`hasLength(1)` -> Rollback-Erwartung); als Bestandstestanpassung im PR nennen.
- **U2 (ROT)** Backend-Simulation (`FakeOvertimeRepository(serverNow: ...)`, `lastUpdate` vorbelegt): nach Fehler und Rollback ist `lastUpdate` unverändert (Mutation "Rollback ohne `keepLastUpdated`" -> rot).
- **U3 (ROT)** Wiederholen nach gelungenem Rollback: zweiter Aufruf (`failSaves` aus) -> `closed`, Saldo = alt + Delta **einmal**, Eintrag beendet; Write-Reihenfolge `saldo, rollback, saldo, eintrag`.
- **U4 (ROT)** Rollback scheitert (`failSaveOvertimeCalls = {2}`): kein Wurf, `failed`, `stored` bleibt `alt + delta` (bekannte Grenze), Logger-Capture (Muster des vorhandenen Tests `Fehlerlog enthält keine Eintragsinhalte`) enthält `runtimeType`, **keine** Eintragsinhalte oder Datumsstrings. Das Doppelzählen beim Wiederholen wird **nicht** als Soll-Test einbetoniert (Konvention O3 aus #388: Ist-Zustand eines bekannten Fehlers nicht committen), nur als Probe und PR-Hinweis.
- **U5 (GRÜN, schärfen)** Vorwärts-Saldo scheitert (`failSaveOvertime`): `saveOvertimeCalls == 1` (kein Rollback-Versuch), kein Eintrag-Write. Fängt die Mutation "Rollback bei jedem Fehler".
- **U6 (GRÜN)** `alreadyClosed`: keine Saldo-Writes, `saveOvertimeCalls == 0`.
- **U7 (GRÜN)** Rollback-Wert ist `stored` aus `ensureOvertimeLoaded` (Fake: `stored` abweichend vom Delta), nicht der Vorwärtswert.

`test/presentation/view_models/open_entry_view_model_test.dart` (`profiles: true`):
- **V1 (ROT)** Eintrag-Fehler beim Beenden: Banner bleibt, `saveError`, `h.overtime.stored` wieder alt, `h.writeLog == ['A:overtime:<neu>', 'A:overtime:<alt>']` (kein `A:lastUpdate`), kein Dashboard-Reload; Wiederholen gelingt mit korrektem Saldo.
- **V2 (ROT)** Profilwechsel im Fenster: `holdSaves` auf A, `switchProfile('B')`, `failSaves = true`, Freigabe: der Rollback landet in A (`writeLog` enthält nur `A:`-Einträge, B unverändert). Beweist die Profil-Kapselung des Rollbacks.

Mutationsproben (Quelle ändern, Lauf, zurücksetzen; Ergebnisse in `410-pr.md`): Rollback entfernen -> U1/U3/V1 rot; Rollback ohne `keepLastUpdated` -> U2 rot; Rollback bei jedem Fehler (auch vorm Saldo) -> U5 rot; Rollback-Wert = Vorwärtswert -> U1 rot; Rollback-Fehler nicht fangen -> U4 rot; Rollback im `alreadyClosed`-Pfad -> U6 rot.

### 4.2 #402

Schritt 1 (API-unabhängig, ROT vor Fix; `act` mit Fehlerabfang, damit kein unbehandelter Zonenfehler den Test beendet):
- **S-1 (ROT)** Stop bei `failSaveOvertime` (Mo 2026-10-05, Uhr 17:00, A läuft seit 08:00, Saldo 120 min; Vorbild `prep()` der Profiltests): kein Wurf; `state.workEntry.workStart != null`, `workEnd == null`; `periodicTimerCount == 1`; `writeLog` leer, `work.saved` leer. Rot heute: Exception, Timer 0 (bestätigt die Probe aus #388).
- **S-2 (ROT)** Timer läuft nach dem Fehler weiter: `tick(5 s)` ändert `grossWorkDuration`; nach `tick(30 s)` schreibt der Autosave den **laufenden** Eintrag (`work.saved.last.workEnd == null`).
- **S-3 (ROT)** Wiederholen: `failSaveOvertime = false`, Stop erneut: genau **ein** Saldo-Write (`A:overtime:135`, `A:lastUpdate`) und **ein** Beenden-Eintrag-Write (`08:00-17:00`), Timer 0, State beendet. Kein Rest aus dem ersten Versuch.
- **S-4 (ROT/GRÜN gemischt)** Tabelle über Aktionen mit Saldo-Block unter `failSaveOvertime`: `setManualEndTime` auf laufendem Eintrag (State laufend, Timer 1), `setManualStartTime`/`updateBreak`/`deleteBreak`/`startOrStopBreak` auf beendetem Eintrag (State identisch zu vorher, kein Write). Heute rot wegen Exception; State-Teil ist heute schon grün.
- **S-5 (ROT)** Tick im Schreibfenster: `holdSaveOvertime`, Stop, `tick(3 s)`: `periodicTimerCount == 1`, `grossWorkDuration` wächst; Freigabe -> beendet, Timer 0. Rot heute (Timer im Fenster 0). Fängt auch die Mutation "Early-Cancel zurück".
- **S-6 (GRÜN)** `startNewSession`/`startNewSessionKeepBreaks` unter `failSaveOvertime`: unverändert (kein Saldo-Block), Eintrag wird geschrieben.
- **S-7 (GRÜN)** Überholung: bestehende O1-Tests (`Dispose: scheiternder Write ...`, O4) bleiben unverändert grün; zusätzlich Fall "überholt + Saldo-Fehler": Stop in A, Saldo hängt, Wechsel auf B, Freigabe mit `failSaveOvertime`: B-State/Timer unberührt (Timerzahl wie B), kein Eintrag-Write.
- **S-8 (Anpassung)** `ohne Ueberholung: Saldo-Fehler wird weitergereicht` (Profiltest Z. 349) wird zu "kein Wurf, Ergebnis `false`, nichts geschrieben, State unverändert" umgeschrieben. Im PR als bewusste Bestandsteständerung benennen.
- **S-9 (Probe, nicht committen)** S4-Teilfehler (`work.failSaves = true` beim Stop): bestätigt, dass Saldo geschrieben und Eintrag nicht, UI "gestoppt", Timer 0 (siehe 1). Befund in den PR-Text und ins Folge-Issue.

Schritt 2 (nach der Signaturänderung):
- **S-10** Rückgabe: Stop bei Fehler `false`, im Erfolgsfall `true`; Aktion ohne Wirkung (Stop auf beendetem Eintrag öffnet die UI-Auswahl) `true`.
- **S-11 Widget-Test** (Muster `dashboard_screen_open_entry_test.dart`; `openEntryViewModelProvider` überschreiben, `MaterialApp` mit `AppLocalizations.localizationsDelegates`/`supportedLocales`, `locale: de`; Repos über Fakes): Tippen auf Stop bei `failSaveOvertime` zeigt das Snackbar (de und en), der Button zeigt weiter "Stoppen" (Eintrag läuft); bei Erfolg kein Snackbar.

Mutationsproben (Ergebnis in `402-pr.md`): `_timer?.cancel()` wieder vor dem Write -> S-1/S-5 rot; `rethrow` statt Fehlerergebnis -> S-1/S-4 rot; `state =` vor den Saldo-Block ziehen -> S-1/S-4 rot; Ergebnis immer `true` -> S-10/S-11 rot; Fehler-Zweig ohne Log (kein Test, nur Review); Snackbar im Screen entfernen -> S-11 rot; `ctx.gen`-Prüfung (`overtaken`) im Fehlerzweig nicht berührt (O1-Tests bleiben grün, sonst Regression).

Abschlussläufe wie CLAUDE.md: `dart format --set-exit-if-changed lib test && flutter analyze --no-fatal-infos && dart run custom_lint && flutter test`, `TZ=Europe/Berlin flutter test`, dazu die Dashboard-/Beenden-Dateien unter `UTC`, `America/Los_Angeles`, `Pacific/Auckland`, Profiltests dreimal gegen Scheduler-Flakiness. `build_runner`: nur nötig, falls `@GenerateMocks` oder `@riverpod` berührt werden (nicht geplant); `flutter gen-l10n` nur bei #402 (neuer Key).

## 5. Risiken, bekannte Grenzen, Doku

Risiken:
- #402 ändert den zentralen Schreibpfad und den Rückgabetyp von 9 Aktionen; die Bestandstests (#379/#386/#388) müssen bis auf S-8 unverändert grün bleiben. Jede weitere Anpassung ist ein Warnsignal.
- Ticks im Schreibfenster (1.4): kleiner neuer Interaktionspfad mit dem Standby-Nachholen von `todayProvider`; S-5 deckt den Timerteil ab, ein gezielter Test für "Tageswechsel-Tick im Fenster" ist optional (selten, vorher schon vorhanden über den Mitternachts-Timer).
- Snackbar-Meldung kann nach einem **teilweise** gelungenen Stop (S2/S4) irreführend sein ("Speichern fehlgeschlagen", aber Saldo wurde schon geschrieben). Auf S4 wird der Text gar nicht erreicht (geschluckt); S2 ist praktisch nicht auslösbar. Siehe Folge-Issue.
- Rollback-Fehlschlag (#410) und alte API ohne #408 sind nicht lösbar, nur geloggt/dokumentiert.

Bekannte Grenzen (nach beiden PRs, in `mobile/CLAUDE.md` festhalten):
1. Dashboard-Stop: Teilfehler nach dem ersten Write (S4 Eintrag-Write scheitert, geschluckt wie #336; S2) lässt Saldo verschoben und Eintrag offen. Ein Saldo-Rollback ist wegen `lastUpdated` nicht tragfähig (1.1). Folge: Banner "Beenden" kann später doppelt zählen. Lösungsrichtung (Folge-Issue): Reihenfolge Eintrag, dann Saldo wie im Web (verschiebt die Fehlerfälle auf "nichts geschrieben" bzw. "Eintrag beendet, Saldo fehlt", mit State-Rollback und Autosave als Heilung), bewusst nicht in #402.
2. #410: Rollback gescheitert oder unklarer Ausgang des Vorwärts-Writes: Wiederholen kann doppelt zählen bzw. nicht zurückrollen; Korrektur über "Überstunden anpassen".
3. Parallelbetrieb/zweites Gerät: absoluter Rollback überschreibt einen zwischenzeitlichen fremden Saldo-Write.
4. Keine Reentranz-Sperre im Dashboard (Doppeltippen im Schreibfenster).
5. Bereits entstandene Teilfehler-Daten werden nicht repariert.

Doku-Änderungen:
- #410-PR: `mobile/CLAUDE.md` Abschnitt "Offene Einträge vor heute (#385)", Punkt "Beenden": Satz "Ein Teilfehler zwischen Saldo- und Eintrags-Write bleibt ein Rest-Risiko (wie #402)" ersetzen durch den Rollback (best-effort, `keepLastUpdated: true`, Rollback-Fehler geloggt, Grenze 2); Doc-Kommentar in `close_open_work_entry.dart` anpassen (der Verweis auf #402); `web/CLAUDE.md` Zeile "Abweichung zu Mobile": den Rollback-Halbsatz streichen (`manualOvertimeMinutes` bleibt Abweichung); Testliste (`Tests`-Zeile) um neue Fälle ergänzen, falls dort aufgezählt.
- #402-PR: `mobile/CLAUDE.md` Abschnitt "Profilwechsel (#388)", Grenze (3) "Stop-Pfad" als behoben beschreiben (Verweis auf den neuen Absatz), neuer kurzer Abschnitt "Fehler beim Speichern (#402)" mit Regelwerk (3 Punkte aus Abschnitt 3), Grenze 1 und 4, Test-Hinweise (`failSaveOvertime`); `_autoSave`/`_recalculateStateAndSave`-Kommentare angleichen (Kommentar "Eine überholte Aktion ... Im Normalfall bleibt das Verhalten unverändert" in Z. 626-628 anpassen); ARB-Key mit `@key`-Beschreibung.
- Folge-Issues (legt die Hauptsession an): (a) Dashboard-Teilfehler S2/S4 / Reihenfolge Eintrag, dann Saldo (Mobile), (b) Reentranz-Sperre im Dashboard, optional (c) Firebase-Overtime-Cache nach fehlgeschlagenem Write.

## Plattformübergreifend
Nur Mobile (Code). `web/CLAUDE.md` bekommt nur einen Doku-Halbsatz (Abweichung entfällt). Web-Stop-Pfad ohne Fehlerbehandlung ist #394 (nicht gelesen, nur aus dem Issue-Verweis bekannt). Backend: unverändert (`keepLastUpdated` ab #408 vorhanden). Keine Firestore-Pfade/Regeln, keine Migration (`DataSyncService` nicht betroffen). Rechenlogik unverändert.

## Offene Fragen (mit Empfehlung)

1. **Stop-Pfad-Lösung (#402):** Option A (Early-Cancel entfernen, Fehler fangen, Ergebnis melden) oder Option C (Reihenfolge Eintrag, dann Saldo wie im Web) schon jetzt? Empfehlung: **A**; C als Folge-Issue, weil es alle Aktionen und viele Bestandstests betrifft und #388 Entscheidung 2 die Reihenfolge festgelegt hat.
2. **Rollback im Dashboard-Stop?** Empfehlung: **nein** (`lastUpdated`-Kopplung, Rechenbeispiel in 1.1: Rollback verschlechtert den Fall). Nur dokumentieren.
3. **Fehlerrückmeldung (#402):** `Future<bool>` plus Snackbar im Screen (ein neuer ARB-Key `dashboardSaveError`) oder Fehlerflag im `DashboardState`? Empfehlung: **`Future<bool>` + Snackbar**, Wortlaut wie oben, Zweck: kein Crashlytics-Fatal mehr und sichtbares Feedback. Ist ein Snackbar überhaupt gewünscht oder nur loggen? Empfehlung: Snackbar.
4. **#410: Rollback auch bei Fehler des Vorwärts-Saldo-Writes** (unklarer Ausgang, z. B. Timeout)? Empfehlung: **nein** (Web-Parität, ein zweiter Request im Offline-Fall sinnlos); Grenze dokumentieren.
5. **Gemeinsamer Helfer?** Empfehlung: **nein** (nur ein Aufrufer, siehe 3), stattdessen Regelwerk in der Doku und gemeinsame Fake-Erweiterung.
6. **PR-Aufteilung:** zwei PRs, **#410 zuerst**, je `Closes`; Branch nach Merge des ersten neu von `develop`. Einverstanden?
7. **Bestandsteständerungen:** `Entry-Save schlägt nach Saldo fehl ... Rest-Risiko` (#410, `hasLength(1)` -> 2 Writes) und `ohne Ueberholung: Saldo-Fehler wird weitergereicht` (#402) werden bewusst umgeschrieben. Freigabe? Empfehlung: ja, beide im PR-Text als geplante Verhaltensänderung nennen.
8. **S4-Stillfehler (Eintrag-Write scheitert nach Saldo, geschluckt, kein Retry)** als separates Bug-Issue anlegen (Doppelzählen über den Banner)? Empfehlung: **ja**, vor/mit #402 anlegen, nicht in #402 lösen.
9. **Reentranz-Sperre im Dashboard** (Doppeltippen im Schreibfenster) als Folge-Issue? Empfehlung: ja, klein, aber eigene Tests.
10. **Charakterisierungstest für Teilfehler (S4, #410-Rollback-Fehlschlag)** committen? Empfehlung: **nein** (nur Probe/PR-Text), konsistent zu O3 aus #388.
11. **Testinfrastruktur:** `failSaveOvertimeCalls` (1-basiert) im Fake in #410 einführen? Empfehlung: ja, Defaults unverändert, Bestandstests unberührt.

## Entscheidungen zu den offenen Fragen (Hauptsession)

1. #402: Option A (Early-Cancel des `_timer` im Stop-Pfad entfernen, Saldo-Fehler immer loggen statt rethrow, Fehler an die UI melden). Option C (Reihenfolge Eintrag vor Saldo wie Web) ist **nicht** Teil, siehe Folge-Issue #412.
2. Kein Saldo-Rollback im Dashboard-Stop (lastUpdated-Kopplung); nur dokumentieren.
3. Rückmeldung: `Future<bool>` aus der Aktion plus Snackbar im Screen mit neuem ARB-Key `dashboardSaveError` (de duzen/en); kein Fehlerflag im `DashboardState`.
4. #410: Rollback nur nach erfolgreichem Vorwärts-Saldo-Write (Web-Parität), in eigenem try, Rollback-Fehlschlag nur loggen, Ergebnis `failed`.
5. Kein gemeinsamer Helfer.
6. Zwei PRs: #410 zuerst (je `Closes`), danach #402; nach jedem Merge Branch neu von `develop`.
7. Die zwei bewussten Bestandstest-Änderungen sind freigegeben (`close_open_work_entry_test` „Entry-Save schlägt nach Saldo fehl"; `dashboard_view_model_profile_test` „ohne Ueberholung: Saldo-Fehler wird weitergereicht"); im PR-Text nennen und begründen.
8. Bug-Issue für den stillen Teilfehler (Eintrag-Write scheitert nach Saldo, geschluckt, Doppelzählen über den Banner): angelegt (#412), nicht in #402 lösen.
9. Folge-Issue Reentranz-Sperre im Dashboard: angelegt (#413).
10. Teilfehler-Charakterisierungstests nicht committen, nur als Probe (wie O3 in #388).
11. `failSaveOvertimeCalls` im Fake (1-basiert, Default unverändert) in #410 einführen.

## Umsetzungsstand #402

Umgesetzt wie entschieden (Option A, `Future<bool>` + Snackbar `dashboardSaveError`, kein Saldo-Rollback). Abweichungen und Ergänzungen:

- **Snackbar auch im Modal `EditBreakModal`** (`updateBreak`): der Aufruf im Modal wäre sonst ohne Feedback geblieben. Der Messenger wird vor `Navigator.pop` synchron gelesen (`reportDashboardSave`), das Modal schließt, die Snackbar erscheint.
- **Tageswechsel-Tick-Test entfallen:** der Stop läuft über `_startTimerIfNeeded`/Reinit wie bisher, der Pfad ist durch die #379-Tests abgedeckt.
- **Fund im Review (Tick im Schreibfenster):** da der Timer bis nach dem Eintrag-Write läuft, setzte der Tick `grossWorkDuration` auf `jetzt - Start` am bereits beendeten Eintrag; der Wert blieb nach dem Abbruch des Timers stehen (UI zeigte 9:00:05 statt 9:00). Behoben: der Tick rechnet bis `workEnd ?? jetzt` (Test S-5b). Autosave im Schreibfenster schreibt den bereits beendeten State-Eintrag und ist harmlos.
- **Grenze 4 (`_ensureCurrentDay`-Fehlschlag liefert still `true`)** bleibt offen: Empfehlung des Reviews siehe PR; nicht geändert.
- Mutationen: Early-Cancel, Rethrow, Catch `true`, Erfolg `false`, Snackbar entfernt/immer, Log-Level/Inhalt/entfernt, Rückgabe je Aktion (9) vertauscht, Snackbar je Aufrufer (Screen 8 Stellen, Modal) entfernt. Überlebende nur bei den Screen-Aufrufern von `clearEndTime`, `startNewSessionKeepBreaks`, `startNewSession`: diese Aktionen haben keinen Saldo-Block und liefern nie `false`, der Zweig ist mit dem echten ViewModel unerreichbar (defensiv).
