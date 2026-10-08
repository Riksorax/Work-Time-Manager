# Mobile-Research: #412 und #413 — Teilfehler Eintrag-Write im Dashboard, Reentranz-Sperre
Datum: 2026-10-08
Typ: Bug-Analyse (zwei Issues, gemeinsam, weil beide `DashboardViewModel` / `_recalculateStateAndSave` betreffen). Kein Code geändert. Branch `claude/week-number-display-bug-x5xq8r` (steht auf `origin/develop`).

Quellen: Issues #412/#413 inkl. Kommentare (nur der Auto-Bugfix-Marker "zurückgestellt, Produkt-/Architekturentscheidung nötig"; zum Neuversuch Kommentar löschen), `mobile/CLAUDE.md`, `388-research.md`, `388-plan.md`, `402-research.md`, `dashboard_view_model.dart` (938 Z.), Web `dashboard.service.ts`, Test-Harness.

## Aufgabe

**#412:** `_recalculateStateAndSave` schreibt Saldo (`saveOvertime` + `saveLastUpdateDate`), setzt dann den State, dann den Eintrag. Scheitert der Eintrag-Write, wird der Fehler geschluckt (#336), `true` geliefert, `_startTimerIfNeeded` bricht Timer **und** Autosave ab (Eintrag ist ja "beendet"). Ergebnis: Saldo verschoben, Eintrag im Repo offen, nichts schreibt ihn nach. Der Banner (#385, `CloseOpenWorkEntry`) kann das Delta später ein zweites Mal zählen. Saldo-Rollback im Dashboard-Stop ist wegen `lastUpdated`-Kopplung nicht tragfähig (402-research 1.1). Optionen laut Issue: Eintrag vor Saldo (Web-Reihenfolge) mit State-Snapshot-Rollback und heilendem Autosave, oder Retry/Reconcile. Mit Tests (Fakes, FakeClock, feste Daten, `TZ=Europe/Berlin`).

**#413:** Keine Sperre gegen überlappende Schreibaktionen (Doppeltippen). `_ActionCtx` (#388) sichert Profil/Zielobjekte, nicht die Reihenfolge. Erwartet: `busy`-Flag/Queue und/oder deaktivierte Buttons, ohne Tageswechsel (#379), Profilwechsel (#388), Autosave zu brechen. Mit hold-fähigen Fakes.

Nicht Teil: Web-Änderungen (#394), Reparatur bereits entstandener Teilfehler-Daten, Ersatz der `lastUpdated`-Heuristik, `CloseOpenWorkEntry` (hat seit #410 eigenen Rollback).

## Betroffene Dateien

| Datei | Warum |
|---|---|
| `lib/presentation/view_models/dashboard_view_model.dart` | `_recalculateStateAndSave` (Z. 671-789: Saldo-Block 704-726, State 742-751, Eintrag-Write 753-768, `_startTimerIfNeeded` 770), alle 9 Schreibaktionen (550-933), `_beginAction`/`_ActionCtx` (23-44, 294), `_autoSave` (425-448), `stopRunningForSwitch` (599-616), `resumePastEntry` (132-159), `_ensureCurrentDay` (306-329), `_onDayChange` (97) |
| `lib/presentation/state/dashboard_state.dart` | optional neues Feld `isSaving` (nur wenn Buttons deaktiviert werden); `_init` baut State per Konstruktor neu (Feld muss mitgeführt werden) |
| `lib/presentation/screens/dashboard_screen.dart`, `widgets/edit_break_modal.dart`, `widgets/common/dashboard_save_feedback.dart` | Aufrufer / Snackbar `dashboardSaveError`; Buttons (Z. 130-176, 378-412) |
| `lib/presentation/view_models/work_profile_view_model.dart` (Z. 62-90) | ruft `stopRunningForSwitch`, `_switchPending` sperrt dort schon Reentranz |
| `lib/presentation/view_models/open_entry_view_model.dart` | Vorbild `busy` (Z. 218/253), ruft `resumePastEntry`/`reloadAfterRetroClose` |
| `lib/l10n/app_de.arb` / `app_en.arb` | `dashboardSaveError`: Beschreibung ("Der Zustand bleibt unverändert, die Aktion kann wiederholt werden") passt nach #412 weiterhin, Text ggf. unverändert; neuer Key nur bei Entscheidung E4 |
| `test/support/fake_repositories.dart`, `test/support/dashboard_harness.dart` | `FakeWorkRepository.failSaves/holdSaves/pendingSaves`, `FakeOvertimeRepository.failSaveOvertime/holdSaveOvertime/failSaveOvertimeCalls`; für #412 fehlt "n-ter Eintrag-Write scheitert" (`failSaveCalls`, analog `failSaveOvertimeCalls`) |
| Zu ändernde Bestandstests | `dashboard_view_model_save_error_test.dart` Z. 320-326 ("Eintrag-Write scheitert nach Saldo: bleibt true (#412 offen)"), Hold-Tests mit `holdSaveOvertime` (Reihenfolge der Release-Aufrufe ändert sich), `dashboard_view_model_test.dart` Z. 228 (#336-Test: Start-Pfad, bleibt unverändert grün) |
| `mobile/CLAUDE.md` | Abschnitte #388 Grenze (3), #402 "Kein Saldo-Rollback"/Grenzen 1+2, #385 Beenden-Absatz |

## Ist-Zustand (Ursache)

Wichtige Befunde aus dem Code, die über die Issue-Texte hinausgehen:

1. **Der Saldo-Block läuft nur, wenn nach der Aktion `workStart != null && workEnd != null`** (Z. 682). Betroffen von #412 sind also nur Aktionen, die einen Eintrag *schließen oder einen geschlossenen Eintrag ändern*: Stop, `setManualStartTime`/`setManualEndTime` auf geschlossenem Eintrag, `deleteBreak`/`updateBreak`/`startOrStopBreak` auf geschlossenem Eintrag. Start, Pause auf laufendem Eintrag, `clearEndTime`, `startNewSession*` haben keinen Saldo-Write; dort scheitert der Eintrag-Write geschluckt, **aber der Timer läuft und der Autosave heilt** nach 30 s (belegt durch Test `dashboard_view_model_break_test` "H"). Das ist gewollt und bleibt.
2. **Selbstheilung am selben Tag:** Nach einem Reload am selben Tag liest `_load` den offenen Eintrag und `lastUpdated == heute` und rechnet `Basis = stored - Tagesanteil(jetzt)`: konsistent, der Timer läuft sichtbar weiter. Der echte Schaden entsteht erst nach Mitternacht/Neustart am Folgetag: offener Vortag im Banner, `Beenden` rechnet inkrementell `stored + Netto - Soll` und zählt doppelt (Überzähler). Zusätzlich sieht der Nutzer "gestoppt", während der Eintrag in Wahrheit offen ist.
3. **Bei geschlossenem Eintrag (Pausenkorrektur, manuelle Zeit) gibt es keinen Timer, also keinen Autosave**: Saldo = neu, Eintrag = alt, State = neu. Ein Reload rechnet dann `Basis = stored - Tagesanteil(alt)`, die Basis ist um `Neu - Alt` verfälscht, **dauerhaft** (bis zur nächsten Aktion, die wieder `Basis + Tagesanteil` schreibt). Das ist die zweite, in den Issues nicht genannte Ausprägung von #412.
4. **Gleiches Problem andersherum bei Saldo-Fehler im Reihenfolgemodell Eintrag→Saldo:** Dort entsteht "Eintrag neu, Saldo alt". Wichtig: Saldo-Fehler ist heute sauber (#402: nichts geschrieben, `false`). Jede neue Reihenfolge darf diese Eigenschaft nicht verlieren.
5. **Doppeltippen (#413) ist schlimmer als "doppelt schreiben".** Beim Start setzt `_recalculateStateAndSave` den State **vor** dem Eintrag-Write (Z. 742-751, Timer erst danach). Ein zweiter Tap im Schreibfenster sieht `workStart != null, workEnd == null` und führt den **Stop** aus: Tag mit 0 Minuten, Saldo-Write von `Basis - Soll`. Beim Stop sieht der zweite Tap den State noch "laufend" (State erst nach Saldo-Block) und schreibt Saldo + Eintrag ein zweites Mal (andere Minute möglich, letzter Write gewinnt, kein Ordnungsgarant). Pausen-Toggle doppelt: Pause startet und endet sofort. `_ensureCurrentDay` (async) und `toggleBreak.call` (await) öffnen weitere Fenster *vor* dem State-Update.
6. **Autosave ist ein ungeschützter Parallelschreiber:** `_autoSave` prüft weder laufende Aktionen noch einen eigenen laufenden Autosave. Bei Reihenfolge Eintrag-zuerst kann ein Autosave mit dem alten "laufenden" Stand den frischen "beendeten" Eintrag überholen (Netz-Reihenfolge nicht garantiert) und den Eintrag wieder öffnen: exakt der Fehler aus #412, nur zufällig. Heute ist das Risiko klein (Saldo-Writes liegen dazwischen), nach einer Umstellung nicht mehr.
7. Es gibt in `lib/data` und `lib/core` **kein einziges Timeout**. Ein Write, der nie zurückkehrt (Zusatzprofile schreiben direkt in Firestore, dessen `set()`-Future offline erst nach Server-Ack auflöst), würde eine Sperre (#413) dauerhaft halten (siehe Risiken).

## Datenfluss

Screen (`reportDashboardSave(context, vm.action())`, fire-and-forget) → `DashboardViewModel.<aktion>` → `_ensureCurrentDay` → `_beginAction` (`_ActionCtx`) → ggf. UseCase (`toggleBreak`) → `_recalculateStateAndSave` → `ctx.overtimeRepository.saveOvertime/saveLastUpdateDate` → State → `ctx.saveWorkEntry` → `HybridWorkRepositoryImpl` (eingeloggt Standard-Profil: `ApiDataSource` → .NET `PUT /api/work-entries`, `PUT /api/overtime` setzt `lastUpdated=heute`; Zusatzprofile: Firestore; ausgeloggt: SharedPreferences).

## (1) Reproduktion / Beleg per Fake-Test-Skizze

Alle Szenarien mit `scenario(..., profiles: true)` (gemeinsames `writeLog`), feste Uhr (`DateTime(2026, 10, 5, 17)`, Seed laufender Eintrag 09:00, Soll 8 h wie `prep(running)` in `dashboard_view_model_save_error_test`), kein `DateTime.now()`.

**R412-a (Stop, Eintrag-Write scheitert):** `h.boot(); h.work.failSaves = true; ok = result(h, h.vm.startOrStopTimer)`. Rot-Beleg heute: `ok == true` (sollte `false`), `h.overtime.savedOvertimes.length == 1`, `h.work.saved.isEmpty`, `h.work.store[key].workEnd == null`, `h.state.workEntry.workEnd != null`, `h.async.periodicTimerCount == 0`; danach `h.work.failSaves = false; h.tick(Duration(minutes: 5))` → `h.work.saved` bleibt leer (kein Autosave). Folgebeleg: neuer Container am Folgetag (zweiter Harness mit denselben Fake-Repos, Uhr +1 Tag) → `GetOpenPastWorkEntries` liefert den Eintrag → `CloseOpenWorkEntry` schreibt `stored + Netto - Soll` ein zweites Mal; `serverNow` am `FakeOvertimeRepository` setzen, damit `lastUpdate` wie im Backend gesetzt wird.
**R412-b (geschlossener Eintrag, Pause bearbeiten):** Seed beendeter Eintrag mit Pause, `failSaves = true`, `h.vm.updateBreak(...)`. Heute: `true`, Saldo neu gespeichert, `h.work.store` unverändert; Reload (`h.switchProfile('B')` und zurück bzw. `h.vm` neu) → `initialOvertime` weicht um `Neu - Alt` ab (Assertion auf `h.state.initialOvertime`).
**R412-c (Gegenprobe, soll grün bleiben):** `failSaves` bei `startOrStopBreak` auf laufendem Eintrag: Timer läuft, Autosave schreibt nach (Bestand "H").
**R413-a (Doppel-Start):** leerer Eintrag, `h.work.holdSaves = true`, zweimal `unawaited(h.vm.startOrStopTimer())` mit `flushMicrotasks`, dann `pendingSaves` freigeben. Rot heute: zweiter Tap führt den Stop aus (`h.work.pendingSaves.length == 2`, zweiter Save hat `workEnd == workStart`, Saldo-Write `Basis - Soll`).
**R413-b (Doppel-Stop):** laufender Eintrag, `h.overtime.holdSaveOvertime = true`, zweimal Stop → heute zwei `saveOvertime`-Aufrufe (`h.overtime.savedOvertimes`/`writeLog`: `A:overtime`, `A:overtime`, zwei Eintrag-Writes).
**R413-c (Doppel-Pause), R413-d (Stop während Pause-Write):** analog, Ergebnis: Pause entsteht und endet sofort bzw. Stop schreibt Eintrag mit veraltetem Pausenstand.
Diese Tests sind die Rot-Phase (TDD) der jeweiligen Umsetzung.

## (2) #412: Lösungsrichtung und Empfehlung

### Optionen im Vergleich

| Option | Kern | Bewertung |
|---|---|---|
| **A: Reihenfolge Eintrag → Saldo, bei Saldo-Fehler den Eintrag kompensieren (Rückschreiben des Vor-Zustands), State erst nach Erfolg** | Eintrag-Fehler: nichts geschrieben, `false`. Saldo-Fehler: Eintrag-Vorzustand best-effort zurückschreiben, `false`, State/Timer unverändert (Vertrag aus #402 bleibt) | **Empfehlung.** |
| B: Saldo → Eintrag beibehalten, bei Eintrag-Fehler State-Snapshot-Rollback und Autosave heilen | Löst Stop (Timer läuft wieder, Autosave schreibt laufenden Eintrag, Saldo bleibt "schief" aber am selben Tag selbstkonsistent). Löst **nicht** Befund 3 (geschlossener Eintrag, kein Autosave) und lässt Saldo verschoben (kein Rollback möglich, 402-1.1). | Nur Teilheilung, Saldo bleibt im Fehlerfall verschoben. |
| C: Retry/Reconcile (Dirty-Marker, Wiederholtimer, Prüfung beim Laden) | Heilt alle Fälle prinzipiell, aber persistenter Marker nötig (App-Neustart!) oder Erkennung aus Daten; `_load` kann "geschlossener Eintrag, `lastUpdated < workEnd`" erkennen, aber nur mit API-`lastUpdated` zuverlässig und ein Schreiben im Ladepfad ist ein neuer Seiteneffekt. | Zu groß, neue Zustandsmaschine, nicht für diesen Bug. |
| D: Atomarer Backend-Endpunkt (Eintrag + Saldo in einer Transaktion) | Beseitigt die Klasse an der Wurzel (für den API-Pfad), gilt aber nicht für Zusatzprofile (Firestore) und lokal. | Zu groß, Mobile+Backend; nur festhalten. |

### Begründung für A

Der Kern der Entscheidung #388/#402 war: Der **Saldo-Write lässt sich nicht zurückrollen**, weil der Stop `lastUpdated` mitschreibt und das Backend den Wert nicht zurücksetzen lässt. Der **Eintrag-Write hat diese Kopplung nicht**: ein Eintrag lässt sich jederzeit mit seinem Vorzustand überschreiben, ohne dass `_load`-Heuristik oder Saldo berührt werden. Also gehört der nicht-rückrollbare Schritt ans Ende:

- Eintrag-Write scheitert (häufigster Fall: Netz weg): nichts hat sich geändert (Regel 1 aus #402), `false`, Snackbar, Wiederholen ist trivial. Das Ergebnis von #412 (Teilfehler) entfällt vollständig, und ein Eintrag-Write-Fehler wird erstmals dem Nutzer gemeldet.
- Saldo-Write scheitert nach erfolgreichem Eintrag: Kompensation `ctx.saveWorkEntry(before)` mit dem am Aktionsbeginn festgehaltenen Vor-Zustand (`_ActionCtx.before`, siehe Hinweise), `false`, State/Timer unverändert. Scheitert auch die Kompensation: nur loggen (`logger.e`, `runtimeType`, keine Eintragsinhalte, Regel 2 aus #402). Folge dann: Stop-Fall heilt der weiterlaufende Autosave (er schreibt den laufenden State-Eintrag), geschlossener-Eintrag-Fall: Eintrag neu/Saldo alt/State alt, der Nutzer sieht die Fehlermeldung und wiederholt (Saldo ist absolut, idempotent). Ein Unterzähler ist nur bei Doppelfehler plus Neustart bis zum Folgetag möglich; das ist die bekannte Grenze 3, nicht der heutige Dauerzustand.
- Das passt zu den Regeln aus #402: (1) Fehler vor dem ersten Write: unverändert; (2) nach dem ersten Write nie weiterwerfen; (3) Saldo-Rollback nur mit `keepLastUpdated: true` (bleibt: Dashboard-Stop bekommt keinen). Neu käme (4): Eintrag-Kompensation ist immer zulässig.

**State-Snapshot-Rollback ist bei A nicht nötig**, wenn der State für Schließen/Bearbeiten-geschlossen erst nach beiden Writes gesetzt wird (heute schon "State nach Saldo-Block", jetzt "State nach Eintrag und Saldo"). Der Preis: der Button zeigt bis zum Ende der Round-Trips (Eintrag + Saldo + lastUpdate statt Saldo + lastUpdate) noch "läuft". Das ist bereits heute das Modell des Stop (#402) und wird durch die Sperre aus #413 (kein Doppeltippen, optional sichtbarer Busy-Zustand) entschärft. Optimistisches Setzen mit Snapshot-Rollback wäre schneller, riskiert aber Flackern und Konflikte mit Timer-Ticks (Snapshot müsste nur `workEntry` zurücksetzen und neu rechnen); nicht empfohlen.

Aktionen **ohne** Saldo-Block (Start, Pause auf laufendem Eintrag, `clearEndTime`, `startNewSession*`) bleiben wie heute: State sofort, Eintrag-Write im Hintergrund, Fehler geloggt und geschluckt, Autosave heilt. Begründung: Offline-Start muss funktionieren; ein Zurückrollen des Starts wäre für ein Zeiterfassungs-Tool die schlechtere Wahl. Die Doku muss den Unterschied benennen (Entscheidung E2).

### Auswirkungen im Einzelnen

- **`lastUpdated`-Kopplung:** unverändert. Der Saldo-Block (`saveOvertime`, `saveLastUpdateDate`, Warnprüfung) bleibt identisch und läuft nur nach erfolgreichem Eintrag-Write. `_load`-Heuristik unverändert. Die Kompensation berührt `lastUpdated` nie.
- **Der Fall S1 ok / S2 scheitert** (nur Nicht-API-Repos: `saveOvertime` ok, `saveLastUpdateDate` scheitert): Saldo neu, `lastUpdated` alt, Eintrag kompensiert alt. Bestand (heute genauso), selten (SharedPreferences/Firestore-Zweitwrite), als Grenze dokumentieren, nicht lösen.
- **Stop-Pfad:** Timer läuft während der Writes weiter (Ticks rechnen weiter mit "laufend"); `_startTimerIfNeeded` weiterhin erst nach State-Setzen. Autosave im Fenster muss unterdrückt werden (siehe #413 und Befund 6), sonst kann ein laufender Autosave den frischen beendeten Eintrag überholen. Das ist die wichtigste Kopplung zwischen den Issues.
- **Alle Schreibaktionen:** nur die mit Saldo-Block ändern ihr Verhalten (Reihenfolge, Rückgabe `false` bei Eintrag-Fehler); die Umstellung sitzt zentral in `_recalculateStateAndSave`, die neun Aktionen selbst bleiben unberührt, außer dass `_beginAction` zusätzlich den Vor-Zustand `state.workEntry` festhält (synchron, vor jedem `await`; bei `startOrStopBreak` liegt der `await toggleBreak.call` *zwischen* `_beginAction` und `_recalculateStateAndSave`, deshalb nicht erst in `_recalculateStateAndSave` lesen).
- **`CloseOpenWorkEntry`:** unberührt (eigene Reihenfolge Saldo→Eintrag mit Rollback und `keepLastUpdated: true`, inkrementell). Der Unterschied ist begründet (inkrementell + `lastUpdated` unangetastet vs. absolut + `lastUpdated` gesetzt) und gehört in einen Satz der Doku. Banner-Doppelzählung über den Dashboard-Stop entfällt mit A.
- **Profilwechsel (#388):** Garantie "alle Writes im Profil des Aktionsbeginns" bleibt, weil Eintrag-Write, Saldo-Write und Kompensation ausschließlich über `ctx`-Objekte laufen. Überholte Aktion (Profilwechsel/Dispose mitten im Write): Writes laufen zu Ende, **auch die Kompensation** (läuft ebenfalls über `ctx.saveWorkEntry`); nur State/Timer/Reinit entfallen. Test: Wechsel nach Eintrag-Write, Saldo-Hold, Saldo-Fehler → `writeLog` enthält `A:entry(neu)`, `A:entry(alt)`, kein `B:`-Eintrag.
- **`stopRunningForSwitch`:** unverändert im Code. Gewinn: Grenze (3) aus #388 ("Eintrag-Write-Fehler nach Saldo lässt 'Beenden und wechseln' mit `true` wechseln") entfällt, weil der Stop nun bei Eintrag-Fehler `false` liefert und der Wechsel unterbleibt (Snackbar `dashboardSaveError`). Die Wirkungsprüfung `!_isRunning` bleibt.
- **Rückgabewert `Future<bool>`:** Vertrag erweitert, nicht geändert: `false` = Aktion hat nichts bewirkt und nichts hinterlassen (Eintrag- oder Saldo-Fehler, Tag nicht ladbar). Alle Aufrufer sind schon an `reportDashboardSave` angebunden.
- **UI-Feedback:** `dashboardSaveError` ("Speichern fehlgeschlagen. Bitte prüfe deine Verbindung und versuche es erneut.") passt ohne Textänderung; die `@dashboardSaveError`-Beschreibung nennt nur den Saldo und sollte auf "Eintrag oder Saldo" erweitert werden (de-Beschreibung, kein neuer Key, `flutter gen-l10n`).
- **Autosave "heilt":** In A ist der Autosave für den Stop-Fall nur noch Reserve (Doppelfehler); die eigentliche Heilung ist, dass der Fehler gar nicht erst ein Teilfehler wird.

## (3) #413: Sperre / Serialisierung

### Optionen

| Option | Vor-/Nachteile |
|---|---|
| **Busy-Flag im ViewModel, zweiter Aufruf wird verworfen** (`true`, kein Snackbar) | Einfach, wie `OpenEntryViewModel.busy` (Konsistenz). Doppeltippen ist der Hauptfall und wird genau richtig behandelt. Verliert absichtliche schnelle Folgeaktion (Pause, dann sofort Stop) im Fenster, das aber meist <1 s dauert und mit sichtbarem Busy-Zustand für den Nutzer klar ist. |
| Queue (serielle Abarbeitung) | Jeder Tap wird ausgeführt, aber ein Doppeltipp auf Start/Stop wird zu Start **und** Stop (0-Minuten-Tag), ein Doppeltipp auf Pause zu Pause-an/aus. Für Toggle-Aktionen falsches Ergebnis; zusätzlich Fragen zu veralteten Argumenten (Zeit aus Picker) und zu Queue-Abbruch bei Fehler/Profilwechsel. |
| Nur UI deaktivieren | Reicht nicht: Aufrufer ohne Button (Banner-Reload, `stopRunningForSwitch`, Modal `EditBreakModal`, Tests) und der Frame-Verzug zwischen zwei Taps bleiben ungeschützt. Die Sperre muss im VM sitzen. |

**Empfehlung:** Busy-Flag im ViewModel (Verwerfen) **plus** UI-Rückmeldung (Buttons deaktiviert/Ladeanzeige über `DashboardState.isSaving`, siehe E3). Programmatische Aufrufer, die nicht verworfen werden dürfen, warten stattdessen auf die laufende Aktion.

### Ausgestaltung (für den Plan)

- **Wrapper `_runAction`** um die neun öffentlichen Aktionen (nicht um `_recalculateStateAndSave`, das auch von `_load` mit `save: false` genutzt wird, sonst Selbstblockade). Das Flag wird **synchron als erste Anweisung** gesetzt, noch vor `_ensureCurrentDay` (sonst bleibt das Fenster in der Ladelücke offen), und im `finally` freigegeben. Zusätzlich `Future<void>? _actionRun` für Wartende.
- **Verworfene Aufrufe liefern `true`** (kein Fehler, kein Snackbar, "nichts zu tun" ist im Vertrag schon definiert). `false` würde fälschlich `dashboardSaveError` zeigen.
- **`_autoSave`:** überspringen, solange eine Aktion läuft, und nicht überlappen (`_autoSaveRun`; ein hängender Autosave blockiert sonst gleich zwei Folgeläufe). **Aktionen mit Eintrag-Write warten vor dem ersten Write auf einen laufenden Autosave** (`await _autoSaveRun`, Zustand danach neu lesen, da der Wrapper vor dem `await` die Argumente schon festgehalten hat, aber `before` erst danach gelten darf). Das ist Voraussetzung für #412-A.
- **`stopRunningForSwitch`:** wartet auf `_actionRun` (statt zu verwerfen), prüft danach `isTimerRunning` neu und ruft erst dann `startOrStopTimer`. Ohne das würde ein parallel getippter Stop dazu führen, dass der Wechsel mit "Speichern fehlgeschlagen" abgelehnt wird, obwohl der Stop gerade erfolgreich läuft. Der Aufruf selbst geht durch denselben Wrapper (kein Sonderweg); das `_switchPending`-Flag des Profil-VM bleibt unverändert.
- **`resumePastEntry`:** liefert `false`, wenn eine Aktion läuft (still, wie die anderen Ablehnungen). Es schreibt nichts, aber ein parallel laufender Start würde sonst mit dem Pin kollidieren. Der dokumentierte Fall "Start-Tap in der Ladelücke wartet auf den Pin" (`dashboard_view_model_resume_test`) bleibt: der Tap hält das Flag, `resumePastEntry` danach nicht (die Prüfung `todayIsEmpty` liefert ohnehin `false`, sobald der Start den State gesetzt hat).
- **`_ensureCurrentDay` / `_onDayChange` / Reinit:** keine Änderung nötig. `_init` erhöht `_initGen`, eine laufende Aktion ist dann überholt und lässt State/Timer in Ruhe (Mechanik aus #379/#388). Das Flag liegt in einem Feld, nicht im State, und überlebt den Reinit; die State-Spiegelung `isSaving` muss `_init` beim Konstruktoraufbau mitgeben (sonst flackert die UI während eines Reinit mitten in einer Aktion).
- **`reloadAfterRetroClose`** und `updateOvertimeFromSettings`/`recalculateOvertimeFromSettings` schreiben nichts: ungesperrt.
- **Profilwechsel/Dispose:** Ein Profilwechsel ist ein Rebuild desselben Notifier-Objekts, dessen Felder über `build()` hinweg bestehen bleiben (Annahme aus der Riverpod-3-Beobachtung in #388, im Plan per Test bestätigen): **`build()` muss Flag und `_actionRun` ausdrücklich zurücksetzen**, sonst blockiert eine hängende alte Aktion das neue Profil, Befund aus #388: `ref.mounted` bleibt über Rebuild `true`). Das ist ein Detail für den Plan und ein eigener Test (Wechsel mitten in der Aktion, danach sofort Start im neuen Profil funktioniert).

## (4) Backend-/Web-Anteil

- **Backend:** nicht nötig. `keepLastUpdated` (#408) wird nicht berührt; kein neuer Endpunkt, keine Firestore-Pfade/Rules, keine Migration, Rechenlogik unverändert. Langfristig (nur festhalten): ein atomarer Endpunkt "Eintrag + Saldo" würde die Klasse für den API-Pfad lösen (Option D), deckt aber Zusatzprofile/lokal nicht ab.
- **Web:** nur festhalten. `DashboardService._recalculateState` schreibt bereits Eintrag vor Saldo (Z. 625-630), hat also schon die Reihenfolge von A, aber keine Kompensation und im Stop-Pfad keine Fehlerbehandlung (#394, offen). `stopRunningTimerForSwitch` macht State-Snapshot-Rollback (kein Entry-Rückschreiben). Eine Reentranz-Sperre gibt es im Web-Dashboard **nicht** (kein busy/Queue in `dashboard.service.ts`): das gleiche Doppeltipp-Problem besteht dort vermutlich ebenfalls (nicht geprüft/getestet). Empfehlung: nach der Mobile-Umsetzung ein Web-Issue "Reentranz-Sperre" anlegen bzw. in #394 aufnehmen; `web/CLAUDE.md` bekommt höchstens einen Halbsatz zur Abweichung. `/web-analyze` wäre der Einstieg.

## (5) Risiken, Testplan, PR-Schnitt

### Risiken
- **Dauer-Sperre durch hängende Writes:** ohne Timeout bleibt `busy` bei einem nie auflösenden Future (Firestore offline bei Zusatzprofilen) für immer gesetzt, das Dashboard reagiert nicht mehr bis zum Neustart. Gegenmaßnahme (Empfehlung E5): Timeout auf den Schreibblock (z. B. 30 s) als Fehler behandeln (`false`, Kompensation versuchen); ein verspätet landender Write ist ein bekannter "unbekannter Ausgang"-Fall und wird vom Autosave überschrieben. Mit `fakeAsync` und `holdSaves` testbar.
- **Verworfene Taps:** Nutzer tippt zweimal absichtlich; ohne sichtbaren Busy-Zustand wirkt die App träge. Deshalb Buttons deaktivieren (E3).
- **Verlängertes Schreibfenster beim Stop** (Eintrag + Saldo + lastUpdated nacheinander bis zum State-Update). Mit der Sperre unkritisch, aber spürbar; im Review mit realer API messen.
- **Autosave-Überholung** (Befund 6): ohne die Autosave-Serialisierung ist Option A **nicht** sicher. Deshalb PR-Reihenfolge unten.
- **Firebase-Overtime-Repo setzt den Cache vor dem Write** (`_cachedOvertime = rounded`, bekannt aus 402-Folgeliste c): nach fehlgeschlagenem Saldo-Write liefert ein In-Session-Reload den fehlgeschlagenen Wert. Bestand, nicht durch diese Issues verschlimmert; erwähnen.
- **Bestehende Tests pinnen das alte Verhalten** (siehe Tabelle): bewusste Änderung, im PR benennen.
- **Timer-/Tageswechsel im verlängerten Fenster:** Standby-Nachholpfad (`todayProvider.refresh()` im Tick) kann `_onDayChange` auslösen; Stop-State ist noch "laufend", `_onDayChange` ignoriert laufende Einträge (unverändert gut); ein Test "Tageswechsel im Schreibfenster" gehört trotzdem dazu.
- Flakiness: alle neuen Tests nur mit FakeClock/`fakeAsync`, Tage als Konstanten (`DateTime(2026, 10, 5, ...)`), zusätzlich `TZ=Europe/Berlin` und `TZ=UTC` lokal.

### Testplan-Skizze
PR #413 (Datei `dashboard_view_model_busy_test.dart`, Harness `profiles: true`):
1. Doppel-Start (`holdSaves`): ein Save, State "läuft", zweiter Aufruf `true`, kein Stop (R413-a rot→grün).
2. Doppel-Stop (`holdSaveOvertime`): genau ein Saldo-Write, ein Eintrag-Write; Folge-Tap nach Freigabe wirkt wieder normal (Flag freigegeben, auch nach Fehler: `try/finally`).
3. Pause/Pause, Pause + Stop, manuelle Zeit + Stop: zweite Aktion verworfen, Ergebnis `true`, kein Snackbar (Widget-Test-Erweiterung `dashboard_screen_save_error_test`: kein `dashboardSaveError`).
4. Tap in der Ladelücke (`holdReads`): Flag schon in `_ensureCurrentDay` gesetzt.
5. Autosave: kein Autosave im Fenster (Tick 30 s während `holdSaves`), kein überlappender Autosave bei hängendem Write.
6. `stopRunningForSwitch` wartet auf laufenden Stop und liefert `true` ohne zweiten Stop; Wechsel mitten in laufender Aktion: neues Profil sofort bedienbar (Flag aus `build()` zurückgesetzt); überholte Aktion lässt State in Ruhe (Bestand).
7. `resumePastEntry` bei laufender Aktion: `false`, nichts gepinnt.
8. Tageswechsel im Schreibfenster (`FakeClock.jumpTo`).
9. Falls `isSaving` im State: Wert true im Fenster, false danach und nach Reinit; Widget-Test: Buttons deaktiviert.
PR #412 (`dashboard_view_model_save_error_test` erweitern):
1. R412-a: Eintrag-Fehler beim Stop → `false`, nichts im Repo, `savedOvertimes` leer, State "läuft", `periodicTimerCount == 1`, Autosave schreibt später den laufenden Eintrag; Wiederholen nach `failSaves=false` klappt (genau ein Saldo-Write).
2. R412-b für alle Saldo-Aktionen (Tabelle wie "S-4": `setManualStartTime`/`setManualEndTime`, `deleteBreak`, `updateBreak`, `startOrStopBreak` auf geschlossenem Eintrag): Eintrag-Fehler → `false`, State/Repo unverändert.
3. Saldo-Fehler nach Eintrag (`failSaveOvertime`): `writeLog` = `A:entry(neu)`, `A:entry(alt)`; State/Timer unverändert; `false`.
4. Kompensation scheitert (`failSaveCalls = {2}`, neu im Fake): kein Wurf, `false`, Log enthält `runtimeType` und keine Eintragsinhalte (Muster des vorhandenen Logger-Capture-Tests), Autosave heilt im Stop-Fall.
5. Überholt: Profilwechsel nach Eintrag-Write bei gehaltenem Saldo und anschließendem Saldo-Fehler → Kompensation landet in A, nichts in B.
6. Folgetag-Beleg: nach Eintrag-Fehler beim Stop liefert `GetOpenPastWorkEntries` am Folgetag nichts (nichts geschrieben), `savedOvertimes` unverändert (statt Doppelzähler).
7. Stop-Pfad über Mitternacht (Vortags-Lauf): Reinit nur bei `saved`; Eintrag-Fehler → kein Reinit, State unverändert.
8. `stopRunningForSwitch` bei Eintrag-Fehler → `false`, kein Wechsel (Grenze (3) aus #388 entfällt; Test in `dashboard_view_model_switch_test`).
9. Gegenprobe "H" (Pause auf laufendem Eintrag, Eintrag-Fehler geschluckt, Autosave heilt) und #336-Test bleiben grün.
10. Timeout-Test (E5), falls umgesetzt.
Mutationsproben je PR (Reihenfolge zurückdrehen, Kompensation entfernen, Flag-Freigabe im `finally` entfernen, Autosave-Wait entfernen), Ergebnisse in `<nr>-pr.md`. Checks wie CI (`dart format`, `flutter analyze --no-fatal-infos`, `dart run custom_lint`, `flutter test`), zusätzlich `TZ=UTC` und `TZ=America/Los_Angeles flutter test` für die neuen Dateien.

### PR-Schnitt und Reihenfolge
**Zwei PRs, #413 zuerst, dann #412 (Basis: PR 1).**
- PR 1 `Closes #413`: Wrapper/Flag, Autosave-Guard und Autosave-Serialisierung, `stopRunningForSwitch` wartet, `resumePastEntry` verwirft, optional `isSaving` plus Button-Deaktivierung. Klein, risikoarm, verändert kein Schreibergebnis.
- PR 2 `Closes #412`: Reihenfolge Eintrag→Saldo, Kompensation, `_ActionCtx.before`, Timeout (E5), ARB-Beschreibung, Bestandstests, Doku in `mobile/CLAUDE.md` (#388 Grenze (3) entfällt, #402-Abschnitt: "Kein Saldo-Rollback" um "Eintrag-Kompensation" ergänzen, Regel (4), Grenzen 1+2 neu).
Begründung: A ist ohne die Autosave-Serialisierung nicht sicher (Befund 6) und verlängert das Schreibfenster, das ohne Sperre Doppeltippen noch gefährlicher macht. Ein gemeinsamer PR wäre möglich, mischt aber zwei Testschwerpunkte und ein Verhaltensversprechen (`true` verworfen) mit einer Semantikänderung (Reihenfolge); getrennt lässt sich jeder Rot/Grün-Nachweis und jede Mutationsprobe sauber lesen. Beide Branches von `develop`, PR 2 nach Merge von PR 1 rebasen.

## Offene Fragen / Entscheidungen

Echte Produktentscheidungen (nur das, was der Nutzer festlegen muss):

1. **E1 Reihenfolge (#388-Entscheidung 2 bewusst neu entscheiden):** Eintrag vor Saldo mit Eintrag-Kompensation (Option A). Empfehlung: **ja.** Die Entscheidung von #388 galt nur dem Race-Fix ("Reihenfolge beibehalten, aber mit Profil-/Generationsprüfung") und ist durch die Erkenntnis aus 402-1.1 (nur der Eintrag ist rückrollbar) überholt. Gegenseite: einzige Verhaltensänderung für den Nutzer ist, dass Eintrag-Fehler jetzt als Snackbar erscheinen und die Aktion nicht ausgeführt wird, statt still zu "gelingen".
2. **E2 Offline-Verhalten der Aktionen ohne Saldo-Block** (Start, Pause laufend, `clearEndTime`, Neue Session): bleiben optimistisch mit Autosave-Heilung und ohne Fehlermeldung. Empfehlung: **so lassen** (Offline-Start muss funktionieren). Alternative wäre Fehlermeldung bei Eintrag-Fehler ohne Rollback; ohne Zusatznutzen, weil der Autosave nachschreibt.
3. **E3 Sichtbarer Busy-Zustand:** Buttons deaktivieren bzw. Fortschrittsanzeige (`DashboardState.isSaving`). Empfehlung: **ja**, mindestens Start/Stop-Button und Pausen-Button; ohne Rückmeldung wirken verworfene Taps wie ein Hänger. Kein neuer Text nötig (kein ARB-Key), nur Deaktivierung/Spinner. Wenn nicht gewünscht: nur VM-Sperre, kleinerer PR 1.
4. **E4 Verhalten verworfener zweiter Tap:** still verwerfen (Empfehlung) vs. Hinweis-Snackbar. Empfehlung still; ein Hinweis wäre ein neuer ARB-Key und Lärm bei Doppeltippen.
5. **E5 Timeout für den Schreibblock** (Dauer-Sperre verhindern): Empfehlung **ja**, 30 s, als Fehler behandeln. Ohne Timeout kann ein hängender Zusatzprofil-Write das Dashboard bis zum Neustart blockieren. Gegenseite: ein verspätet landender Write ist möglich (unbekannter Ausgang).
6. **E6 Folge-Issues:** (a) Web: Reentranz-Sperre / Kompensation (Eintrag vor Saldo gibt es dort schon) anlegen oder in #394 aufnehmen; (b) Firebase-Overtime-Cache nach fehlgeschlagenem Write (Cache vor Write gesetzt); (c) langfristig atomarer Backend-Endpunkt. Empfehlung: (a) ja, (b) ja klein, (c) nicht anlegen.

Technische Klärung ohne Nutzerentscheidung (Plan): Position des Vor-Zustands in `_ActionCtx`, Wartepunkt auf Autosave, Zurücksetzen von Flag und `_actionRun` in `build()`, `isSaving` in `_init` mitführen, Fake-Erweiterung `failSaveCalls`.
