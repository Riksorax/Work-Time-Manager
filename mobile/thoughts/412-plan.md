# Mobile-Plan: #412 — Teilfehler Eintrag-Write im Dashboard (PR 2 von 2)
Research: mobile/thoughts/412-413-research.md (Abschnitt #412, E1-E6), Vorgänger: mobile/thoughts/413-plan.md, 413-pr.md (PR 1 gemergt)
Basis: Branch `claude/week-number-display-bug-x5xq8r` auf `origin/develop` inkl. PR 1 (`_runAction`, Token, `isSaving`, Autosave-Serialisierung, 30-s-Timeouts).

## Entscheidung der Hauptsession zur offenen Frage (umgesetzt)
Die „Heilung nach spätem Landen“ (`_healAfterLateWrite`, Autosave-Variante) wird **nicht** umgesetzt. Entfallen: E13, E14, E17, N14-N18 und die zugehörigen Passagen unten (Abschnitt „Spät landender Eintrag-Write (Heilung)“, Schritt 3 Heilungs-Tests/-Impl, Grenze 3 alt). Stattdessen **Grenze 3 (neu):** Ein nach Timeout spät landender Write ist nicht abbrechbar und kann später landen; der Saldo ist absolut, der Eintrag wird beim nächsten Schreiben/Autosave überschrieben. Ein Timeout wird wie ein Fehler behandelt (Eintrag-Timeout => `false`, Saldo-Timeout => `false` mit Kompensation des Eintrags). Umgesetzt: Schritte 1, 2, 3 (nur E12/E15/E16), 4, 5, 6.

## Ziel
Schlägt der Eintrag-Write einer Aktion mit Saldo-Block fehl, bleibt nichts zurück (kein Teilfehler "Saldo neu, Eintrag alt") und der Nutzer erfährt es (`false` -> Snackbar `dashboardSaveError`). Dazu wird die Reihenfolge der Writes umgedreht: **Eintrag vor Saldo**, bei Saldo-Fehler wird der Eintrag best-effort auf den Vorzustand zurückgeschrieben.

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Neue Entity / Feld? | Nur `_ActionCtx.before` (`WorkEntryEntity`, Pflichtfeld, privat). Kein Entity-/Model-/State-Feld. | Vorzustand für die Kompensation, synchron in `_beginAction` aus `state.workEntry` (bei `startOrStopBreak` liegt `await toggleBreak.call` danach, deshalb nicht erst in `_recalculateStateAndSave` lesen). |
| Repository-Interface ändern? | Nein. Hybrid-/Firebase-/Local-/ApiDataSource unberührt. Kompensation = normaler `ctx.saveWorkEntry`-Aufruf. | Reine ViewModel-Logik. |
| Neuer Provider? | Nein, kein `@riverpod`, **kein build_runner**, keine Mocks. | |
| Premium / Profil | Kein Gate. Profil: alle Writes (Eintrag, Saldo, Kompensation, Heilung) nur über `ctx`-Objekte, also im Profil des Aktionsbeginns (#388). | |
| Backend / Web | Keine Änderung. Web hat die Reihenfolge Eintrag->Saldo schon (#394 bleibt offen). | |
| Neue Texte? | Kein neuer ARB-Key. Nur die **Beschreibung** `@dashboardSaveError` in `app_de.arb` ("Eintrag oder Saldo") -> `flutter gen-l10n`; `app_en.arb` unverändert (Werte gleich). | Entscheidung Hauptsession. |
| Reihenfolge | Aktionen mit Saldo-Block (nach der Aktion Start **und** Ende gesetzt): **Eintrag -> Saldo -> State -> Timer -> ggf. Reinit**. Bewusste Neuentscheidung gegen #388-Entscheidung 2 ("Reihenfolge beibehalten"); in der Doku vermerken. | Nur der Eintrag ist rückrollbar (Saldo schreibt `lastUpdated` mit, 402-Research 1.1). Der nicht rückrollbare Schritt gehört ans Ende. |
| Eintrag-Fehler (Saldo-Aktion) | Nichts geschrieben, State/Timer unverändert, loggen (`logger.e`, nur `runtimeType`, keine Eintragsinhalte), `false`, **auch bei überholter Aktion** (wie Saldo-Fehler heute). Kein Snapshot-Rollback nötig, weil der State erst nach beiden Writes gesetzt wird. | Regel 1 aus #402. |
| Eintrag-Timeout (30 s) | Wie Eintrag-Fehler (`false`), zusätzlich "Heilung nach spätem Landen" (siehe unten). Der PR-1-Test "T2 ... (PR 2 aendert dies)" wird auf `false` umgeschrieben. | Entscheidung Hauptsession. |
| Saldo-Fehler/-Timeout | Block selbst **unverändert** (inkl. `timedOut`-Guard). Danach `_compensateEntry(ctx)`: `ctx.saveWorkEntry(ctx.before)` mit `_writeTimeout`, Ergebnis `false`, State/Timer unverändert. | Vertrag aus #402 bleibt: Saldo-Fehler = nichts bleibt zurück. |
| Kompensation scheitert/Timeout | Nur loggen (`logger.e`, Text "Kompensation", `runtimeType`, keine Inhalte), nichts werfen, Ergebnis trotzdem `false`. Keine weitere Wiederholung. | Regel 2 (nie weiterwerfen). Folgen siehe Grenzen. |
| `lastUpdated` | Kompensation fasst `lastUpdated` nie an (nur Eintrag). Saldo-Block, `_load`-Heuristik, `CloseOpenWorkEntry` unverändert. Fall "Saldo ok, `saveLastUpdateDate` scheitert": Saldo neu, `lastUpdated` alt, Eintrag kompensiert -> bekannte Grenze (Bestand), nur Nicht-API-Repos. | Kopplung bleibt wie heute. |
| Aktionen ohne Saldo-Block (Start, Pause auf laufendem Eintrag, `clearEndTime`, Neue Session x2) | **Unverändert** (E2): State sofort, Eintrag-Write danach, Fehler/Timeout geloggt und geschluckt, `true`, Autosave heilt. | Offline-Start muss funktionieren. |
| Firebase-Overtime-Cache-Vorbelegung | **Nicht** in diesem PR (Folge-Issue E6b). | Entscheidung Hauptsession. |

## Verhalten im Detail (Referenz für die Umsetzung)

`_recalculateStateAndSave(updatedEntry, {save, ctx})`, `hasSaldoBlock = start != null && end != null` (wie heute Z. 776). Zweige:

- `save == false` (`_load`) und `!hasSaldoBlock`: **unverändert** (State, dann Eintrag-Write bzw. kein Write).
- `save && hasSaldoBlock` (neu):
  1. Werte berechnen (unverändert).
  2. Eintrag-Write: `final write = ctx.saveWorkEntry.call(updatedEntry); await write.timeout(_writeTimeout)`. Fehler -> `logger.e('... (${e.runtimeType})')`, bei `TimeoutException` zusätzlich `_healAfterLateWrite` registrieren, `return false`. Kein Saldo-Write, kein State.
  3. Saldo-Block unverändert. Fehler -> bestehendes Log, dann `await _compensateEntry(ctx)`, `return false`.
  4. State setzen (`if (!overtaken())`), `saved = true`, danach wie heute: `if (overtaken()) return true;`, `_startTimerIfNeeded()`, Vortags-Reinit nur bei `saved`.
- `save && !hasSaldoBlock`: wie heute (State -> Eintrag-Write geschluckt -> Timer).

`_compensateEntry(ctx)`: `try { await ctx.saveWorkEntry.call(ctx.before).timeout(_writeTimeout); } catch (e) { logger.e('[Dashboard] Eintrag-Kompensation fehlgeschlagen (${e.runtimeType})'); }`. Läuft auch bei überholter Aktion (Profilwechsel, Dispose) zu Ende, weil nur `ctx`-Objekte benutzt werden.

**Spät landender Eintrag-Write (Heilung):** Ein per Timeout aufgegebener Write ist nicht abbrechbar und kann später landen, auch nach Autosave oder Wiederholen (Reihenfolge im Transport nicht garantiert). `_healAfterLateWrite`: am abgegebenen Future `write.then((_) => heal(), onError: (_) {})` (Fehler der Originals ignorieren, nichts landete). `heal()` läuft **erst nach dem Landen** (nur das garantiert Reihenfolge) und schreibt die "VM-Wahrheit" erneut:
  - Aktion nicht überholt (`ref.mounted`, `ctx.gen == _initGen`) und `!_busy`: `ctx.saveWorkEntry(state.workEntry)` (laufender Stop-Fall: laufender Eintrag; geschlossener Fall: Stand vor der Aktion bzw. bei erfolgreichem Wiederholen der neue; beides idempotent).
  - Aktion überholt (Profilwechsel/Dispose): `ctx.saveWorkEntry(ctx.before)` (das alte Profil ist eingefroren, `before` ist seine Wahrheit).
  - `_busy` (andere Aktion im Flug): überspringen, `logger.i`. Die laufende Aktion schreibt den neuesten Stand selbst (Restrisiko in Grenzen).
  - Fehler des Heilungs-Writes: loggen (`runtimeType`), nicht werfen. Timeout `_writeTimeout`.
  Gleiches für den **Autosave-Timeout** (PR-1-Lücke "hängender Autosave landet nach dem Stop und öffnet den Eintrag wieder"): `_autoSave` merkt `saveWorkEntry` und `_initGen` vor dem Write; nach dem späten Landen schreibt `heal` (nur wenn `ref.mounted`, Gen gleich, `!_busy`) `state.workEntry` erneut.

Rückgabe-Vertrag (neu): `false` = Aktion hat nichts bewirkt und nichts hinterlassen (Tag nicht ladbar, Eintrag-Fehler, Saldo-Fehler); Kompensationsfehler ändert das Ergebnis nicht. `true` = gespeichert, nichts zu tun, verworfen (#413), überholt mit erfolgreichen Writes, oder Aktion ohne Saldo-Block.

**Zeitbudget:** Aktion maximal Autosave-Wait 30 + Eintrag 30 + Saldo 30 + Kompensation 30 s = 120 s (Flag währenddessen gesetzt, Taps verworfen).

## Dateien
| Datei | neu/geändert | Zweck |
|---|---|---|
| `mobile/lib/presentation/view_models/dashboard_view_model.dart` | geändert | `_ActionCtx.before`, `_beginAction`, Zweige in `_recalculateStateAndSave`, `_compensateEntry`, `_healAfterLateWrite`, Heilung im Autosave-Timeout, Doc-Kommentare (Reihenfolge, Rückgabe) |
| `mobile/lib/l10n/app_de.arb` (+ generierte `app_localizations*.dart`) | geändert | Beschreibung `@dashboardSaveError`; `flutter gen-l10n` |
| `mobile/test/support/fake_repositories.dart` | geändert | `FakeWorkRepository.failSaveCalls` (1-basiert) + `saveCalls`; `FakeOvertimeRepository.failSaveLastUpdate` (Flag) |
| `mobile/test/presentation/view_models/dashboard_view_model_partial_failure_test.dart` | neu | Kernsuite E1-E14 (Harness `profiles: true`) |
| `mobile/test/presentation/view_models/dashboard_view_model_save_error_test.dart` | geändert | zwingende Anpassungen (siehe Bestandstests) |
| `mobile/test/presentation/view_models/dashboard_view_model_busy_test.dart` | geändert | zwingende Anpassungen (T2 u. a.) |
| `mobile/test/presentation/view_models/dashboard_view_model_switch_test.dart` | geändert | `stopWrites`, neu E12 |
| `mobile/test/presentation/view_models/dashboard_view_model_profile_test.dart`, `work_profile_view_model_guard_test.dart`, `dashboard_screen_save_error_test.dart` | ggf. geändert | nur falls im Lauf rot (Klassifikation) + neu: Guard-Test Eintrag-Fehler -> `saveFailed`, Widget-Test Snackbar bei Eintrag-Fehler (de/en) |
| `mobile/CLAUDE.md` | geändert | siehe Schritt 6 |
| `mobile/thoughts/412-pr.md` | neu (Review-Phase) | Rot-Nachweise, Klassifikation der Bestandstests, Mutationen, TZ-Läufe |

## Schritte (TDD, jeder Schritt beginnt mit dem Test)
domain/data/core-providers entfallen (keine Änderung). `build_runner` nicht nötig.

### Schritt 1: Test-Support (inert)
- [x] Impl (Fakes sind Testcode, vor den Tests nötig): `FakeWorkRepository.saveCalls` (zählt jeden Aufruf vor dem Hold) und `failSaveCalls` (Menge 1-basierter Nummern, wirft nach dem Hold, wie `failSaveOvertimeCalls`); `FakeOvertimeRepository.failSaveLastUpdate` (wirft in `saveLastUpdateDate`, schreibt dann nichts).
- [x] Danach komplette Suite grün (Defaults ändern nichts).

### Schritt 2: Kern — Reihenfolge, Eintrag-Fehler, Kompensation
- [x] Tests zuerst, neue Datei `dashboard_view_model_partial_failure_test.dart`. Setup wie `save_error_test`: Mo 2026-10-05, Uhr 17:00 (`DateTime(2026, 10, 5, 17)`), Soll 8 h, Saldo 120 min, `running` = Start 08:00, `finishedWithBreak` (08:00-17:00, Pause 12:00-12:30), `profiles: true`, Uhr nie `DateTime.now()`. Neue `stopWrites` = `['A:entry:<moKey>:08:00-17:00', 'A:overtime:135', 'A:lastUpdate']`.
  - **E1 Reihenfolge Stop**: Erfolg -> `writeLog == stopWrites`. Mit `holdSaves` (Eintrag-Write gehalten): `saveOvertimeCalls == 0`, State noch laufend (`workEnd == null`), `isSaving == true`; nach Freigabe Saldo-Write; mit `holdSaveOvertime`: Eintrag schon im Log, State **noch** laufend, Timer 1; nach Freigabe State beendet, Timer 0. (Rot heute: Saldo zuerst.)
  - **E2 Eintrag-Fehler Stop** (`failSaves`): Ergebnis `false` (Rot: `true`), `writeLog` leer, `work.saved` leer, `savedOvertimes` leer, `saveOvertimeCalls == 0`, State laufend, `periodicTimerCount == 1`, `isSaving == false`, Snackbar-Vertrag nur über Ergebnis. Log: Level error, enthält `Exception` **nicht als Inhalt**, nur `runtimeType`, enthält nicht `2026-10-05` (Muster Logger-Capture aus `save_error_test`). Danach `failSaves=false`: Wiederholen -> `writeLog == stopWrites` (genau ein Saldo-Write). Danach Autosave-Beleg in separatem Szenario: nach E2 `tick(30 s)` schreibt Autosave den **laufenden** Eintrag (`saved.last.workEnd == null`).
  - **E3 Eintrag-Fehler geschlossener Eintrag** (Tabelle über `setManualEndTime`, `setManualStartTime`, `updateBreak`, `deleteBreak`, `startOrStopBreak`, Seed `finishedWithBreak`, `failSaves`): `false`, `work.store` identisch zum Seed (`identical`), State-Eintrag/`initialOvertime`/`totalOvertime` unverändert, `overtime.stored == 120`, `saveOvertimeCalls == 0`; Folge-Beleg R412-b: `h.switchProfile('B')` und zurück (Reload) -> `initialOvertime` unverändert (Rot heute: um Neu-Alt verfälscht). Wiederholen ohne Fehler: `true`, Log `entry, overtime, lastUpdate`.
  - **E4 Saldo-Fehler Stop** (`failSaveOvertime`): `false`, `writeLog == ['A:entry:<moKey>:08:00-17:00', 'A:entry:<moKey>:08:00--']` (Eintrag neu, dann Vorzustand), `work.store[moKey]` gleich Seed, kein `lastUpdate`-Eintrag (`overtime.lastUpdate` unverändert), State laufend, Timer 1, `isSaving == false`. Wiederholen: erfolgreicher Stop mit `stopWrites` am Ende.
  - **E5 Saldo-Fehler geschlossener Eintrag** (Tabelle wie E3, `failSaveOvertime`): `false`, `writeLog` = `[entry(neu), entry(alt)]`, `store` gleich Seed, State unverändert.
  - **E6 `lastUpdated`-Kopplung**: (a) bei Saldo-Fehler (E4) `overtime.lastUpdate` und `savedKeepLastUpdated` unberührt; (b) `failSaveLastUpdate` (Saldo ok, lastUpdate scheitert): `false`, Eintrag kompensiert (`store` = Seed), `overtime.stored` bereits neu (bekannte Grenze, im Test festgeschrieben und kommentiert). (c) `serverNow` am Fake gesetzt: Eintrag-Fehler -> `overtime.lastUpdate` bleibt `null` (nichts geschrieben).
  - **E7 Kompensation scheitert** (`failSaveCalls = {2}` bei `failSaveOvertime`): kein Wurf, Ergebnis `false`, `writeLog == [entry(neu)]`, Log Level error mit "Kompensation" und `runtimeType`, ohne `2026-10-05`. Stop-Fall: State laufend, Timer 1, `tick(30 s)` -> Autosave schreibt laufenden Eintrag, `store` wieder Seed (Heilung). Geschlossener Fall (zweite Ausprägung): State alt, `store` neu (festgeschriebene Grenze), Wiederholen derselben Aktion schreibt konsistent (`store` = neu, Saldo neu).
  - **E8 Vortags-Lauf über Mitternacht**: Seed Start Mo 22:00, Uhr Mo 23:00 -> `h.clock.jumpTo(DateTime(2026, 10, 6, 1))`, Stop. Erfolg: Reinit auf Di (`workEntry.date` Di), Logreihenfolge `entry(Mo), overtime, lastUpdate`. Eintrag-Fehler: `false`, **kein** Reinit (State bleibt Mo, laufend), Timer 1, kein Saldo-Write. Saldo-Fehler: `false`, kein Reinit, Kompensation geschrieben. Alle Daten als `DateTime(...)`-Konstanten.
  - **E9 Tageswechsel im Schreibfenster**: Stop 23:59:50 Mo mit `holdSaves`, `jumpTo(Di 00:00:10)` + `tick(1 s)`: State bleibt laufend (`_onDayChange` ignoriert laufende), nach Freigabe Reinit auf Di; mit Eintrag-Fehler statt Freigabe: weiter laufend, kein Reinit.
  - **E10 Profilwechsel mitten in der Aktion** (`holdSaveOvertime`, danach `h.switchProfile('B')`, dann `failSaveOvertime = true` und Freigabe): `writeLog` enthält `A:entry(neu)`, `A:entry(alt)`, **kein** `B:`-Eintrag, Ergebnis `false`, State/Timer von B unberührt, `isSaving` von B unverändert. Variante Eintrag-Fehler überholt (`failSaves` am A-Repo, Wechsel während `holdSaves`): `false`, nichts in B. Variante Erfolg überholt: `true`, Writes `entry, overtime, lastUpdate` in A.
  - **E11 Gegenproben (müssen von Anfang an grün bleiben)**: Pause auf **laufendem** Eintrag mit `failSaves` (Bestand "H", `dashboard_view_model_break_test`), Start mit `failSaves` (#336-Test in `dashboard_view_model_test` Z. ~228), `clearEndTime`/`startNewSession*` mit `failSaves` -> `true`, Timer läuft, Autosave heilt.
- [x] **Rot-Nachweis (Pflicht):** Fakes (Schritt 1) vorhanden, VM unverändert -> neue Datei ausführen. Erwartet rot: E1 (alle Zeilen), E2, E3, E4, E5, E6(b/c), E7, E8 (Fehlerfälle), E9, E10; erwartet grün von Anfang an: E11, E6(a), Erfolgsfälle von E8. Namen der roten Tests plus je ein Assertion-Auszug in `412-pr.md`.
- [x] Impl: `_ActionCtx.before` + `_beginAction`; Zweige in `_recalculateStateAndSave` wie "Verhalten im Detail" (ohne Heilung); `_compensateEntry`.
- [x] Bestandstests anpassen (siehe Abschnitt "Bestandstests", Klassifikation per Lauf der ganzen Suite). Reihenfolge: erst Impl, dann ganze Suite, dann jeden roten Bestandstest einzeln klassifizieren und in `412-pr.md` begründen; **vorher keinen Bestandstest anfassen**.
- [x] Grün: neue Datei + gesamte Suite.

### Schritt 3: Timeout-Zusammenspiel und Heilung
- [x] Tests zuerst (gleiche Datei, Abschnitt "Timeout"; nur E12/E15/E16, E13/E14/E17 entfallen). Hilfsmuster: Hold nur für den **ersten** Write (`holdSaves = true`, nach Entstehen von `pendingSaves.single` sofort `holdSaves = false`), damit Autosave/Heilung/Kompensation nicht erneut halten; Aktionsbeginn auf t=5 s legen (PR-1-Hinweis: Autosave-Tick auf Sekunde 30, sonst Tie), jeder Hold wird vor Szenario-Ende freigegeben (Timer-Leak-Check).
  - **E12 Eintrag-Timeout Stop**: bei 29 s noch offen und zweiter Tap verworfen (`true`), bei 30 s Ergebnis `false`, State laufend, Timer 1, `isSaving == false`, `saveOvertimeCalls == 0`, Log mit `TimeoutException` ohne `2026-10-05`. (Ersetzt T2 aus PR 1.)
  - **E13 Spätes Landen, Heilung**: nach E12 landet der Original-Write (Completer freigeben): `writeLog` zeigt `entry(neu)` gefolgt von `entry(Wahrheit)`; `store` = laufender Eintrag; kein Saldo-Write. Varianten: (a) Autosave lief **vor** dem Landen (`tick`), Landen überschreibt -> Heilung stellt den laufenden Eintrag wieder her (Rot ohne Heilung: `store` bleibt geschlossen); (b) Wiederholter Stop war zwischendurch **erfolgreich** (State beendet): Heilung schreibt den beendeten Eintrag, `store` bleibt beendet, kein Zurückkippen; (c) Landen während einer laufenden Aktion (`_busy`): keine Heilung, `logger.i`; (d) Aktion überholt (Profilwechsel vor Landen): Heilung schreibt `before` in A, nichts in B; (e) Original wirft nach dem Timeout: keine Heilung, kein unbehandelter Fehler (kein Zonenfehler); (f) Original landet nie: kein Heilungs-Write, Szenario endet ohne Leak (Completer am Ende freigegeben).
  - **E14 Geschlossener Eintrag + Eintrag-Timeout** (`updateBreak`): `false` nach 30 s, State unverändert; spätes Landen -> Heilung schreibt Vorzustand (`store` = Seed).
  - **E15 Saldo-Timeout + Kompensation**: `holdSaveOvertime`, bei 30 s `false`, `writeLog == [entry(neu), entry(alt)]` (Kompensation direkt nach dem Timeout, nicht erst nach Freigabe); spät landender Saldo (`A:overtime:135`) holt weder `lastUpdate` noch Eintrag nach (`timedOut`-Guard, PR-1-Test angepasst); Wiederholen vollständig.
  - **E16 Kompensation-Timeout**: `failSaveOvertime` + gehaltene Kompensation (zweiter Eintrag-Write hängt): nach +30 s Ergebnis `false`, Flag frei, Gesamtdauer 30 s (Saldo-Fehler sofort + 30 s Kompensation), danach Wiederholen möglich.
  - **E17 Autosave-Timeout landet spät** (Erweiterung PR-1-T3): Autosave hängt, Stop läuft nach dessen Timeout durch (`store` beendet), dann landet der Autosave: Heilung schreibt den beendeten State; `store` bleibt beendet (Rot ohne Autosave-Heilung: `store` wieder offen).
- [x] **Rot-Nachweis:** E12, E13a/b/d, E14, E15, E16, E17 rot gegen den Stand nach Schritt 2; E13e/f und E13c grün-von-Anfang (Wächter). Ausgaben in `412-pr.md`.
- [x] ~~Impl: `_healAfterLateWrite`~~ (entfallen, Entscheidung Hauptsession) (Action-Variante + Autosave-Variante), Aufruf bei `TimeoutException` im Eintrag-Write der Saldo-Aktionen und im `_autoSave`-Catch.
- [x] Grün: Datei + Suite.

### Schritt 4: `stopRunningForSwitch` und UI-Vertrag
- [x] Tests zuerst:
  - **E18** (`dashboard_view_model_switch_test`): `stopRunningForSwitch` bei Eintrag-Fehler -> `false`, State laufend, kein Wechsel (Grenze (3) aus #388 entfällt); bei Saldo-Fehler weiterhin `false` plus Kompensation im Log. Bestehender Erfolgsfall mit neuer `stopWrites`-Reihenfolge.
  - **E19** (`work_profile_view_model_guard_test`): `checkSwitchAllowed(confirm: true)` bei Eintrag-Fehler -> `saveFailed`, Profil bleibt A.
  - **E20** (Widget, `dashboard_screen_save_error_test`, de + en): Stop-Tap bei `failSaves` -> Snackbar `dashboardSaveError`, Button wieder aktiv, Anzeige "läuft" (vorher: stiller Erfolg).
- [x] **Rot-Nachweis:** E18, E19, E20 rot (Eintrag-Fehler liefert heute `true`).
- [x] Impl: keine Codeänderung in `stopRunningForSwitch`/Screen erwartet (Wirkungsprüfung `!_isRunning` bleibt). Nur Doc-Kommentar von `stopRunningForSwitch` aktualisieren (Eintrag-Fehler -> `false`).
- [x] Grün: Suite.

### Schritt 5: Texte
- [x] `@dashboardSaveError`-Beschreibung in `app_de.arb` (Eintrag oder Saldo, Zustand bleibt unverändert, Aktion kann wiederholt werden); `flutter gen-l10n`. Kein neuer Key, `app_en.arb` unverändert. Test: vorhandene l10n-Tests bleiben grün.

### Schritt 6: Doku, Checks, Mutationsproben
- [x] `mobile/CLAUDE.md` (Doku-Nachzug, jeweils mit #412):
  - **#388** "Writes einer Aktion": Satz zu "Fehler beim Saldo-Write" anpassen (jetzt Eintrag-Fehler -> `false`, nichts geschrieben; Saldo-Fehler -> Kompensation); **Reihenfolge-Entscheidung**: die Entscheidung "Eintrag und Saldo in der bestehenden Reihenfolge Saldo->Eintrag" wird durch #412 bewusst überholt (nur der Eintrag ist rückrollbar), mit Begründung. **Grenze (3)** ersetzen: Eintrag-Fehler führt jetzt zu `false` und der Wechsel unterbleibt; nur noch Doppelfehler (Saldo- plus Kompensationsfehler) als Rest.
  - **#402**: Absatz "Stop-Pfad" (Reihenfolge Eintrag -> Saldo -> State), "Kein Saldo-Rollback" um **Eintrag-Kompensation über `_ActionCtx.before`** ergänzen; Rückgabe-Vertrag `false` = Eintrag- oder Saldo-Fehler oder Tag nicht ladbar; **Regelwerk Teilfehler** um (4) "Eintrag-Kompensation ist immer zulässig (kein `lastUpdated`-Bezug), Kompensationsfehler nur loggen" und (5) "nicht rückrollbare Writes ans Ende der Kette" ergänzen; Aktionen ohne Saldo-Block bleiben optimistisch (E2) mit Autosave-Heilung; **Bekannte Grenzen** neu fassen: (1) alt entfällt; Rest: Doppelfehler Saldo+Kompensation (Stop-Fall heilt der Autosave, geschlossener Eintrag: Eintrag neu/Saldo alt bis zur nächsten Aktion), `saveLastUpdateDate`-Fehler nach `saveOvertime` (nur Nicht-API), fehlgeschlagener Eintrag-Write, der trotzdem landete (mehrdeutiger Fehler, nur Timeout wird geheilt), Firebase-Overtime-Cache nach Fehler (Folge-Issue). Tests-Zeile um `dashboard_view_model_partial_failure_test` und Fake-Hooks `failSaveCalls`/`failSaveLastUpdate` erweitern.
  - **#413**: erster Bullet (Reihenfolge "unverändert") aktualisieren, Timeout (b) neu (`false` + Heilung statt geschluckt `true`), Grenze (4) streichen, Hinweis Zeitbudget 120 s, Heilung nach spätem Landen (inkl. Autosave) und Grenze 2 präzisieren.
  - **#385** Beenden-Absatz: "Der Dashboard-Stop bekommt bewusst keinen Saldo-Rollback ... (#402/#412)" um "stattdessen Eintrag vor Saldo und Eintrag-Kompensation; `CloseOpenWorkEntry` behält seine Reihenfolge Saldo->Eintrag mit Saldo-Rollback (inkrementell, `keepLastUpdated: true`)" ergänzen.
- [x] Checks aus `mobile/`: `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-fatal-infos`, `dart run custom_lint`, `flutter test`. Neue/geänderte Testdateien zusätzlich unter `TZ=UTC`, `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland` (CI: Europe/Berlin). `build_runner` nicht nötig, `gen-l10n` nur wegen Schritt 5.
- [x] Mutationsproben (Mutation einbauen, Zieltest muss rot werden, zurücknehmen; Ergebnisse in `412-pr.md`):
  | # | Mutation | Erwartet rot |
  |---|---|---|
  | N1 | Reihenfolge zurückdrehen (Saldo vor Eintrag) | E1, E2, E3 |
  | N2 | Eintrag-Fehler wieder schlucken (`true`, State setzen) | E2, E3, E8, E18 |
  | N3 | Kompensation entfernen | E4, E5, E10 |
  | N4 | Kompensation schreibt `updatedEntry` statt `ctx.before` | E4, E5 |
  | N5 | `before` erst in `_recalculateStateAndSave` aus `state.workEntry` lesen | `startOrStopBreak`-Zeile in E5 (Zwischen-`await` mit gehaltenem `toggleBreak`: Test mit Hold-fähigem Toggle) |
  | N6 | Kompensationsfehler weiterwerfen | E7 |
  | N7 | Kompensation läuft nicht bei überholter Aktion | E10 |
  | N8 | Kompensation über `ref.read(saveWorkEntryUseCaseProvider)` statt `ctx` | E10 (B-Eintrag im Log) |
  | N9 | State vor den Writes setzen | E1 (State-Zeilen), E2 |
  | N10 | Reinit auch bei Fehler | E8 |
  | N11 | Kompensation fasst `lastUpdate` an (`saveLastUpdateDate` nach Kompensation) | E4, E6(a) |
  | N12 | Saldo-Aktionen-Zweig auch für Aktionen ohne Saldo-Block | E11 |
  | N13 | `hasSaldoBlock`-Bedingung nur `workEnd != null` | E11 (`clearEndTime`/Neue-Session-Zeilen bleiben grün, prüfen ob Zeile ohne Start existiert; sonst als äquivalent dokumentieren) |
  | N14 | Heilung entfernen | E13a/b/d, E14, E17 |
  | N15 | Heilung ohne `!_busy`-Prüfung | E13c |
  | N16 | Heilung sofort statt nach dem Landen | E13a (Reihenfolge) |
  | N17 | Heilung schreibt immer `before` statt VM-Wahrheit | E13b |
  | N18 | Fehler des Originals nach Timeout nicht behandeln | E13e (Zonenfehler) |
  | N19 | Eintrag-Timeout entfernen | E12 (Test hängt, Timeout des Testlaufs) |
  | N20 | Kompensation ohne Timeout | E16 |
  | N21 | Eintrag-Fehlerlog mit `$e` und Eintragsdaten | E2 (Log-Test) |
  | N22 | Eintrag-Timeout liefert wieder `true` | E12 |

## Bestandstests
**Nur zwingende Anpassungen, einzeln begründet in `412-pr.md`.** Methode: nach der Impl in Schritt 2 die ganze Suite laufen lassen, jeden roten Test in genau eine Klasse einordnen (ein Test, der in keine Klasse passt, ist ein Befund und geht vor jeder Änderung an die Hauptsession):
- **A: Reihenfolge-Konstante** (`stopWrites` neu `entry, overtime, lastUpdate`): `save_error_test` Z. 48, `busy_test` Z. 47, `switch_test` Z. 173 (jeweils lokale Konstante) und die davon abhängigen Erwartungen, u. a. S-3, S-5, B2, B3(a), B14, B15, B12a/b, `stopRunningForSwitch`-Erfolgsfälle.
- **B: Saldo-Fehler schreibt jetzt das Paar Eintrag neu + Vorzustand** (statt "nichts geschrieben"): `save_error_test` S-1 (`writeLog`/`work.saved` leer), `busy_test` B3(a), B9b (`saved.length == 1` -> Autosave plus Kompensationspaar), B11-T1 (`writeLog`-/`saved`-Erwartungen beim Saldo-Timeout), `profile_test` Z. ~351-407 (überholte Saldo-Fehler-Tests), `guard_test` Z. 117, `switch_test` Z. 100, Widget-Test `dashboard_screen_save_error_test` Z. 98/223-253 falls sie `work.saved` prüfen.
- **C: Hold-Tests mit geänderter Freigabe-Reihenfolge** (`holdSaveOvertime` hält jetzt **nach** dem Eintrag-Write; der Eintrag ist beim Hold schon im Log, State noch laufend): `busy_test` B2, B6, B7 (Zeilen mit Saldo-Aktionen), B9a (`h.work.log` enthält kein `save:` -> stattdessen "kein Autosave-Eintrag"), B10, B14a, B15b, `save_error_test` S-5 und "überholte Aktion"-Tests, `switch_test` Z. 195/233, `profile_test` Z. 82/136. Anpassung = Erwartung des Logs/States im Hold-Fenster, nie die Absicht des Tests.
- **D: Verhaltensänderung per Entscheidung** (genau diese beiden): `save_error_test` "Eintrag-Write scheitert nach Saldo: bleibt true (#412 offen)" -> umbenennen und auf `false`/nichts geschrieben umstellen (oder in E2 aufgehen lassen); `busy_test` T2 "(PR 2 aendert dies)" -> `false` und Name ohne Zusatz. Dazu `busy_test` T3 (Autosave-Timeout): Erwartung `writeLog` entsprechend A.
- **Erwartet unverändert grün (Wächter):** `dashboard_view_model_test` #336-Test (Start-Pfad), `dashboard_view_model_break_test` "H", `S-5b` (Bruttodauer bei Tick im Eintrag-Write-Fenster; der Test bleibt grün, sein Anlass entfällt, weil der Timer nie mehr einen beendeten State rechnet — Test und Timer-Kommentar bleiben, kein Refactoring), `day_change`-, `reload`-, `overtime`-, `resume`-Tests, `open_entry_view_model_test`, `close_open_work_entry_test` (CloseOpenWorkEntry unberührt).
- Fakes, die `DashboardViewModel` überschreiben, bleiben kompatibel (Signaturen unverändert).

## Bekannte Grenzen (in CLAUDE.md und PR festhalten)
1. **Doppelfehler** (Saldo-Fehler und Kompensationsfehler): Stop-Fall heilt der Autosave innerhalb 30 s bzw. das Wiederholen; geschlossener Eintrag: Eintrag neu/Saldo alt/State alt bis zur nächsten Aktion, Reload davor verfälscht die Basis um Neu-Alt (zweite Ausprägung aus der Research, jetzt nur noch bei Doppelfehler).
2. **Mehrdeutiger Eintrag-Fehler:** Wirft ein Write, obwohl er serverseitig landete (z. B. Antwort verloren), wird nicht kompensiert (Entscheidung Hauptsession: "nichts geschrieben"); nur der Timeout-Fall wird nachträglich geheilt.
3. **Heilung ist best-effort:** Landet der Original-Write nie, gibt es keine Heilung (und nichts, was zu heilen wäre); landet er während einer anderen laufenden Aktion, entscheidet die Reihenfolge im Transport (Aktion schreibt den neuesten Stand selbst).
4. **Kompensation/Saldo ohne Heilung:** Ein per Timeout aufgegebener Saldo- oder Kompensations-Write kann später landen (unbekannter Ausgang, Saldo absolut/idempotent, Wiederholen korrigiert).
5. `saveLastUpdateDate`-Fehler nach `saveOvertime` (nur Nicht-API-Repos): Saldo neu, `lastUpdated` alt, Eintrag kompensiert.
6. Firebase-Overtime-Cache vor dem Write gesetzt (Folge-Issue). Web: Reentranz-Sperre/Kompensation (Folge-Issue, #394).
7. Zeitbudget einer Aktion bis 120 s (Flag gesetzt, Taps verworfen, Buttons deaktiviert).
8. Aktionen ohne Saldo-Block bleiben bei Eintrag-Fehler still (E2).

## Validierung
- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze --no-fatal-infos`
- `dart run custom_lint`
- `flutter test` (gesamt) sowie neue/geänderte Dateien unter `TZ=UTC`, `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland`
- Rot-Nachweise je Schritt 2-4, Klassifikation der Bestandstests und Mutationsproben N1-N22 in `mobile/thoughts/412-pr.md`

## Offene Fragen
Keine blockierenden. Zur Kenntnis: Die "Heilung nach spätem Landen" (Schritt 3, inkl. Autosave-Variante) geht über die Entscheidungen der Hauptsession hinaus, ist aber die Absicherung für das geforderte Timeout-Race. Wird sie abgelehnt, entfallen E13-E14, E17, N14-N18 und die Grenze 3; E12/E15/E16 bleiben.
