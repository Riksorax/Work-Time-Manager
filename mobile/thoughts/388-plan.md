# Mobile-Plan: #388 — PR 1 (Option A): Profilwechsel im Dashboard, Race-Fix, Tests, Doku
Erstellt: 2026-10-04
Research: mobile/thoughts/388-research.md (inkl. "Entscheidungen zu den offenen Fragen (Hauptsession)", gilt vor allem anderen)
Vorbild: web/thoughts/380-plan.md (PR 1, Stufe 1)
**PR 2 (Dialog "Beenden und wechseln", Option B, ARB-Keys, `stopRunningForSwitch`) ist NICHT Teil dieses Plans.** PR 1 verweist mit `Refs #388` (nicht `Closes`).

## Ziel
Ein Profilwechsel bei laufendem oder gerade gespeichertem Dashboard-Eintrag verfälscht keine Daten mehr: alle Writes einer Aktion landen im Profil des Aktionsbeginns (Eintrag **und** Saldo), nur Folgeschritte (State, Timer, Reinit) werden bei Überholung abgebrochen. Das "Einfrieren" (Timer wird beim Wechsel ohne Speichern gestoppt, Rückwechsel setzt fort) ist per Test abgesichert und in `mobile/CLAUDE.md` als bewusste Entscheidung dokumentiert. `deleteProfile(aktiv)` wechselt zuerst, dann API.

## Befunde aus dem Code (ergänzen/schärfen die Research)
- `startOrStopBreak` hat zwischen `_ensureCurrentDay()` und `_recalculateStateAndSave` ein eigenes `await toggleBreak.call(...)`. Der Aktionskontext darf deshalb **nicht** erst in `_recalculateStateAndSave` festgehalten werden, sondern muss **in jeder Aktion direkt nach `_ensureCurrentDay()`** (synchron, vor dem ersten weiteren `await`) entstehen und als Parameter übergeben werden. Gleiches gilt für den `toggleBreakUseCaseProvider`-Read.
- `_recalculateStateAndSave` hat drei `ref.read(...Provider)` nach/zwischen `await`s: `overtimeRepositoryProvider` (vor dem ersten `await`, ok), `settingsRepositoryProvider` in `_checkOvertimeWarning` (nach den Saldo-`await`s, Profil B möglich) und `saveWorkEntryUseCaseProvider` (nach den Saldo-`await`s, **der Race-Defekt**). Zusätzlich `todayProvider.notifier` im Reinit-Zweig.
- `_load` hat bereits Gen-Guard (`stale()`); `_autoSave`, `_checkOvertimeWarning`, `_recalculateStateAndSave` nicht. `_autoSave` ist sicher (löst UseCase vor dem `await` auf, Timer wird in `onDispose` abgebrochen); sein Kommentar "Reinit findet nie bei laufendem Timer statt" ist durch den Profilwechsel überholt und wird korrigiert (nur Kommentar).
- `ActiveWorkProfileIdNotifier` (`providers.dart` Z. 255) ist ein manueller `NotifierProvider<…, String?>`: `build()` liest Auth + SharedPreferences, `setActiveProfile` setzt `state` synchron. Für Tests reicht eine Subklasse mit `build() => null` und einem `setActiveProfile`, das nur `state` setzt (kein Auth/Prefs).
- **Keine Provider-Annotationen betroffen** (`@riverpod`-Dateien bleiben unverändert) -> `build_runner` nur dann, wenn Schritt 0 neue `@GenerateMocks` bräuchte (geplant: nein, nur handgeschriebene Fakes). Keine ARB-Keys, kein `flutter gen-l10n`.

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Neue Entity / Feld? | nein | reine VM-/Test-Änderung |
| Repository-Interface ändern? | nein | Hybrid-/Firebase-/Local-/ApiDataSource unberührt; Profil bleibt konstruktor-gebunden. Fix = Aufrufer löst Repos/UseCases **zum Aktionsbeginn** auf und hält sie fest |
| Neuer Provider? | nein | kein `@riverpod`, kein `build_runner` (nur falls Schritt 0 entgegen Plan `@GenerateMocks` nutzt) |
| Kontext-Typ | kleine private Klasse `_ActionCtx` in `dashboard_view_model.dart` (Felder: `gen` (`_initGen`), `saveWorkEntry` (UseCase), `overtimeRepository`, `settingsRepository`) | Entspricht Web-`ActionCtx`; Eintrag und Saldo landen garantiert im selben Profil. Profil selbst muss nicht gespeichert werden: das Repo ist daran gebunden |
| Überholungsprüfung | `ctx.gen != _initGen` (Profilwechsel invalidiert -> `onDispose` -> `_initGen++`) | riverpod 3.0.3: `ref.mounted` bleibt über den Rebuild `true`, taugt für Profilwechsel nicht; `ref.mounted` bleibt nur für echten Dispose als zusätzliche Bedingung (`!ref.mounted \|\| gen != _initGen`) |
| Semantik bei Überholung | Writes (Saldo, `lastUpdate`, Eintrag) **immer vollständig** mit festgehaltenen Objekten und vor dem `await` eingefrorenen Werten (`newTotalOvertime`, Eintrag); abgebrochen werden `state = …`, `_startTimerIfNeeded`, Reinit nach Vortags-Stop | Hauptsession-Entscheidung 2; "komplett abbrechen" ließe A inkonsistent (Saldo gespeichert, Eintrag nicht). Reihenfolge Saldo -> Eintrag bleibt |
| Verhalten bei echtem Dispose (Logout, Container-Dispose) | Wie Überholung: Writes laufen mit festgehaltenen Objekten zu Ende, Folgeschritte entfallen. **Änderung gegenüber heute** (`if (!ref.mounted) return;` zwischen Saldo und Eintrag verwirft den Eintrag-Write). Siehe offene Frage O1 | Konsistente Regel "eine begonnene Aktion schreibt vollständig"; Ausnahme wäre schwer zu begründen |
| Warnung (`_checkOvertimeWarning`) | bekommt das festgehaltene `settingsRepository` als Parameter; läuft weiter wie heute (defensiv, `try/catch`) | Schwellwerte des Profils der Aktion statt B. Notification-Service-Read bleibt `ref.read` im `try/catch` (kein Profilbezug) |
| `deleteProfile(aktiv)` | zuerst `setActiveProfile(null)` (synchron, ohne `await` auf Prefs-Write), dann `repository.deleteProfile`, dann `invalidate(workProfiles)`; bei API-Fehler Rückwechsel auf `profileId` und Exception weiterwerfen | Hauptsession-Entscheidung 3 (wie Web); schließt Autosave-Fenster. Vorher aktives Profil mit `ref.read` festhalten, **vor** dem `await` |
| `addProfile` | unverändert (Guard vor API-Aufruf ist PR 2) | Entscheidung 4 |
| Nebenbefund Stop-Pfad | Test bestätigt/widerlegt nur, keine Code-Änderung | Entscheidung 6; Behebung PR 2 bzw. Folge-Issue (Hauptsession) |
| Auto-Stop offener Einträge / Parallelbetrieb | nicht umgesetzt, nur dokumentiert | Entscheidung 7 |
| Premium-Gate / Backend / Firestore-Regeln / Web | nein / nein / nein / nein | rein Mobile |
| Neue Texte | nein | keine UI-Änderung |

## Dateien
| Datei | neu/geändert | Zweck |
|---|---|---|
| `mobile/test/support/fake_repositories.dart` | geändert | Schreib-Log mit Repo-Label, Hold-Möglichkeit für Writes, `failSaves` für Saldo (Schritt 0, verhaltensneutral) |
| `mobile/test/support/dashboard_harness.dart` | geändert | optionaler Profil-Modus, `switchProfile(id)`-Helper (Schritt 0) |
| `mobile/test/presentation/view_models/dashboard_view_model_profile_test.dart` | neu | Fälle 1-9 der Research (Schritte 1, 2, 4) |
| `mobile/lib/presentation/view_models/dashboard_view_model.dart` | geändert | `_ActionCtx`, Kontext in allen Schreibaktionen, Guard in `_recalculateStateAndSave`, Kommentar `_autoSave` (Schritt 2) |
| `mobile/lib/presentation/view_models/work_profile_view_model.dart` | geändert | `deleteProfile`-Reihenfolge (Schritt 3) |
| `mobile/test/presentation/view_models/work_profile_view_model_test.dart` | geändert | Reihenfolge-/Fehlerfälle `deleteProfile`, `addProfile` friert Dashboard ein (Schritt 3) |
| `mobile/CLAUDE.md` | geändert | Abschnitt "Profilwechsel (#388)" (Schritt 5) |
Unverändert: `providers.dart`/`providers.g.dart`, alle Repository-Implementierungen, `work_profile_switcher.dart`, ARB-Dateien.

## Test-Konventionen (alle Schritte)
- Feste lokale Daten: Mo `DateTime(2026, 10, 5, …)`; Soll Mo-Fr 40 h = 8 h (Profil A = `FakeSettingsRepository`-Default), Profil B abweichend (z. B. `workdays [2,3,4]`, `weeklyHours 24`, also Montag = Zusatztag, `isExtraDay`). Saldo A 120 min, B 30 min. Kein `DateTime.now()`, keine Zeitzonenannahme, `FakeClock` mit `bind(async)`.
- Alles in `fakeAsync` über `scenario(...)`/`Harness` (Timer-Leak-Check am Ende). Wechsel immer über den Harness-Helper `switchProfile(id)` (setzt Profil, `elapse(Duration.zero)` für den Scheduler-Task, `flushMicrotasks`); nie von Hand verteilen.
- Läufe aus `mobile/`: `TZ=Europe/Berlin flutter test` (CI) sowie lokal `TZ=UTC`, `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland`. `dart format --set-exit-if-changed lib test` vor jedem Commit.
- Rot-Nachweis: vor der Impl die roten Tests laufen lassen und **Fehlermeldungen notieren** (für `388-pr.md`); danach grün.
- Bestehende Tests (`dashboard_view_model*_test.dart`, `day_change`) bleiben **unverändert** und grün. Jede Anpassung eines Bestandstests ist ein Warnsignal und an die Hauptsession zu melden.

## Schritte (TDD, Layer: test/support -> domain-nah (VM) -> Doku; kein data/provider/l10n-Eingriff)

### Schritt 0: Harness um optionalen Profil-Modus (verhaltensneutral, eigener Commit)
- [ ] Baseline: vollständiger `flutter test` unter `TZ=Europe/Berlin` grün (Ausgangsstand notieren).
- [ ] `fake_repositories.dart` (alle Erweiterungen mit Default = bisheriges Verhalten):
  - gemeinsames, optionales Schreib-Log: Konstruktor-Parameter `label` (z. B. `'A'`/`'B'`) und `List<String>? writeLog`; jeder Write hängt `"<label>:entry:<yyyy-MM-dd>:<start>-<end>"` bzw. `"<label>:overtime:<minuten>"` / `"<label>:lastUpdate"` an (bei `label == null` kein Log, damit Bestand unberührt).
  - `FakeWorkRepository`: `holdSaves` + `pendingSaves` (Completer-Liste, analog `holdReads`/`pendingReads`); Hold vor dem Eintragen in `store`/`saved`.
  - `FakeOvertimeRepository`: `holdSaveOvertime` (Completer-Liste `pendingOvertimeSaves`) und `failSaveOvertime` (wirft in `saveOvertime`).
- [ ] `dashboard_harness.dart`: optionaler Parameter `profiles: false` (`Harness(async, start, {bool profiles = false})`; `scenario(..., profiles: …)` reicht ihn durch). Bei `true`:
  - zweites Repo-Set `workB`/`overtimeB`/`settingsB` (Labels `A`/`B`, gemeinsames `writeLog`); die bisherigen Felder `work`/`overtime`/`settings` bleiben = Profil A.
  - Test-Notifier (Subklasse von `ActiveWorkProfileIdNotifier`, `build() => null`, `setActiveProfile` setzt nur `state`) via `activeWorkProfileIdProvider.overrideWith(...)`.
  - `workRepositoryProvider.overrideWith((ref) => ref.watch(activeWorkProfileIdProvider) == null ? work : workB)`, analog Overtime und Settings (Watch ist entscheidend: erzeugt die Kaskade-Invalidierung wie in `providers.dart`).
  - `switchProfile(String? id)`: `container.read(activeWorkProfileIdProvider.notifier).setActiveProfile(id)`, dann `async.elapse(Duration.zero)` und `flushMicrotasks`.
  - `profiles == false`: weiterhin die festen `overrideWithValue`-Overrides (Bestandsverhalten, Byte-genau gleich).
- [ ] Selbstprüfung: ein Mini-Test im neuen Testfile (oder Harness-Smoke) "Profilmodus: nach `switchProfile('B')` liest das VM B" (Eintrag aus `workB` im State). Muss **grün** sein und beweist die Kaskade im Harness (sonst sind spätere Rot-Nachweise wertlos).
- [ ] Gesamtlauf grün, Bestandstests unverändert. **Commit 1** ("test: Harness mit Profil-Modus (#388)").

### Schritt 1: Profilwechsel-Tests im `DashboardViewModel` mit Rot-Nachweis (Test-Commit vor dem Fix)
Datei `dashboard_view_model_profile_test.dart`, `scenario(..., profiles: true)`. Fälle nach Research Abschnitt 6 (zehn Fälle; Nummern der Research in Klammern).
ROT vor Fix (Race, per Probe bereits belegt) — **zuerst schreiben, laufen lassen, Fehlermeldungen notieren**:
- [ ] **T1 (Research 1)** Stop in A (Uhr 17:00, A: laufend ab 08:00, Saldo 120 min; B: fertiger Eintrag 09:00-12:00, Saldo 30 min), `holdSaveOvertime` auf A, `switchProfile('B')` im Fenster, Hold freigeben: `writeLog` enthält den Eintrag nur mit Label `A`; `workB.store` und `overtimeB.stored` unverändert; State = B (Eintrag 09:00-12:00, Total aus B). Heute rot: Eintrag landet in B, State zeigt A-Eintrag.
- [ ] **T2 (Research 2)** `for`-Schleife/Tabelle über alle Aktionen mit abgeschlossenem Eintrag: `startOrStopTimer` (Stop), `setManualEndTime`, `setManualStartTime`, `updateBreak`, `deleteBreak`, `startOrStopBreak` (je eigenes `scenario`, Vorbereitung: A mit passendem Eintrag; Wechsel im Saldo-Fenster): alle Writes mit Label `A`, keiner `B`. Für `startOrStopBreak` zusätzlich Variante, in der der Wechsel in das `await toggleBreak` fällt (nur testbar, wenn der Fake-Repo-Read hängt; sonst entfällt die Variante und die Begründung kommt in den PR-Text, nicht stillschweigend streichen).
GRÜN vor Fix (Charakterisierung, sichern Einfrieren und bestehende Garantien):
- [ ] **T3 (Research 3) Einfrieren**: A läuft (Autosaves bei 30/60 s vorher), `switchProfile('B')`; 5 Minuten weiter: 0 Writes in A und B nach dem Wechsel, `periodicTimerCount` = B (0, wenn B nicht läuft), State = B-Eintrag, Basis/Total aus B-Saldo, Soll/`isExtraDay` aus B-Settings (Montag = Zusatztag).
- [ ] **T4 (Research 4) Rückwechsel**: zurück auf A: A-Eintrag unverändert (`workEnd == null`, kein Write beim Wechsel), genau 1 Timer, Brutto aus Differenz der Fake-Uhr (inkl. in B verbrachter Zeit; Erwartung aus `clock`-Differenz berechnen, nicht hart kodiert).
- [ ] **T5 (Research 5) Autosave nach Wechsel**: 31 s nach dem Wechsel kein Write mit dem A-Eintrag in B; Parallelbetrieb: A eingefroren, B startet eigenen Timer, Autosave schreibt nur B-Eintrag in B.
- [ ] **T6 (Research 6) Wechsel im Eintrag-Fenster**: `holdSaves` auf A-Eintrag, Wechsel, Freigabe: beide Writes in A, Timerzahl wie B (kein `_startTimerIfNeeded` für B), State bleibt B. Heute grün für die Writes; der Timer-Teil wird erst durch den Fix wirksam abgesichert (siehe Mutationsprobe).
- [ ] **T7 (Research 7) Überholter Lauf**: A -> B -> A mit `holdReads` (B-Lesen hängt): Endzustand A, kein B-Timer; zweite Variante: Wechsel während `holdOvertimeLoad`, spätes Ergebnis von A wird verworfen.
- [ ] **T8 (Research 8) Tageswechsel x Profilwechsel**: Wechsel um 23:59:50, Mitternacht danach (`FakeClock` + `todayProvider`): genau ein gültiger Endzustand, Profilwechsel nutzt die `lastUpdate`-Heuristik (kein `dayChange`).
- [ ] **T9 (Research 9) Cleanup**: nach `dispose` Timer-Zähler 0 (greift bereits über `scenario`; zusätzlich explizit mit laufendem B-Timer und eingefrorenem A).
- [ ] T10 (Research 10, `WorkProfileViewModel`) gehört in Schritt 3.
- [ ] Rot-Nachweis dokumentieren (T1, T2 rot; T3-T9 grün); Gesamtlauf: alle Bestandstests grün. **Commit 2** ("test: Profilwechsel im DashboardViewModel, Race rot (#388)") — der Commit enthält bewusst rote Tests, falls die Hauptsession das nicht will, Commit 2 und 3 zusammenfassen (O2).

### Schritt 2: Race-Fix in `dashboard_view_model.dart`
- [ ] Tests existieren (Schritt 1, T1/T2 rot).
- [ ] Impl:
  - `_ActionCtx` (privat) + `_beginAction()`: liest `_initGen`, `saveWorkEntryUseCaseProvider`, `overtimeRepositoryProvider`, `settingsRepositoryProvider` per `ref.read`, **synchron**.
  - Alle Schreibaktionen rufen `_beginAction()` **direkt nach** `if (!await _ensureCurrentDay()) return;` auf: `startOrStopTimer` (inkl. Stop-Pfad), `startNewSession`, `startNewSessionKeepBreaks`, `setManualStartTime`, `setManualEndTime`, `clearEndTime`, `startOrStopBreak` (vor `toggleBreak`-Read/`await`), `deleteBreak`, `updateBreak`. Ctx wird als benannter Parameter an `_recalculateStateAndSave` gereicht (Pflichtparameter, damit kein Aufrufer vergessen wird; der interne Aufruf aus `_load` Z. 178 mit `save: false` bekommt keinen Ctx -> Parameter optional, nur bei `save: true` verwendet; Assert/Fehler, wenn `save` ohne Ctx).
  - `_recalculateStateAndSave`: `base`/`newTotalOvertime`/Eintrag werden wie heute **vor** dem ersten `await` berechnet (bereits so; nicht nach einem `await` aus `state` nachlesen). Writes über `ctx.overtimeRepository`, `ctx.saveWorkEntry`, `_checkOvertimeWarning(total, ctx.settingsRepository)`.
  - Nach den Saldo-`await`s: `overtaken = !ref.mounted || ctx.gen != _initGen`. Bei `overtaken` **kein** `state = …`, aber der Eintrag-Write läuft weiter (mit `ctx.saveWorkEntry`, try/catch wie heute). Nach dem Eintrag-Write: bei `overtaken` return (kein `_startTimerIfNeeded`, kein Reinit, kein `todayProvider.refresh()`); ansonsten Verhalten unverändert (inkl. `saved`-Reinit-Zweig).
  - Der Fall "Überholung während des Eintrag-Writes" (Fenster 2): `overtaken` wird nach `await saveWorkEntry` erneut ausgewertet (zwei Prüfstellen: nach Saldo-Block, nach Eintrag-Write).
  - `_autoSave`-Kommentar korrigieren (Profilwechsel invalidiert auch bei laufendem Timer, Timer-Abbruch in `onDispose` hält den Zustand korrekt). Keine Logikänderung.
  - Keine Änderung an `_load`, `_ensureCurrentDay`, `_onDayChange`.
- [ ] T1/T2 grün; T3-T9 und alle Bestandstests grün; `flutter analyze --no-fatal-infos`, `dart run custom_lint`, Format-Check.
- [ ] **Mutationsproben** (Quelle ändern, Test laufen lassen, zurücksetzen; Ergebnis in `388-pr.md`):
  - festgehaltenes `ctx.saveWorkEntry` durch `ref.read(saveWorkEntryUseCaseProvider)` ersetzen -> T1/T2 rot.
  - festgehaltenes `ctx.overtimeRepository` durch `ref.read(overtimeRepositoryProvider)` nach dem ersten `await` ersetzen (nur Saldo-Zweig) -> Saldo-Assert in T1/T2 rot (falls nicht rot: Test schärfen, A-Saldo-Eintrag im `writeLog` prüfen).
  - `overtaken`-Guard vor `state =` entfernen -> T1 (State = B) rot; Guard vor `_startTimerIfNeeded` entfernen -> T6/T7 rot (Timerzahl).
  - `ctx` nicht direkt nach `_ensureCurrentDay`, sondern erst in `_recalculateStateAndSave` bilden -> `startOrStopBreak`-Variante in T2 rot (sonst Variante nachrüsten).
  - `onDispose`-Timer-Abbruch entfernen -> T3/T5 rot.
  - `_initGen++` in `onDispose` entfernen -> T7 (überholter Lauf) und Guard-Tests rot.
- [ ] **Commit 3** ("fix: Dashboard schreibt bei Profilwechsel nie ins falsche Profil (#388)").

### Schritt 3: `deleteProfile(aktiv)`-Reihenfolge (`WorkProfileViewModel`)
Tests zuerst in `work_profile_view_model_test.dart` (bestehender Aufbau: `MockWorkProfileRepository`, Container mit Auth-Override):
- [ ] **T10a ROT**: aktives Profil `p1` löschen: bei Aufruf von `repository.deleteProfile` ist `activeWorkProfileIdProvider` bereits `null` (Mock-`thenAnswer` liest den Provider im Callback und hält den Wert fest). Heute: `'p1'`.
- [ ] **T10b ROT**: API-Fehler (`thenThrow`/`thenAnswer((_) async => throw …)`): Exception wird weitergereicht, aktives Profil danach wieder `'p1'` (Rückwechsel).
- [ ] **T10c GRÜN (Bestand/Charakterisierung)**: inaktives Profil löschen: aktives Profil bleibt unverändert, kein Wechsel (auch bei Fehler kein Rückwechsel).
- [ ] **T10d GRÜN**: `addProfile` mit laufendem Dashboard-Timer friert ein (Container mit Dashboard-Fakes aus `test/support`, kein Autosave-Write des A-Eintrags unter dem neuen Profil nach 31 s). Falls der Container-Aufbau zu schwer ist, im Dashboard-Profiltest über `setActiveProfile('p1')` simulieren (gleiche Wirkung) und die Absicht im Kommentar festhalten.
- [ ] Optional **T10e**: `deleteProfile(aktiv)` bei laufendem Dashboard: zwischen Wechsel und API-Delete keine Writes (Hold auf `repository.deleteProfile`, 31 s weiter, `writeLog` leer). Nur umsetzbar mit Dashboard-Fakes; sonst weglassen und im PR als nur-per-Review-gesichert nennen.
- [ ] Impl wie in der Architekturtabelle: Profil vor dem `await` festhalten, bei `activeWorkProfileIdProvider == profileId` zuerst `setActiveProfile(null)` (Future nicht awaiten, wie in den bestehenden Aufrufern), dann API, Fehler -> `setActiveProfile(profileId)` + `rethrow`, Erfolg -> `invalidate(workProfiles)`. Hinweis: Rückwechsel setzt wieder `state` synchron und löst einen Dashboard-Reload für das Profil aus (gewollt).
- [ ] Mutationsprobe: Reihenfolge zurückdrehen -> T10a rot; Rückwechsel entfernen -> T10b rot.
- [ ] Tests grün (inkl. TZ-Läufe). **Commit 4** ("fix: deleteProfile wechselt zuerst, dann API (#388)").

### Schritt 4: Nebenbefund Stop-Pfad bestätigen/widerlegen (nur Test, kein Fix)
- [ ] Test in `dashboard_view_model_profile_test.dart` (oder eigene Gruppe "Nebenbefund Stop-Pfad"), ohne Profil-Modus nötig, `failSaveOvertime = true`, A läuft, `startOrStopTimer()`:
  - Erwartung zu bestätigen: Exception aus `saveOvertime` wird **nicht** gefangen (Future der Aktion schlägt fehl; im `fakeAsync` über `.then/.catchError` oder `expectLater(..., throwsA)` abfangen, nicht als unbehandelter Zonenfehler), `periodicTimerCount == 0` (Timer vor dem Speichern abgebrochen), `state.workEntry.workEnd == null` und `state.workEntry.workStart != null` (State "laufend" ohne Timer), kein Eintrag-Write im `writeLog`.
  - Ergebnis ("bestätigt"/"widerlegt" mit beobachteten Werten) in `388-pr.md` und in die kurze Rückmeldung an die Hauptsession.
- [ ] Commit-Form: als **Charakterisierungstest** mit deutlichem Kommentar ("Ist-Zustand, wird in PR 2 / Folge-Issue umgedreht, siehe #388") nur, wenn die Hauptsession zustimmt (O3); sonst nur als lokale Probe, nicht committen. Default laut Plan: nicht committen, Befund dokumentieren (verhindert, dass ein Fehler als Soll-Verhalten zementiert wird).
- [ ] Keine Impl-Änderung. Falls der Test den Befund **widerlegt**, Doku (Schritt 5) und Hinweis an die Hauptsession entsprechend anpassen.

### Schritt 5: Doku `mobile/CLAUDE.md`
- [ ] Neuer Abschnitt "Profilwechsel (#388)" nach "Tageswechsel (#379)" (Reports-Unterabschnitt #387 bleibt dort), Inhalt:
  - **Einfrieren (bewusste Entscheidung, Option A):** Wechsel invalidiert Repos/UseCases/Dashboard-VM; `onDispose` bricht Timer ab, **ohne Speichern**; Eintrag bleibt im alten Profil mit `workStart` und ohne `workEnd` stehen (wie nach App-Neustart); Rückwechsel setzt fort (Zeit in B zählt in A mit). Autosave schreibt nach dem Wechsel nichts mehr.
  - **Semantik der Writes:** Aktionen halten Gen und Repos/UseCases direkt nach `_ensureCurrentDay()` fest (`_ActionCtx`); Eintrag und Saldo landen immer im Profil des Aktionsbeginns; bei Überholung nur Folgeschritte (State, Timer, Reinit) abgebrochen; Überholungsprüfung über `_initGen` (nicht `ref.mounted`, bleibt über Rebuild `true`, riverpod 3.0.3). Neue Schreibaktionen müssen `_beginAction()` nach `_ensureCurrentDay()` aufrufen und nie `ref.read(...UseCaseProvider)` nach einem `await` nutzen.
  - **`deleteProfile(aktiv)`:** erst wechseln, dann API, Rückwechsel bei Fehler. `addProfile` wechselt automatisch (friert ein), Guard/Dialog ist offen (PR 2).
  - **Bekannte Grenzen:** (1) Parallelbetrieb (A eingefroren und laufend, B startet eigenen Timer); (2) offene Einträge im vergessenen Profil (kein Auto-Stop; Darstellung in Reports/Kalender nicht untersucht); (3) Nebenbefund Stop-Pfad (Ergebnis aus Schritt 4); (4) bereits verfälschte Daten werden nicht repariert; (5) `ProfileScope` im Backend prüft keine Profilexistenz (nicht verifiziert).
  - **Tests:** Harness-Profilmodus (`Harness(profiles: true)`, `switchProfile`, `writeLog`, Hold-Flags), Hinweis auf `elapse(Duration.zero)` im Helper.
- [ ] Prüfen, dass der Abschnitt "Tageswechsel (#379)" keine widersprüchliche Aussage über `_autoSave`/Reinit enthält (aktuell nicht; kein Eingriff nötig).
- [ ] **Commit 5** ("docs: Profilwechsel-Abschnitt in mobile/CLAUDE.md (#388)").

## Validierung (nach Schritt 5, vor PR)
- Aus `mobile/`: `dart format --set-exit-if-changed lib test && flutter analyze --no-fatal-infos && dart run custom_lint && flutter test`.
- `TZ=Europe/Berlin flutter test` (CI), zusätzlich `TZ=UTC`, `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland` (mindestens die Dashboard-Dateien: `dashboard_view_model*_test.dart`, `dashboard_view_model_profile_test.dart`, `work_profile_view_model_test.dart`).
- `build_runner` nur nötig, falls entgegen Plan Provider-Annotationen oder `@GenerateMocks` berührt wurden (dann `dart run build_runner build --delete-conflicting-outputs`, Diff in `*.g.dart`/`*.mocks.dart` prüfen).
- Wiederholungslauf der Profiltests (3x) gegen Flakiness durch Scheduler-Reihenfolge.
- `388-pr.md`: Rot-Nachweise (T1/T2/T10a/T10b), Mutationsproben-Ergebnisse, Nebenbefund-Ergebnis, Hinweis "verfälschte Daten werden nicht repariert", Release-Notes-Hinweis. Commit/PR: Hauptsession/Review (`Refs #388`, nicht `Closes`; PR gegen `develop`).
- Manuelle Verifikation (nicht automatisierbar): Gerät/Emulator mit Premium-Konto, zwei Profile: Stop in A, sofort Profilmenü, B-Eintrag bleibt unverändert; Rückwechsel setzt A fort; Profil löschen (aktiv) mit laufendem Timer.

## Risiken
- Der Fix berührt den zentralen Schreibpfad aller Aktionen; Bestandstests (#379/#386) sind das Sicherheitsnetz und dürfen nicht angepasst werden müssen.
- Verhaltensänderung bei echtem Dispose (Eintrag wird nach begonnener Aktion noch gespeichert, vorher verworfen): gewollt, aber sichtbar (O1).
- Das Harness-Verhalten hängt am riverpod-3.0.3-Detail "Invalidierung -> `onDispose` sofort, Rebuild im Scheduler-Task"; T3/T7 prüfen es indirekt, ein Riverpod-Update ohne Test-Rot ist ausgeschlossen. Vergessenes `elapse(Duration.zero)` -> deshalb nur über `switchProfile`.
- Rote Tests in Commit 2 (Test-vor-Fix) brechen bei einzelnem Cherry-Pick/`git bisect`: Squash-Entscheidung bei der Hauptsession (O2).

## Offene Fragen an die Hauptsession
- **O1:** Verhalten bei echtem Dispose (Logout/Container-Dispose) mitten in einer Aktion: Writes mit festgehaltenen Objekten zu Ende führen (Plan, konsistent zur Überholungsregel) oder wie heute nach dem Saldo abbrechen (`ref.mounted`-Return beibehalten, nur für Profilüberholung Writes vollständig)? Plan wählt "zu Ende führen".
- **O2:** Test-vor-Fix als eigener Commit mit roten Tests (Commit 2) oder Tests und Fix in einem Commit und den Rot-Nachweis nur im PR-Text/`388-pr.md`?
- **O3:** Soll der Nebenbefund-Test (Schritt 4) als Charakterisierungstest committet werden (zementiert den Ist-Zustand bis PR 2) oder nur als lokale Probe laufen? Plan-Default: nicht committen.
- **O4:** `_ActionCtx` hält auch das `settingsRepository` (Schwellwerte der Überstunden-Warnung aus dem Profil der Aktion). Akzeptabel oder Warnung unverändert lassen (liest B nach einem Wechsel; reine Benachrichtigung, geringfügig)?

## Entscheidungen zu den offenen Fragen (Hauptsession)

- **O1:** Ja, eine begonnene Aktion schreibt auch bei echtem Dispose (Logout) mit den festgehaltenen Objekten zu Ende (wie Web). Schlägt ein Write dabei fehl (z. B. Auth weg), wird der Fehler geloggt und geschluckt (kein Absturz, keine Folgeschritte). Mit Test belegen und im PR-Text als Verhaltensänderung nennen.
- **O2:** Test und Fix im selben Commit je Schritt; der Rot-Nachweis (Meldungen) kommt in den Bericht und den PR-Body. Keine Commits mit roten Tests.
- **O3:** Stop-Pfad-Charakterisierungstest nicht committen, nur als Probe laufen lassen. Ergebnis im Bericht; bestätigt sich der Fehler, legt die Hauptsession ein Folge-Issue an.
- **O4:** Ja, Überstunden-Warnung mit den Schwellwerten des Profils der Aktion (festgehaltenes Settings-Repo).
