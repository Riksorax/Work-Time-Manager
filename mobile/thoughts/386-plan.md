# Mobile-Plan: #386 — Gleitzeit bei beendetem Eintrag mit "jetzt" statt Ende; ToggleBreak speichert doppelt
Research: mobile/thoughts/386-research.md
Branch: claude/week-number-display-bug-x5xq8r (ein PR gegen `develop`, drei Commits)

## Ziel
Problem 1: `DashboardViewModel._recalculateOvertime` rechnet bei beendetem Eintrag mit `workEnd` statt mit der Uhr, die Settings-Änderung bewertet das neue Soll weiterhin neu. Problem 2: Pausen-Toggle speichert genau einmal (Save im Use Case `ToggleBreak` entfällt, VM-Save bleibt).

## Entscheidungen der Hauptsession (gelten vor allem anderen)
Siehe letzter Abschnitt. Kurz: Fix nur per `end = workEnd ?? _now()`; offene Pause bei gestopptem Eintrag = 0; Save im Use Case entfernen; Fehlerpfad-Änderung akzeptiert; ein PR, getrennte Commits; Harness nach `test/support/`.

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Neue Entity / Feld? | Nein | reine Rechen-/Persistenzkorrektur |
| Repository-Interface ändern? | Nein (`WorkRepository` unverändert) | Hybrid-/Firebase-/Local-/ApiDataSource unberührt; nur `ToggleBreak` verliert die Abhängigkeit |
| Neuer Provider? | Nein, aber `toggleBreakUseCase` (`@riverpod`, `providers.dart`) ändert sich (ohne `workRepositoryProvider`) | `dart run build_runner build --delete-conflicting-outputs`; `providers.g.dart` und `toggle_break_test.mocks.dart` nur generieren. DashboardVM ist manuell registriert, bleibt |
| Premium-Gate? | Nein | |
| Pro Arbeitszeit-Profil? | Kein neuer Durchreich-Bedarf | alles läuft über das aktive Profil des Repos |
| Backend-Änderung? | Nein | Backend ist Referenz (offene Pause = 0) |
| Neue Texte? | Nein | keine ARB-Keys, kein `flutter gen-l10n` |
| Firestore Rules? | Nein | keine neuen Pfade |
| Abweichung vom Naheliegenden | Save im Use Case statt im VM entfernen; Harness-Extraktion als eigener Commit 0; offene Pause bei gestopptem Eintrag = 0 (Web zählt bis `workEnd`) | siehe Entscheidungen |

## Dateien
| Datei | neu/geändert | Zweck |
|---|---|---|
| `mobile/test/support/dashboard_harness.dart` | neu (Commit 0) | `Harness`, `scenario`, `entryOf`, `eightHours` aus der Day-Change-Testdatei, Verhalten unverändert (Klassen öffentlich, Imports anpassen) |
| `mobile/test/presentation/view_models/dashboard_view_model_day_change_test.dart` | geändert (Commit 0) | importiert den Harness, lokale Kopie entfällt, keine Testlogik geändert |
| `mobile/test/presentation/view_models/dashboard_view_model_overtime_test.dart` | neu (Commit 1) | Tests A, A2, A3, A4, A5, B, D, E |
| `mobile/lib/presentation/view_models/dashboard_view_model.dart` | geändert (Commit 1) | `_recalculateOvertime`, `_calculateElapsedTime`, `_calculateExpectedEndTime`, `_calculateTotalBreakDuration` mit `end` |
| `mobile/test/presentation/view_models/dashboard_view_model_break_test.dart` | neu (Commit 2) | Tests G, G2, H, I |
| `mobile/test/domain/usecases/toggle_break_test.dart` (+ `.mocks.dart` entfällt/regeneriert) | geändert (Commit 2) | Test J: reiner Use Case, `FakeClock`, festes Datum |
| `mobile/lib/domain/usecases/toggle_break.dart` | geändert (Commit 2) | Repository-Parameter und `saveWorkEntry` entfernen, Doc-Kommentar anpassen |
| `mobile/lib/core/providers/providers.dart` (+ `providers.g.dart` generiert) | geändert (Commit 2) | `toggleBreakUseCase` ohne Repository |

## Rahmen für alle neuen Tests
- `fakeAsync` + `FakeClock(DateTime(2026, 10, 5, 12, 0))` (Mo 2026-10-05), alle Zeiten lokal per `DateTime(y, m, d, h, min)`, nie `DateTime.now()`, kein Wochentag/Datum der Laufzeit. Der Tag ist in Berlin, UTC, Los Angeles, Auckland DST-frei. Soll über `settings.weeklyHours`/`workdays` direkt setzen (Mo-Fr).
- `TestWidgetsFlutterBinding.ensureInitialized()` (`setUpAll`), Container innerhalb `fakeAsync`, am Ende `dispose` und Timer-Zähler 0 (macht `scenario`).
- Auto-Save-Intervall (30 Ticks à 1 s) beachten: `tick` unter 30 s oder Save-Zähler vor dem Tick merken.
- CI läuft in Europe/Berlin: vor jedem Commit lokal `TZ=Europe/Berlin flutter test <Datei>` (Pflicht), zusätzlich einmal `TZ=UTC`, `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland` für die neuen Dateien.
- Rot-Nachweis: Test schreiben, ausführen, Fehlschlag mit der erwarteten Ursache (nicht Compile-/Setup-Fehler) im Terminal bestätigen und in der Commit-/PR-Beschreibung kurz festhalten, erst dann Implementierung.

## Schritte (TDD)

### Commit 0: Harness-Extraktion (Verhalten unverändert, `refactor(mobile-test): …(#386)`)
- [x] Vorab-Nachweis: `flutter test test/presentation/view_models/dashboard_view_model_day_change_test.dart` grün, Anzahl Tests notieren.
- [x] `Harness`, `scenario`, `entryOf`, `eightHours` (und von ihnen genutzte Helfer) nach `test/support/dashboard_harness.dart` verschieben; keine Logikänderung, nur Imports/Sichtbarkeit. Prüfen, ob die Day-Change-Datei weitere Top-Level-Helfer ab Zeile 125 nutzt und diese ggf. mitziehen.
- [x] Nachweis: gleiche Testanzahl, alles grün, auch `TZ=Europe/Berlin`. `dart format` ausführen. Mockito-Tests mit `DateTime.now()` bleiben unangetastet.

### Commit 1: Problem 1 — Gleitzeit mit `workEnd` (`fix(mobile): … (#386)`)
Schritt 1 Domain/Data/Provider: keine Änderung.
Schritt 2 Presentation, Tests zuerst (`dashboard_view_model_overtime_test.dart`, Harness aus `test/support/`):
- [x] A (Kern): Eintrag 5.10. 08:00-11:00, ohne Pause, `weeklyHours = 30` (Soll 6 h), `overtime.stored = 0`, `lastUpdate = null`, Boot 12:00. Vorab `dailyOvertime == -3h`; nach `recalculateOvertimeFromSettings()` `daily == -3h` und `total == -3h`; `clock.jumpTo(15:00)`, erneut aufrufen, weiter `-3h`.
- [x] A2: gleicher Eintrag, `weeklyHours = 40` (Soll 8 h) → `daily == -5h`, auch bei 15:00 (Soll-Änderung wird übernommen, kein Früh-Return). Beim Schreiben prüfen, ob rot; sonst Uhrzeit so wählen, dass der Fehler sichtbar wird.
- [x] A3: `stored = 1h`, `lastUpdate = DateTime(2026,10,2,18,0)`: `total == 1h - 3h` nach Neuberechnung bei 15:00.
- [x] A4: Eintrag 08:00-17:00, Pause 12:00-12:45, Soll 8 h: `daily == +15min`, Uhr 20:00 plus Neuberechnung bleibt `+15min`.
- [x] A5: offene Pause bei gestopptem Eintrag zählt 0 (Entscheidung 2); Konsistenzassertion: Wert nach `recalculateOvertimeFromSettings` == Wert direkt nach `boot()`.
- [x] B (Gegenprobe laufend, grün vor und nach Fix): nur `workStart` 08:00, Boot 12:00, Soll 8 h → `-4h`; `tick(1h)` → `-3h`; Settings-Änderung ändert nur das Soll.
- [x] D (Stop-Ablauf): laufend 08:00, `tick(3h)` auf 11:00, `startOrStopTimer()` → `-3h`; `jumpTo(15:00)`; `recalculateOvertimeFromSettings()` → `-3h`; `overtime.savedOvertimes` ohne neuen Eintrag, `work.saved` ohne Zuwachs (deckt E ab).
- [x] Rot-Nachweis: A, A2, A3, A4, D rot (Fehlerwerte `-2h`/`+1h`/`+4h`-Variante), B und alle bestehenden VM-Tests grün.
- [x] Impl in `dashboard_view_model.dart`: `end = workEntry.workEnd ?? _now()` einmal in `_recalculateOvertime` bilden und an `_calculateElapsedTime`, `_calculateTotalBreakDuration`, `_calculateExpectedEndTime` durchreichen. Bei `workEnd != null` offene Pause = 0 (gleiche Rechnung wie `_recalculateStateAndSave`); für `workEnd == null` byteidentisch (`end == now`, Timer-Tick). Gemeinsame Pausen-Summe nur bündeln, wenn der Diff klein bleibt, sonst nicht anfassen. Kein Früh-Return bei `workEnd != null`.
- [x] Prüfen, welchen Wert der Gleitzeit-Dialog in den Einstellungen vorbelegt (Research offen); nur dokumentieren, nicht ändern.
- [x] Grün: neue Datei, `dashboard_view_model_test.dart`, `dashboard_view_model_day_change_test.dart`; Zeitzonen-Läufe.
- [x] Optional F (Settings-VM-Integration) weglassen; Aufruf ist trivial delegiert.
Schritte 3 (Provider), 5 (Texte): entfallen.

### Commit 2: Problem 2 — ToggleBreak ohne Doppel-Save (`fix(mobile): … (#386)`)
Schritt 1 Domain, Tests zuerst:
- [x] J: `toggle_break_test.dart` umbauen: Use Case ohne Repository (`ToggleBreak(clock: fakeClock.call)`), `@GenerateMocks`/Repository-Mock entfernen, `*.mocks.dart` entfällt; Rückgabe-Assertions (Pause starten, laufende Pause beenden) mit `FakeClock` und festem Datum 2026-10-05. Rot: Kompilierfehler wegen Konstruktor ist hier der erwartete Nachweis; zusätzlich G unten als Verhaltensnachweis.
Schritt 3/4 ViewModel-Tests (`dashboard_view_model_break_test.dart`), vor der Impl, mit Rot-Nachweis:
- [x] G (Kern, rot): laufender Eintrag 08:00, Boot 09:00, `act(vm.startOrStopBreak)` → `work.saved.length == 1` (vorher 2), genau eine laufende Pause mit `start == 09:00`.
- [x] G2: zweiter Toggle → genau ein zusätzlicher Save, Pause hat `end`.
- [x] H (Fehlerpfad, rot): `work.failSaves = true` → `startOrStopBreak` wirft nicht, State enthält die Pause, Timer läuft weiter; danach `failSaves = false`, `tick(30s)` → Auto-Save schreibt Stand mit Pause.
- [x] I (grün vor und nach Fix, Schutz von `_ensureCurrentDay`): (a) laufender Eintrag Fr 2.10. 08:00, Uhr auf Sa 3.10. 00:30: Toggle schreibt in Key `2026-10-02`, ein Save, kein Reinit. (b) gestoppter Vortagseintrag, Uhr auf Folgetag: `work.log` zeigt `read:<neu>` vor `save:<neu>`, nie `save:<Vortag>`. Muster aus `dashboard_view_model_day_change_test.dart`.
Impl:
- [x] `toggle_break.dart`: Repository-Feld/Konstruktorparameter und `saveWorkEntry`-Aufruf entfernen, Doc-Kommentar auf "reine Transformation Entry → Entry" ändern. VM `startOrStopBreak` bleibt (ruft weiterhin `_recalculateStateAndSave`).
- [x] `providers.dart`: `toggleBreakUseCase` ohne `workRepositoryProvider`, `clock` bleibt.
- [x] `dart run build_runner build --delete-conflicting-outputs` (regeneriert `providers.g.dart`, entfernt/aktualisiert Mocks); generierte Dateien nie manuell editieren.
- [x] Grep: keine weiteren Aufrufer von `ToggleBreak(`/`toggleBreakUseCase` außer VM und Test.

## Validierung (vor jedem Commit, aus `mobile/`)
- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze --no-fatal-infos`, `dart run custom_lint`, `flutter test` unter `TZ=Europe/Berlin` (wie CI), neue Testdateien zusätzlich unter UTC/Los_Angeles/Auckland.
- PR-Text: Verhaltensänderung Fehlerpfad (Entscheidung 4), Abweichung offene Pause Mobile/Backend (0) vs. Web #390 (bis `workEnd`), Nebenbefunde (`StartOrStopTimer` ungenutzt und würde doppelt speichern, `dashboard_screen.dart` Z. 66 `DateTime.now()`), Ergebnis Frage 8.

## Frage 8: Web-Pausen-Toggle, Doppel-Speichern? (gelesen: `web/src/app/features/dashboard/dashboard.service.ts`)
Nein. `startOrStopBreak` (Z. 424-444) baut nur die neue Pausenliste und ruft genau einmal `_recalculateState(..., true, ctx)`; dort (Z. 625-661) erfolgt ein `workSvc.saveEntry` und, nur bei `workEnd` gesetzt, ein `_saveOvertime`. Kein weiterer Save im Web-Pfad, kein Use Case dazwischen. Das Web ist also korrekt (ein Entry-Save pro Toggle). Kein Web-Fix nötig, nur als Hinweis im PR-Text.

## Risiken
- Laufende Einträge: `_calculateElapsedTime`/`_calculateTotalBreakDuration` gehören zum 1-s-Tick; Test B und bestehende `expectedEndTime`-Tests sichern ab.
- Fehlerpfad Problem 2: Pause erscheint im UI, obwohl der Save scheiterte; Auto-Save schreibt nach (wie seit #336 bei allen Aktionen).
- Doppel-Tap-Race bleibt bestehen, nicht Teil von #386.
- Commit 0 darf keine Testlogik ändern, sonst ist der Rot/Grün-Nachweis der Folgecommits nicht aussagekräftig.

## Offene Fragen an die Hauptsession
1. Soll Commit 0 (Harness-Extraktion) im selben PR bleiben (drei Commits) oder als Teil von Commit 1 laufen? Plan nimmt: eigener Commit im selben PR.
2. Test J: Der Rot-Nachweis für den Use Case ist ein Kompilierfehler (Konstruktor); ok, oder soll der Nachweis nur über G/H laufen? Plan nimmt: G/H sind der Verhaltensnachweis, J darf kompilierrot sein.
3. Gleitzeit-Dialog in den Einstellungen (Vorbelegung des Saldos): nur dokumentieren, nicht fixen, sofern der Befund auffällig ist, ok?

## Entscheidungen zu den offenen Fragen (Hauptsession)

1. Harness-Extraktion als eigener Commit (Commit 0) im selben PR: ja.
2. Kompilierroter Test J als Rot-Nachweis: ok; Verhalten belegen G und H.
3. Vorbelegung des Gleitzeit-Dialogs nur dokumentieren (PR-Text, Nebenbefund), nicht fixen.
