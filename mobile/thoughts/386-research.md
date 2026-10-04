# Mobile-Research: #386 — Gleitzeit bei beendetem Eintrag mit „jetzt“ statt Ende berechnet; ToggleBreak speichert doppelt
Datum: 2026-10-04
Branch: claude/week-number-display-bug-x5xq8r (auf develop, enthält Web-Fix #390/PR #395)

## Aufgabe
Folge-Issue zu #379/PR #384. Zwei unabhängige Fehler im Mobile-Dashboard:
1. `DashboardViewModel.recalculateOvertimeFromSettings` rechnet bei bereits beendetem Eintrag die Ist-Dauer mit der Uhr statt mit `workEnd`. Nach Feierabend verfälscht eine Settings-Änderung (Soll, Arbeitstage) Tages- und Gesamt-Gleitzeit.
2. `ToggleBreak` (Use Case) und `DashboardViewModel.startOrStopBreak` speichern den Eintrag je einmal, also doppelt.

Akzeptanz (aus dem Issue): beide Punkte reproduzieren, per Test absichern (feste Daten, Fake-Uhr über `clockProvider`, auch unter `TZ=Europe/Berlin`), dann beheben. Plattform: nur Mobile.
Nicht Teil: Pausenregeln, Backend-Abweichungen (manuelle Überstunden, offene Pausen), `StartOrStopTimer`-Use-Case (siehe Nebenbefunde).

## Betroffene Dateien
| Datei | Warum |
|---|---|
| `mobile/lib/presentation/view_models/dashboard_view_model.dart` | `_recalculateOvertime` (340-370), `_calculateElapsedTime` (333-338), `_calculateExpectedEndTime` (373-411), `_calculateTotalBreakDuration` (413-420), `recalculateOvertimeFromSettings` (252-259), `startOrStopBreak` (711-716), `_recalculateStateAndSave` (499-598) |
| `mobile/lib/domain/usecases/toggle_break.dart` | Use Case speichert in Zeile 54 selbst |
| `mobile/lib/presentation/view_models/settings_view_model.dart` | einzige Aufrufer von `recalculateOvertimeFromSettings` (Z. 287 `updateWorkdays`, Z. 301 `updateWeeklyTargetHours`) und `updateOvertimeFromSettings` (Z. 242) |
| `mobile/test/domain/usecases/toggle_break_test.dart` | prüft `verify(saveWorkEntry).called(1)` am Use Case, muss mit Fix angepasst werden |
| `mobile/test/presentation/view_models/dashboard_view_model_day_change_test.dart` | `Harness` (FakeAsync + FakeClock + Fake-Repos) als Vorlage; liegt privat in der Datei |
| `mobile/test/support/fake_clock.dart`, `fake_repositories.dart` | Fake-Uhr, In-Memory-Repos (`work.saved`/`work.log` zählen Saves, `failSaves`) |
| `mobile/test/presentation/view_models/dashboard_view_model_test.dart` | Mockito-Variante, nutzt `DateTime.now()` (datumsabhängig, nicht für neue Tests verwenden) |

## Problem 1 — Ist-Zustand

### Bewertung aller Stellen in `mobile/lib`, die mit „jetzt“/Uhr rechnen
| Stelle | Rechnet mit jetzt | Bei gestopptem Eintrag |
|---|---|---|
| `_recalculateOvertime` (340) über `_calculateElapsedTime` (333) `now - workStart - Pausen(now)` | ja, immer | **FALSCH (der Bug)**: `dailyOvertime`, `totalOvertime` |
| `_calculateExpectedEndTime` (373), Pausen bis `_now()` | ja | formal falsch (`expectedEndTime`, `expectedEndTotalZero`), UI blendet beides bei `workEnd != null` aus (`dashboard_screen.dart` 108-115). Unsichtbar, aber State inkonsistent |
| `_calculateTotalBreakDuration(now)` (413): offene Pause bis jetzt, Pausen nach jetzt ignoriert | ja | falsch, siehe Folge von `_recalculateOvertime` |
| `_load` Zeile 104-114 (gestoppt) | nein, `workEnd`, offene Pause = 0 | korrekt |
| `_load` Zeile 115-129 (laufend) | ja | korrekt (nur Zweig ohne `workEnd`) |
| `_load` Zeile 143-145 `DateUtils.isSameDay(lastUpdateDate, _now())` | Tagesvergleich, keine Dauer | Heuristik, kein Dauerfehler |
| `_startTimerIfNeeded` (261-309): Sofort-Update + Timer-Tick mit `_now()` | ja | nur im Zweig `workStart != null && workEnd == null`, korrekt |
| `_recalculateStateAndSave` (508-528) | nein, `workEnd`, offene Pause = 0 | korrekt, persistiert diesen Wert |
| `startOrStopTimer`/`startNewSession*`/`setManual*`/`clearEndTime` `_now()` | Zeitstempel setzen | korrekt |
| `dashboard_screen.dart` Z. 66: `b.end ?? DateTime.now()` (echte Uhr, nicht `clockProvider`) | ja | nur Fallback für `grossDuration` (bei gestopptem Eintrag `workEnd - workStart`, also nicht genutzt) und Pausen-Anzeige; kein Gleitzeitwert, unkritisch. Nicht testbar mit Fake-Uhr, nicht Teil des Fixes |
| `work_entry_extensions.dart` `calculatedWorkDuration` (`workEnd ?? nowToMinute()`) | ja bei laufendem | `calculateOvertime` hat Guard `workEnd == null → 0`, `reports_page.dart` 550 ist also korrekt für gestoppte Einträge. Der Issue-Hinweis auf `effectiveWorkDuration`: die `WorkEntryEntity`-Methode gleichen Namens (`work_entry_entity.dart` 52) liefert 0 ohne `workEnd`, rechnet nie mit jetzt |
| `reports_view_model` (`DateTime.now()` Z. 39/50/157/174/216/550), `insights_view_model` 40, `settings_view_model` 235, `weekly_reflection_view_model` 70, `*_state.dart` | Auswahl-/Zeitstempel („heute“ als Default-Monat/-Tag, `lastUpdated`) | keine Ist-Dauer-/Gleitzeitberechnung, nicht betroffen |
| `ToggleBreak`/`StartOrStopTimer`/`GetTodayWorkEntry` (`clock`) | Zeitstempel | korrekt |

Ergebnis: genau **eine** fehlerhafte Rechenkette (`_recalculateOvertime` mit `_calculateElapsedTime`, `_calculateExpectedEndTime`, `_calculateTotalBreakDuration`), identisch zum Web-Fehler in #390. Nicht betroffen sind `_load` und `_recalculateStateAndSave`.

### Auslöser
Für einen gestoppten Eintrag erreicht `_recalculateOvertime` nur ein Pfad: `recalculateOvertimeFromSettings()` (Guard nur `workStart == null`). Der Timer-Pfad (Start, Tick) läuft nur bei `workEnd == null`; `_startTimerIfNeeded` ruft `_recalculateOvertime` im else-Zweig (gestoppt) nicht auf.
`recalculateOvertimeFromSettings` wird von `SettingsViewModel.updateWorkdays` und `updateWeeklyTargetHours` ausgelöst, also wenn der Nutzer in den Einstellungen Arbeitstage oder Wochenstunden ändert, während das Dashboard einen beendeten heutigen Eintrag zeigt (Provider lebt weiter, `IndexedStack`/Shell). Der Aufruf geht über `ref.read(dashboardViewModelProvider.notifier)`, das ViewModel wird dadurch ggf. erst jetzt gebaut (dann zählt der Ladepfad).
Nicht auslösend: Rebuild des ViewModels durch `ref.watch(settingsRepositoryProvider)` in `build()` ruft `_init` (korrekter Pfad); der Fehler tritt nur über den expliziten Aufruf auf.

Fehlerwirkung (Beispiel): Eintrag 08:00 bis 11:00, Soll 6 h, kein Pause, Gleitzeit-Basis 0. Korrekt: -3 h. Nach Settings-Änderung um 12:00: `12:00 - 08:00 - 6 h = -2 h`; um 15:00: `+1 h`. Der Fehler wächst mit der Uhrzeit. Bei einer Settings-Änderung, die das Soll ändert, wird zusätzlich korrekt das neue Soll verwendet (der Anteil „Soll“ stimmt, nur die Ist-Dauer ist falsch).

### Wird der falsche Wert persistiert?
**Nur Anzeige, keine Reparatur nötig.**
- `_recalculateOvertime` schreibt nur `state = state.copyWith(...)`, kein Repo-Aufruf.
- Persistiert wird der Saldo ausschließlich in `_recalculateStateAndSave(save: true)` (`saveOvertime`, `saveLastUpdateDate`), und dort wird `dailyOvertime` aus dem Eintrag neu berechnet (`workEnd`), `base = state.initialOvertime` (unverfälscht). Der falsche State-Wert fließt nicht ein.
- Der nächste `_init` und jede Aktion (`updateBreak`, `setManualEndTime`, ...) überschreiben den State wieder korrekt.
- Folgefehler nur in der Anzeige: `updateOvertimeFromSettings(newBase)` nutzt `state.dailyOvertime` (ggf. falsch) für `totalOvertime = newBase + currentDaily`; gespeichert wird in `SettingsViewModel.setOvertimeBalance` der vom Nutzer eingegebene Wert `overtime`. Falls der Nutzer den (falsch angezeigten) Gesamtsaldo abliest und als Anpassung eingibt, wird dieser Wert bewusst persistiert (Nutzeraktion, kein Backfill sinnvoll). Bitte vor dem Fix gegenprüfen, welcher Wert der Dialog in den Einstellungen vorbelegt (nicht untersucht).

### Soll-Verhalten (Fix-Skizze, kein Code)
`end = workEntry.workEnd ?? _now()` einmal bilden und durchreichen:
- Netto = `end - workStart - Pausen(end)`.
- `_calculateExpectedEndTime`: Pausen bis `end` (für gestoppte Einträge ohnehin ausgeblendet; konsistent halten statt `null` setzen, wie in der Web-Entscheidung #390).
- Settings-Änderung muss einen gestoppten Eintrag weiterhin neu bewerten (neues Soll), daher kein Früh-Return bei `workEnd != null`.
- `_calculateElapsedTime`/`_calculateTotalBreakDuration` werden vom Timer-Tick mitbenutzt: Verhalten für laufende Einträge muss byteidentisch bleiben (`end == now`).

### Pausen-Detail für gestoppte Einträge (Entscheidungsbedarf)
Bei gestopptem Eintrag mit offener Pause (Stop verhindert Auto-Pausen nur über `hasRunningBreak`, ein manuell gesetztes Ende bei laufender Pause ist möglich) gilt:
- `_load` und `_recalculateStateAndSave` zählen die offene Pause als 0 (wie Backend `SumBreakMs`).
- `_calculateTotalBreakDuration(end)` würde eine offene Pause bis `workEnd` zählen (so macht es Web).
Empfehlung: für gestoppte Einträge dieselbe Rechnung wie `_recalculateStateAndSave` (offene Pause = 0), damit alle Pfade und das Backend den gleichen Wert liefern. Alternativ für Web-Parität bis `workEnd`. Siehe Frage 2.

## Problem 2 — Ist-Zustand ToggleBreak

### Wer speichert wann
`DashboardViewModel.startOrStopBreak()` (Z. 711):
1. `_ensureCurrentDay()` (Guard, kein Schreiben; bei laufendem Eintrag sofort `true`, sonst Tageswechsel/Nachladen).
2. `toggleBreak.call(state.workEntry)`: Pause starten/beenden **und `_repository.saveWorkEntry(updatedEntry)` (Speichern #1, awaited)**; Fehler wird nicht gefangen und propagiert.
3. `_recalculateStateAndSave(updatedEntry)` setzt State und ruft `saveWorkEntry(updatedEntry)` über `saveWorkEntryUseCaseProvider` (**Speichern #2**, awaited, in try/catch, #336). Bei gestopptem Eintrag zusätzlich `saveOvertime` und `saveLastUpdateDate`.
Die beiden Saves schreiben denselben Inhalt nacheinander (kein paralleler Zugriff innerhalb einer Aktion). Zweiter Save also reine Redundanz. Alle anderen VM-Aktionen (`deleteBreak`, `updateBreak`, `startOrStopTimer`, `setManual*`) speichern genau einmal über `_recalculateStateAndSave`. `startOrStopBreak` ist die Ausnahme. (Das ViewModel nutzt den Use Case `StartOrStopTimer` gar nicht, siehe Nebenbefunde.)
Beide Save-Wege gehen über denselben Hybrid-Repo (`workRepositoryProvider`), eingeloggt Standard-Profil also über `ApiDataSource` zum .NET-Backend: zwei PUTs/Writes pro Pausen-Tap.

### Auswirkungen
- Last: doppelte Netzwerk-/Firestore-Schreibvorgänge pro Pausen-Klick (Backend schreibt über `FirestoreMappings` das ganze Monats-Dokument).
- Latenz: State und Timer-Anzeige werden erst nach Save #1 aktualisiert (State-Update steht in `_recalculateStateAndSave` nach dem Use Case). Bei langsamem Netz Verzögerung der UI-Reaktion; währenddessen Doppel-Tap möglich: beide Aufrufe lesen `state.workEntry` vor dem await und togglen vom selben Ausgangszustand, Ergebnis wären zwei identische „Pause starten“ bzw. doppelt beendet (Race, durch den Umbau abgeschwächt, nicht vollständig geschlossen).
- Race zum Auto-Save: der 30-s-`_autoSave` speichert `state.workEntry` (alter Stand ohne die Pause) und kann zwischen Save #1 und #2 laufen; letzter Schreiber gewinnt. Save #2 schreibt wieder den neuen Stand, in der Reihenfolge Autosave nach #2 ist der Stand korrekt, weil dann `state` neu ist. Verlustfenster klein, aber real.
- Fehlerverhalten ungleich: Fehlschlag von Save #1 bricht `startOrStopBreak` mit unbehandelter Exception ab (State unverändert, Button-Tippen wirkt wie ohne Reaktion, Exception im Event-Handler `onPressed`, nicht an Crashlytics-Logger). Fehlschlag von Save #2 wird gefangen (#336).

### Entfernen ohne Verhaltensbruch
Empfehlung: **Speichern im Use Case entfernen**, nicht im ViewModel. Gründe: Das VM-Save hat Fehlerbehandlung (#336), setzt den State vor dem Save, speichert bei gestopptem Eintrag den Saldo mit und läuft über den Reinit bei Vortags-Stop. Der Use Case wird dadurch zu einer reinen Transformation `Entry → Entry` (Doc-Kommentar „Speichere ..."/Konstruktor-Repository anpassen).
Folgen im Detail:
- `_ensureCurrentDay`: läuft vor dem Use Case, unverändert. Bei laufendem Eintrag (Normalfall, auch über Mitternacht) bleibt er am Starttag; bei gestopptem Eintrag wird zuerst auf heute umgestellt. Kein Zusammenhang mit dem Save im Use Case. Tageswechsel-Reinit nach dem Save (`saved && workEnd != null && date != heute`) hängt am VM-Save und bleibt erhalten.
- Fehlerpfad: Netzwerkfehler beim Pausen-Toggle wird dann wie bei allen anderen Aktionen gefangen und geloggt, State ist aktualisiert, nächster Save (Auto-Save 30 s bei laufendem Timer) schreibt nach. Das ist eine bewusste Verhaltensänderung (vorher: Abbruch ohne State-Änderung, unbehandelte Exception). Konsistent mit #336 und mit `deleteBreak`/`updateBreak`.
- Use-Case-Signatur: Konstruktor `ToggleBreak(this._repository, {clock})`; wird `_repository` nicht mehr gebraucht, Konstruktor ändert sich (`providers.dart` `toggleBreakUseCase`, `providers.g.dart` regenerieren). Alternative ohne Signaturänderung: Repository-Parameter behalten (YAGNI-Verstoß). Empfehlung: Repository entfernen, `@riverpod`-Provider `toggleBreakUseCase` ohne `workRepositoryProvider`, `build_runner` nötig.
- Tests: `toggle_break_test.dart` (`verify(mockRepository.saveWorkEntry(any)).called(1)`, `@GenerateMocks([WorkRepository])`, `*.mocks.dart` neu generieren) auf reine Rückgabe-Prüfung umstellen; Rückgabe-Assertions (Pause starten/beenden) bleiben.
- Aufrufer: nur `startOrStopBreak` (grep: kein weiterer).

## Datenfluss
Problem 1: `SettingsPage` → `SettingsViewModel.updateWeeklyTargetHours/updateWorkdays` → `settingsRepository.set…` → `DashboardViewModel.recalculateOvertimeFromSettings` → `_recalculateOvertime` → nur `DashboardState`. Kein Repo/UseCase/Firestore.
Problem 2: `DashboardScreen` Button → `DashboardViewModel.startOrStopBreak` → `ToggleBreak.call` → `WorkRepository.saveWorkEntry` (#1) → `_recalculateStateAndSave` → `SaveWorkEntry.call` → `WorkRepository.saveWorkEntry` (#2) → `HybridWorkRepositoryImpl` → `ApiDataSource` / Firestore (Profil) / SharedPreferences.

## Backend/Web-Referenz (Frage 3)
Backend (`server/src/WorkTimeManager.Api/Domain/ReportCalculator.cs`): `NetWorkMs` (201-206) zählt nur bei `Type == "work"` **und** `WorkStart` **und** `WorkEnd`, sonst 0; `GrossWorkMs` = `WorkEnd - WorkStart`; `SumBreakMs` ignoriert offene Pausen (`End is null`, 192); `CalculateDailyStat` = `worked - target + manualMs`. Im Domain-Code gibt es keine Uhr („jetzt“ kommt nur als `lastUpdated` im Repository). Ein gestoppter Eintrag wird also immer mit `WorkEnd` gerechnet, ein laufender zählt 0 (Live-Anzeige ist reine Client-Sache). `DailyTargetMs` = `weeklyTargetHours / workdays.Count` ohne Rundung auf Minuten (Mobile rundet in `_getEffectiveTargetDailyHours` auf Minute, bekannte Abweichung, nicht Teil von #386).
Web-Fix #390 (`web/thoughts/390-research.md`, PR #395): `end = e.workEnd ?? new Date()` in `_recalculateOvertime` für Netto, Pausen und `_calcExpectedEnd`; nur Anzeige; `expectedEnd*` unverändert gelassen; keine Absicherung der Settings-Race; Tests A (gestoppt + Settings-Emission), B (laufend, Gegenprobe), D (Stop-Ablauf). Mobile-Pendant ist 1:1 gleich aufgebaut.
Bekannte, hier nicht zu ändernde Abweichungen Mobile ↔ Backend: Mobile-VM kennt `manualOvertime` nicht (Backend addiert `ManualOvertimeMinutes`); offene Pause bei gestopptem Eintrag (siehe oben); Soll-Rundung auf Minute; Sonder-Einträge (Urlaub/Krank/Feiertag) zählen im Backend als Soll erfüllt, das Dashboard-VM rechnet nur aus Start/Ende.

## Testplan (Fake-Uhr, feste Daten, datums-/TZ-unabhängig)
Rahmen: `fakeAsync`, `FakeClock(DateTime(2026, 10, 5, 12, 0))` (Mo; `Harness` aus `dashboard_view_model_day_change_test.dart`, bei Bedarf nach `test/support/dashboard_harness.dart` extrahieren oder kopieren), Fake-Repos, `settings.weeklyHours`/`workdays` direkt setzen. Alle Zeiten lokal per `DateTime(y, m, d, h, min)`. 2026-10-05 ist in Europe/Berlin, UTC, Los Angeles und Auckland ein DST-freier Tag (Berlin 25.10., LA 1.11., Auckland begann 27.9.). Nicht `DateTime.now()` oder Wochentag der Laufzeit verwenden. `TestWidgetsFlutterBinding.ensureInitialized()`, Container innerhalb `fakeAsync`, `dispose` und Timer-Zähler prüfen (siehe `mobile/CLAUDE.md`, „Tageswechsel“).
Lokal prüfen: `TZ=Europe/Berlin`, `TZ=UTC`, `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland flutter test <datei>`.

Problem 1 (Datei `test/presentation/view_models/dashboard_view_model_overtime_test.dart` neu):
- **A (Kern, rot vor Fix):** Seed: Eintrag 5.10. 08:00 bis 11:00, keine Pausen, `weeklyHours = 30` (5 Arbeitstage: Soll 6 h), `overtime.stored = 0`, `lastUpdate = null`. Boot um 12:00. Vorab: `dailyOvertime == -3h`. `vm.recalculateOvertimeFromSettings()` → `dailyOvertime == -3h` und `totalOvertime == -3h` (ohne Fix `-2h`). Dann `clock.jumpTo(DateTime(2026,10,5,15,0))`, erneut aufrufen → `-3h` (ohne Fix `+1h`).
- **A2 (Settings wirken wirklich):** gleicher Eintrag, `settings.weeklyHours = 40` setzen (Soll 8 h), `recalculateOvertimeFromSettings()` → `dailyOvertime == -5h`, auch bei Uhr 15:00 (Soll-Änderung wird für gestoppten Eintrag übernommen, kein Früh-Return).
- **A3 (Basis):** `overtime.stored = 1h`, `lastUpdate = DateTime(2026,10,2,18,0)` (Vortag): `totalOvertime == 1h - 3h` nach Neuberechnung bei 15:00.
- **A4 (Pausen):** Eintrag 08:00-17:00 mit Pause 12:00-12:45, Soll 8 h: Netto 8h15, Daily `+15min`, Uhr 20:00 und Neuberechnung bleibt `+15min`; Variante Pause nach Ende nicht erzeugen.
- **A5 (offene Pause bei gestopptem Eintrag):** nur falls Frage 2 entschieden; erwartet je nach Entscheidung 0 oder bis `workEnd`. Muss gleich dem Wert aus `_load`/`_recalculateStateAndSave` sein (Konsistenztest: Wert nach `recalculateOvertimeFromSettings` == Wert direkt nach `boot()`).
- **B (Gegenprobe laufend, grün vorher und nachher):** Eintrag nur mit `workStart` 08:00, Boot 12:00, Soll 8 h → `dailyOvertime == -4h`; `tick(1h)` → `-3h`; Settings-Änderung ändert nur das Soll, Ist läuft weiter mit der Uhr.
- **D (Stop-Ablauf):** laufend 08:00, Uhr per `tick(3h)` auf 11:00, `startOrStopTimer()` (Stop) → `dailyOvertime == -3h` (Soll 6 h); `clock.jumpTo(15:00)`; `recalculateOvertimeFromSettings()` → weiterhin `-3h`; gespeicherter Saldo (`overtime.savedOvertimes.last`) unverändert `-3h` (belegt „nicht persistiert“, ein Save-Zähler: keine neuen `saveOvertime` durch den Recalc).
- **E (Persistenz-Nachweis, optional):** nach A: `overtime.savedOvertimes` und `work.saved` ohne Zuwachs.
- **F (optional, Integration):** `SettingsViewModel.updateWeeklyTargetHours` mit echtem Dashboard-VM (Container-Override der Fake-Repos): benötigt weitere Fakes (`settingsRepository.setTargetWeeklyHours` etc.); nur falls Aufwand vertretbar, sonst weglassen (der Aufruf ist trivial delegiert).

Problem 2 (Datei `dashboard_view_model_break_test.dart`, Harness wie oben, `clockProvider` → Fake-Uhr):
- **G (Kern, rot vor Fix):** Seed laufender Eintrag 08:00, Boot 09:00 (`work.saved` leer, `_load` speichert nicht), `act(vm.startOrStopBreak)` → `work.saved.length == 1` (ohne Fix 2, identische Inhalte), State enthält genau eine laufende Pause mit `start == 09:00`. Dann `tick(30min)`: aber Autosave-Zähler beachten (Auto-Save nach 30 Ticks à 1 s; `tick` im Test auf Zeiträume unter 30 s oder Save-Anzahl vor dem Tick merken).
- **G2:** zweiter Toggle (Pause beenden) → insgesamt genau ein zusätzlicher Save, Pause hat `end`.
- **H (Fehlerpfad):** `work.failSaves = true` → `startOrStopBreak` wirft nicht, State enthält die Pause, Timer läuft weiter (nach Fix; vorher: Exception aus dem Use Case, State ohne Pause). Anschließend `failSaves=false`, `tick(30s)` → Auto-Save schreibt den Stand mit Pause.
- **I (Tageswechsel/`_ensureCurrentDay`):** (a) laufender Eintrag über Mitternacht (Fr 2.10. 08:00 gestartet, Uhr springt auf Sa 3.10. 00:30): Pausen-Toggle schreibt weiter in den Vortagseintrag (Key 2026-10-02), genau ein Save, kein Reinit. (b) gestoppter Vortagseintrag, Uhr springt auf Folgetag: `startOrStopBreak` schaltet zuerst auf den neuen Tag um (Lesen vor Schreiben im `work.log`: `read:<neu>` vor `save:<neu>`), nie `save:<Vortag>`. Vorhandene Tests in `dashboard_view_model_day_change_test.dart` zeigen das Muster, `work.log` dient als Reihenfolgebeleg.
- **J (Use-Case-Test):** `toggle_break_test.dart` nach Fix: Use Case ist rein (kein Repository), Rückgabewerte prüfen; mit `FakeClock` statt `DateTime.now` und festem Datum (die bestehende Datei nutzt `DateTime(2023,10,26)`, ist aber für Pause start/ende von `clock = DateTime.now` abhängig, also Clock injizieren).

Rot-Nachweis: Tests A/A2/A3/A4/D/G/H müssen vor dem Fix scheitern. A2 scheitert vor dem Fix nur, wenn die Uhr später als Soll-Änderung wirkt (Uhr 15:00: `+4h`-Variante) — beim Schreiben prüfen. Vor dem Fix B und die bestehenden Tests grün lassen.
Hinweis: die Mockito-Tests (`dashboard_view_model_test.dart`) nutzen `DateTime.now()` und `workdaysIncludingToday()` — für neue Tests nicht übernehmen.

## Aufteilung: ein PR oder zwei? — Empfehlung: zwei Commits, ein PR (hilfsweise zwei PRs)
Beide Punkte betreffen dieselbe Datei und denselben Issue, sind fachlich unabhängig (Rechnung vs. Persistenz). Ein PR ist vertretbar, weil das Issue beide verbindet und der Umfang klein ist (Problem 1 etwa 15 Zeilen im VM; Problem 2 etwa 5 Zeilen im Use Case plus Provider/Test). Ein PR bündelt nur ein Review, aber der Rückbau des Speicherns berührt `providers.dart`/`providers.g.dart` (Konstruktoränderung, `build_runner`) und das Fehlerverhalten beim Pausen-Toggle; das ist ein anderes Risikoprofil als der reine Anzeige-Fix.
Empfehlung: **ein PR, zwei getrennte Commits** (TDD je Problem, einzeln revertierbar, jeweils Rot-Nachweis), Titel „fix(mobile): … (#386)“. Gegenargument für zwei PRs: Problem 2 ändert Verhalten bei Speicherfehlern und könnte separat zurückgenommen werden müssen. Wenn der Reviewer das trennen will, Commits sind dafür cherry-pickbar. Problem 1 hat Priorität (Nutzer sieht falsche Zahl), Problem 2 ist Effizienz/Race.
Backend/Web: nicht nötig. Web-Gegenstück Problem 1 ist #390/PR #395 (bereits gemergt); Web-Pendant zu Problem 2 existiert nicht (Web speichert in `DashboardService` ohne Use Case; nicht untersucht, ob dort doppelt gespeichert wird, ein kurzer Blick lohnt vor dem PR).

## Plattformübergreifend
Nur Mobile. Kein neuer Firestore-Pfad (keine Rules-Änderung), kein neues Backend-Feld, keine ARB-Texte, kein Premium-Bezug, kein Profilbezug (alles läuft über das aktive Profil des Repos). `@riverpod`-Provider ändern sich nur, falls der `ToggleBreak`-Konstruktor angepasst wird: dann `dart run build_runner build`.
Crashlytics: Fehler im Pausenpfad werden nach dem Fix über `logger.e` (#336) erfasst statt als unbehandelte Exception.

## Nebenbefunde (nicht Teil der Aufgabe, nur dokumentiert)
- `StartOrStopTimer`-Use-Case (inkl. Provider, Test) wird vom Dashboard-VM nicht benutzt (VM implementiert Start/Stop selbst, `startOrStopTimerUseCaseProvider` ohne Aufrufer in `lib`). Würde er verwendet, speicherte er ebenfalls doppelt. Ggf. eigenes Aufräum-Issue.
- `dashboard_screen.dart` Z. 66 nutzt `DateTime.now()` statt `clockProvider` (Anzeige-Fallback).
- `_load` rechnet Pausen für gestoppte Einträge nicht mit offener Pause; Auto-Save/Timer unberührt.
- Break-Toggle auf einem bereits gestoppten Eintrag ist per UI möglich (Button immer sichtbar) und erzeugt dann eine Pause nach `workEnd` mit Saldo-Speicherung; unverändert lassen.

## Offene Fragen und Empfehlungen
1. **Fix-Umfang Problem 1:** `end = workEnd ?? _now()` in `_recalculateOvertime` (Netto, Pausen, `_calculateExpectedEndTime`) wie Web, ohne gestoppte Einträge auszuschließen? Empfehlung: ja, nur diese Variante (Settings-Änderung muss neu bewerten), `expectedEnd*` konsistent mit `end` berechnen (unsichtbar, minimaler Diff).
2. **Offene Pause bei gestopptem Eintrag:** wie `_load`/`_recalculateStateAndSave`/Backend als 0 zählen oder wie Web bis `workEnd`? Empfehlung: 0 (Parität zu den anderen Mobile-Pfaden und zum kanonischen Backend), gestoppt = `workEnd - workStart - abgeschlossene Pausen`. Eventuell die Pausen-Summe als eine gemeinsame private Funktion für `_load`, `_recalculateStateAndSave` und `_recalculateOvertime` bündeln (Duplikat heute dreimal), nur wenn der Diff klein bleibt.
3. **Problem 2: Save im Use Case oder im VM entfernen?** Empfehlung: im Use Case (`ToggleBreak` wird rein, Repository-Parameter und `providers.g.dart` anpassen), VM-Save bleibt wegen Fehlerbehandlung (#336), Saldo-Save und Vortags-Reinit.
4. **Verhaltensänderung Fehlerpfad akzeptabel?** Nach Fix wird ein Speicherfehler beim Pausen-Toggle wie bei den anderen Aktionen geschluckt/geloggt (State zeigt die Pause, Auto-Save schreibt nach). Empfehlung: ja, im PR-Text nennen.
5. **Ein PR oder zwei?** Empfehlung: ein PR mit zwei Commits (siehe oben); zwei PRs nur, wenn du Problem 2 getrennt reviewen willst.
6. **Test-Harness:** `Harness` aus der Day-Change-Testdatei nach `test/support/` extrahieren (geteilt) oder kopieren? Empfehlung: extrahieren (kleine, rein mechanische Änderung, im ersten Commit), sonst entstehen zwei Kopien. Mockito-Tests mit `DateTime.now()` unangetastet lassen.
7. **Nebenbefunde** (`StartOrStopTimer` ungenutzt, `DateTime.now()` im Screen, offene Pause im Web vs. Backend): nur als Hinweis in den PR-Text, kein eigenes Issue ohne Bedarf. Empfehlung: ein kurzes Aufräum-Issue für `StartOrStopTimer`.
8. **Web-Gegencheck Problem 2:** soll vor dem PR geprüft werden, ob das Web beim Pausen-Toggle ebenfalls doppelt speichert (`DashboardService`)? Empfehlung: ja, kurzer Blick (nur Lesen), Ergebnis als Hinweis; Fix wäre ein eigenes Web-Issue.

## Risiken
- Fehlerhafte Rückwirkung auf laufende Einträge: `_calculateElapsedTime`/`_calculateTotalBreakDuration` gehören auch zum 1-s-Tick; Änderung darf für `workEnd == null` nichts ändern (Test B + bestehende Tests `expectedEndTime`).
- `ToggleBreak`-Konstruktoränderung betrifft `providers.dart`, generiertes `.g.dart`, Mocks (`toggle_break_test.mocks.dart`): nur über `build_runner`, nicht manuell.
- Fehlerpfad-Änderung (Frage 4): Pause wird im UI angezeigt, obwohl der Save fehlschlug; bei App-Kill vor dem nächsten Auto-Save geht sie verloren (gleiches Risiko wie bei allen anderen Aktionen seit #336).
- Doppel-Tap-Race bleibt auch nach Fix möglich (zwei Aufrufe vor dem State-Update, falls `_ensureCurrentDay` auf einen Ladelauf wartet); nicht Teil von #386, nicht mit verschärfen.
- Tests: Auto-Save-Intervall (30 ticks) und `fakeAsync`-Timer-Zähler beachten; Zeiten immer lokal konstruieren, kein `DateTime.now()`.

## Entscheidungen zu den offenen Fragen (Hauptsession)

1. Fix Problem 1: nur `end = workEnd ?? _now()` (Netto, Pausen, `expectedEnd*`), gestoppte Einträge nicht ausschließen.
2. Offene Pause bei gestopptem Eintrag zählt als 0 (wie `_load`, `_recalculateStateAndSave` und Backend). Gemeinsame Pausen-Summe nur bündeln, wenn der Diff klein bleibt. Hinweis: Web (#390) zählt offene Pausen bis `workEnd` – im PR-Text als bekannte Abweichung nennen.
3. Problem 2: Save im Use Case entfernen, im VM behalten; `ToggleBreak` ohne Repository, `build_runner` ausführen.
4. Verhaltensänderung akzeptiert: Speicherfehler beim Pausen-Toggle wird geloggt/geschluckt (wie #336), State zeigt die Pause, Auto-Save schreibt nach. Im PR-Text nennen.
5. Ein PR, zwei getrennte Commits (je Problem TDD, einzeln revertierbar).
6. `Harness` nach `test/support/` extrahieren.
7. Nebenbefunde nur im PR-Text, kein eigenes Issue (Hauptsession entscheidet danach).
8. Web-Pausen-Toggle auf Doppel-Speichern kurz lesen und Ergebnis im Plan festhalten (nicht beheben).
