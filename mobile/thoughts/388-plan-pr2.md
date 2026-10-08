# Mobile-Plan: #388 — PR 2 (Option B): Bestätigungsdialog "Abbrechen / Beenden und wechseln"
Erstellt: 2026-10-05
Research: mobile/thoughts/388-research.md (Abschnitt "Entscheidungen zu den offenen Fragen (Hauptsession)" gilt vor allem anderen)
Vorbild: web/thoughts/380-plan.md (Stufe 2), Web-Umsetzung `WorkProfileService.requestSwitch` / `DashboardService._confirmSwitch` + `stopRunningTimerForSwitch`
PR-1-Plan (`388-plan.md`) bleibt unverändert. PR 2 baut auf PR 1 (#403, gemergt: `_ActionCtx`, Harness `profiles: true`) und #402 (`Future<bool>` der Schreibaktionen) auf. Commit/PR: `Closes #388`, gegen `develop`.

## Ziel
Wechselt der Nutzer (Profil-Wechsler im AppBar oder "Neues Profil anlegen") das Arbeitszeit-Profil, während im Dashboard ein Timer läuft, fragt die App vorher: "Abbrechen" lässt alles unverändert (kein Wechsel, kein neues Profil), "Beenden und wechseln" stoppt und speichert den Timer im alten Profil über den normalen Stop-Pfad und wechselt erst bei Erfolg. Scheitert das Speichern (Saldo-Fehler), wird nicht gewechselt und die Snackbar `dashboardSaveError` erscheint. `deleteProfile(aktiv)`, Logout und App-Neustart bleiben ohne Dialog (Einfrieren, PR 1).

## Befunde aus dem Code (schärfen die Research)
- Der Stop-Pfad ist seit #402 ergebnisfähig: `startOrStopTimer()` liefert `Future<bool>`, bei Saldo-Fehler `false` mit unverändertem State/Timer, nichts wird geworfen. Der Research-Nebenbefund (Exception, Timer vorzeitig abgebrochen, "Rollback") ist erledigt, **`_recalculateStateAndSave` muss für PR 2 nicht umgebaut werden** (kleiner als in der Research angenommen). Es gibt bewusst keinen Saldo-Rollback (`lastUpdated`-Kopplung).
- Falle: `startOrStopTimer()` liefert auch `true`, ohne zu stoppen (`_ensureCurrentDay` scheitert: "Abbruch still mit `true`", Known Limit #402-4; ebenso "bereits beendet"). `stopRunningForSwitch` darf `true` deshalb **nicht** aus dem Rückgabewert allein ableiten, sondern prüft danach `!_isRunning(state.workEntry)`. Sonst würde "Beenden und wechseln" ohne Stopp wechseln.
- Bekannte Grenze bleibt: Eintrag-Write-Fehler nach erfolgreichem Saldo-Write ist geschluckt (#336/#412), Ergebnis `true` -> Wechsel erfolgt. Nicht Teil von PR 2 (in CLAUDE.md erwähnen).
- Stop eines über Mitternacht gelaufenen Eintrags löst nach dem Speichern einen Reinit (`_init(dayChange: true)`) im alten Profil aus; er wird in `_recalculateStateAndSave` abgewartet. Das ist unkritisch (Wechsel folgt danach), aber der Rückgabewert-Check muss auf dem State **nach** dem Reinit laufen (neuer Tag, nicht laufend -> ok).
- `WorkProfileViewModel` ist ein einfacher `Provider` (lebt dauerhaft) und kann damit ein `_switchPending`-Flag halten (Pendant zu Web `_switchPending`), ohne neuen Provider.
- Der Switcher hat zwei Wechselpfade: `onSelected` (Profil-ID) und `__add__` -> `AddWorkProfileDialog` -> `addProfile`. `__manage__` (Löschen) bleibt unberührt.
- Auswahl des **bereits aktiven** Profils im Menü: kein Wechsel, kein Dialog (Web: `id === from` -> `true`).
- Kein `@riverpod`, kein neues `@GenerateMocks`: **kein `build_runner`**. ARB-Änderung -> `flutter gen-l10n` (generierte `app_localizations*.dart` ändern sich, nicht manuell editieren).

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Neue Entity / Feld? | nein | |
| Repository-Interface ändern? | nein | Hybrid/Firebase/Local/ApiDataSource unberührt |
| Neuer Provider? | nein | Logik in `DashboardViewModel` (neue Methoden) und `WorkProfileViewModel` (Guard); beide manuell registriert, kein `@riverpod` |
| Wo liegt der Guard? | `WorkProfileViewModel.checkSwitchAllowed({required Future<bool> Function() confirm})` -> `ProfileSwitchGuardResult { allowed, cancelled, saveFailed, busy }` (Enum, im selben File). Zwei UI-Aufrufer rufen ihn **vor** dem Wechsel bzw. dem API-Aufruf | Eine Stelle für Logik und Reentranz-Sperre; die UI liefert nur den Dialog per Callback (VM hat keinen Context). Wechsel selbst bleibt `setActiveProfile` im Aufrufer (kein Eingriff in `ActiveWorkProfileIdNotifier`, damit `deleteProfile`/Logout/Neustart garantiert ohne Guard bleiben) |
| Guard-Ablauf | (1) `_switchPending` gesetzt? -> `busy`. (2) `dashboard = ref.read(dashboardViewModelProvider)`; `state.isLoading` oder nicht laufend -> `allowed` ohne Dialog. (3) `confirm()` -> `false` -> `cancelled`. (4) `await dashboardNotifier.stopRunningForSwitch(fromProfileId)` -> `false` -> `saveFailed`, sonst `allowed`. Flag im `finally` zurücksetzen | Entscheidung 8 (Hauptsession): `ref.read`, bei `isLoading` kein Dialog (wie Web). Das VM wird beim Start der Home-Shell ohnehin gebaut; `ref.read` instanziiert es zur Not (per Widget-Test mit Settings-Tab-Szenario abgesichert, kein Dashboard-Widget im Baum) |
| Neue VM-Methoden am Dashboard | `bool get isTimerRunning` (`!state.isLoading && _isRunning(state.workEntry)`) und `Future<bool> stopRunningForSwitch(String fromProfileId)` | s. u. |
| `stopRunningForSwitch`-Ablauf | (a) läuft ein Ladelauf (`isLoading && _initRun != null`): abwarten (nie auf dem Platzhalter arbeiten). (b) aktives Profil != `fromProfileId` (`activeWorkProfileIdProvider` per `ref.read`, `null` = Standard-ID normalisieren) -> `false` (Dialog war offen, Profil hat sich nicht-interaktiv geändert, nichts schreiben). (c) nicht (mehr) laufend (manuell gestoppt) -> `true`. (d) `ok = await startOrStopTimer()`. (e) `false` -> `false`; sonst `!_isRunning(state.workEntry)` als Ergebnis | Nutzt den **normalen** Stop-Pfad (Hauptsession): Pflichtpausen, Soll am Eintragsdatum, `_ActionCtx`, Saldo-vor-Eintrag, Saldo-Fehler -> State/Timer unverändert. Kein zweiter Stop-Pfad, keine Duplizierung von Rechenlogik |
| Verhalten laufende Pause beim Stop | wie Stop-Button (`startOrStopTimer`: keine Auto-Pausen, offene Pause bleibt) | keine eigene Logik; Parität zum Stop-Button als Testfall |
| Dialog-Widget | `showProfileSwitchConfirmDialog(BuildContext, {required String fromName, required String toName})` -> `Future<bool>` in neuer Datei `presentation/widgets/profile_switch_confirm_dialog.dart` (`AlertDialog`: Titel, Text, `TextButton` `cancel`, `FilledButton` `stopAndSwitchButton`; `barrierDismissible: false`, Ergebnis `null` -> `false`) | UI-Schicht; Muster der vorhandenen Dialoge |
| Profilnamen | `fromName` aus `workProfilesProvider` (Profil der aktiven ID, Fallback `WorkProfileEntity.defaultProfile().name`), `toName` = Name des Ziel-Profils bzw. der im Dialog eingegebene Name (`addProfile`) | Namen statt IDs im Text (Research) |
| `addProfile` | Guard **vor** dem API-Aufruf, in `AddWorkProfileDialog._save` (Signatur von `WorkProfileViewModel.addProfile` unverändert). `cancelled`/`busy`: Anlegen-Dialog bleibt offen mit eingegebenem Namen, kein API-Aufruf, kein Profil. `saveFailed`: wie oben + Snackbar `dashboardSaveError` | Entscheidung 4 (wie Web O1). Offenlassen statt Schließen: Nutzer kann Namen behalten oder selbst abbrechen |
| Fehler beim Speichern | Snackbar `dashboardSaveError` (vorhandener Key), **kein** neuer `switchSaveFailed`-Key | Hauptsession-Festlegung; weicht von der Research (4 Keys) ab -> 3 neue Keys |
| `deleteProfile(aktiv)`, Logout, Neustart | unverändert, ohne Dialog | Entscheidung 5 |
| Premium-Gate? | unverändert (Wechsler nur mit Login/Profilen; `__add__` behält Paywall/Limit vor dem Dialog) | |
| Pro Arbeitszeit-Profil? | `fromProfileId` wird beim Guard festgehalten und an `stopRunningForSwitch` übergeben | Stop landet über `_ActionCtx` im Profil des Aktionsbeginns |
| Backend/Web/Firestore-Regeln? | nein | rein Mobile |
| Neue Texte | ja, 3 Keys de (duzen, `@key`-Beschreibung Pflicht) + en: `switchWhileRunningTitle`, `switchWhileRunningText` (Platzhalter `from`, `to`, je `String`), `stopAndSwitchButton`; "Abbrechen" = vorhandenes `cancel`, Fehler = `dashboardSaveError` | Parität zum Web-Text |

Texte (de, Web-Parität): Titel "Zeiterfassung läuft"; Text "Im Profil \"{from}\" läuft noch eine Zeiterfassung. Sie wird beendet und gespeichert, bevor du in das Profil \"{to}\" wechselst."; Button "Beenden und wechseln". en: "Time tracking is running"; "Time tracking is still running in profile \"{from}\". It will be stopped and saved before you switch to profile \"{to}\"."; "Stop and switch".

## Dateien
| Datei | neu/geändert | Zweck |
|---|---|---|
| `mobile/lib/presentation/view_models/dashboard_view_model.dart` | geändert | `isTimerRunning`, `stopRunningForSwitch(fromProfileId)` |
| `mobile/lib/presentation/view_models/work_profile_view_model.dart` | geändert | `ProfileSwitchGuardResult`, `checkSwitchAllowed`, `_switchPending` |
| `mobile/lib/presentation/widgets/profile_switch_confirm_dialog.dart` | neu | Bestätigungsdialog |
| `mobile/lib/presentation/widgets/work_profile_switcher.dart` | geändert | `onSelected` (Profilwahl) geht über Guard; Snackbar bei `saveFailed` |
| `mobile/lib/presentation/widgets/add_work_profile_dialog.dart` | geändert | Guard vor `addProfile` |
| `mobile/lib/l10n/app_de.arb`, `app_en.arb` (+ generierte `app_localizations*.dart`) | geändert | 3 Keys |
| `mobile/test/presentation/view_models/dashboard_view_model_switch_test.dart` | neu | VM-Tests `stopRunningForSwitch` (Harness `profiles: true`) |
| `mobile/test/presentation/view_models/work_profile_view_model_guard_test.dart` | neu | Guard-Tests (Harness + Fake-Confirm) |
| `mobile/test/presentation/widgets/work_profile_switcher_switch_guard_test.dart` | neu | Widget-Tests Wechsler, Anlegen-Dialog, Dialog de/en |
| `mobile/CLAUDE.md` | geändert | Abschnitt "Profilwechsel (#388)": Dialog statt "offen" |
Unverändert: `providers.dart`/`*.g.dart`, alle Repositories, `ActiveWorkProfileIdNotifier`, `manage_work_profiles_dialog.dart`, `_recalculateStateAndSave`, `reportDashboardSave`.

## Test-Konventionen
- Feste lokale Daten: Mo `DateTime(2026, 10, 5, …)`, `FakeClock` mit `bind(async)`, kein `DateTime.now()`, keine Zeitzonenannahme. Saldo A 120 min, B 30 min wie PR 1.
- VM-Tests in `fakeAsync` über `scenario(..., profiles: true)`; Wechsel nur über `h.switchProfile(id)`; Timer-Leak-Check am Ende (`periodicTimerCount`).
- Widget-Tests: `MaterialApp(locale: Locale('de'), localizationsDelegates/supportedLocales)`, Auth/Prefs/`workProfileRepositoryProvider`/`isPremiumProvider`-Overrides wie `work_profile_switcher_test.dart` (vorhandene `@GenerateMocks([WorkProfileRepository])`-Mocks wiederverwenden, kein neues Mock-File). Dashboard-VM per Fake-Notifier (Subklasse von `DashboardViewModel`, feste State, `startOrStopTimer`/`stopRunningForSwitch` konfigurierbar, `Future<bool>`); kein echter Timer in Widget-Tests -> `pumpAndSettle` bleibt nutzbar, sonst am Ende `pumpWidget(SizedBox())`. Ein echter-VM-Fall nur, wenn er ohne periodische Timer-Leaks machbar ist (sonst per `pump(Duration)` und Dispose).
- Läufe aus `mobile/`: `TZ=Europe/Berlin flutter test` (CI), lokal zusätzlich `TZ=UTC`, `America/Los_Angeles`, `Pacific/Auckland` für die neuen Dateien.
- Bestandstests bleiben **unverändert** und grün; jede nötige Anpassung ist ein Warnsignal und geht an die Hauptsession. Insbesondere `work_profile_switcher_test.dart` (Wechsel ohne laufenden Timer ändert nichts) und `work_profile_view_model_test.dart`.

## Schritte (TDD; Reihenfolge domain -> data -> provider entfällt, danach VM -> l10n -> UI -> Doku)
Abweichung von der Standard-Reihenfolge: ARB-Keys kommen **vor** den Widgets (die Widgets brauchen die generierten Getter, sonst kompiliert nichts).

### Schritt 0: Baseline
- [x] Vollständiger `flutter test` unter `TZ=Europe/Berlin` grün (Ausgangsstand notieren, `git status` sauber).
- [x] Prüfen, dass `Harness` `container`, `switchProfile`, `writeLog`, `holdSaveOvertime`/`failSaveOvertime` und `overtime.saveOvertimeCalls` bietet (PR 1/#402/#410); falls ein Helper fehlt (z. B. Stub für `failReads`), minimal im Harness ergänzen, Default = bisheriges Verhalten, eigener kleiner Commit.

### Schritt 1: `DashboardViewModel.stopRunningForSwitch` (Test zuerst)
Datei `dashboard_view_model_switch_test.dart`, `scenario(..., profiles: true)`. Ausgangslage: Uhr 17:00, A: laufend ab 08:00, Saldo 120 min.
- [x] **S1 Erfolg:** `stopRunningForSwitch('default')` -> `true`; `writeLog`: Saldo-Write (`A:overtime:…`, `A:lastUpdate`) **vor** Eintrag-Write (`A:entry:…` mit Ende 17:00); State `workEnd != null`; `periodicTimerCount == 0`; aktives Profil unverändert (die Methode wechselt nicht); keine B-Writes.
- [x] **S2 Parität zum Stop-Button:** zweites Szenario mit `startOrStopTimer()`; gespeicherter Eintrag und Saldo identisch (Pflichtpause 45 min bei 9 h brutto) -> beweist "normaler Stop-Pfad".
- [x] **S3 Saldo-Fehler:** `overtime.failSaveOvertime = true` -> `false`; State weiter laufend (`workEnd == null`), `periodicTimerCount == 1` (Timer läuft weiter), kein Eintrag-Write im `writeLog`, keine ungefangene Exception.
- [x] **S4 nicht laufend:** Eintrag bereits beendet bzw. leer -> `true`, keine Writes.
- [x] **S5 Profil nicht mehr `from`:** `switchProfile('B')` vor dem Aufruf, Aufruf mit `'default'` -> `false`, keine Writes in A und B.
- [x] **S6 Ladelauf:** `holdReads`: Aufruf während des Ladens wartet, nach Freigabe wird gestoppt und `true` geliefert (Future-Zustand mit `completes`/Flag prüfen, nicht von Hand `elapse` verteilen).
- [x] **S7 Stop ohne Wirkung -> `false`:** `_ensureCurrentDay` scheitert (Tag nicht ladbar, z. B. Lesefehler nach Uhr-Sprung über Mitternacht bei gestopptem Eintrag ist hier nicht anwendbar; Szenario: laufender Eintrag, `startOrStopTimer` kehrt ohne Stop zurück). Falls ohne Eingriff in Produktionscode nicht erzeugbar, über den Fake-Notifier im Widget-/Guard-Test absichern und die Begründung in den PR-Text (nicht stillschweigend streichen).
- [x] **S8 Vortag über Mitternacht:** laufender Eintrag vom Vortag, Stop speichert am Starttag, danach Reinit auf neuen Tag -> `true`, State nicht laufend (Invariante über lokale Tagesschlüssel, TZ-unabhängig).
- [x] **S9 `isTimerRunning`:** `false` während `isLoading`, `true` bei laufendem Eintrag, `false` nach Stop.
- [x] Rot nachweisen (Methode existiert nicht -> Kompilierfehler; Fehlermeldung notieren), Impl, grün. Impl wie Architekturtabelle, keine Änderung an `_recalculateStateAndSave`.
- [x] Mutationsproben (Quelle ändern, Tests laufen lassen, zurücksetzen): Post-Check `!_isRunning` entfernen -> S7 rot; Profil-Check entfernen -> S5 rot; `await _initRun` entfernen -> S6 rot; direkt `_recalculateStateAndSave` mit eigenem Eintrag statt `startOrStopTimer` -> S2 rot.

### Schritt 2: `WorkProfileViewModel.checkSwitchAllowed` (Test zuerst)
Datei `work_profile_view_model_guard_test.dart` (Harness `profiles: true`, `workProfileViewModelProvider` aus `h.container`, `confirm`-Stub zählt Aufrufe).
- [x] **G1** kein Timer läuft -> `allowed`, `confirm` nie aufgerufen.
- [x] **G2** Timer läuft, `confirm` -> `true`, Stop ok -> `allowed`; Eintrag in A gespeichert (Writes wie S1).
- [x] **G3** Timer läuft, `confirm` -> `false` -> `cancelled`; **keine** Writes, Timer läuft weiter.
- [x] **G4** Timer läuft, Stop schlägt fehl (`failSaveOvertime`) -> `saveFailed`; State/Timer unverändert.
- [x] **G5** `isLoading` (`holdReads`) -> `allowed` ohne Dialog.
- [x] **G6** Reentranz: zweiter Aufruf während offenem `confirm` -> `busy`, `confirm` nur einmal; nach Abschluss wieder frei (auch nach `confirm`-Exception: Flag im `finally`; Ergebnis dann `cancelled`/nicht wechseln, Exception wird nicht weitergereicht, geloggt).
- [x] **G7** `deleteProfile(aktiv)` und `addProfile` (VM-Methoden) rufen den Guard **nicht** (Charakterisierung: bei laufendem Timer kein `confirm`, `deleteProfile` wechselt wie in PR 1) -> Guard bleibt ausschließlich Sache der zwei UI-Aufrufer; der bestehende `work_profile_view_model_test` bleibt grün.
- [x] Rot (Methode fehlt), Impl, grün. Mutation: `_switchPending`-Reset im `finally` entfernen -> G6 rot; `isLoading`-Ausnahme entfernen -> G5 rot.

### Schritt 3: Texte (ARB)
- [x] `app_de.arb` (Template, mit `@key`-Beschreibung und `placeholders` für `from`/`to`) und `app_en.arb` ergänzen, `flutter gen-l10n`. Test: ein Widget-Test im nächsten Schritt prüft de und en (en per `locale: Locale('en')`).

### Schritt 4: UI (Widget-Tests zuerst)
Datei `work_profile_switcher_switch_guard_test.dart`:
- [x] **W1 Wechsler, kein Timer:** Profil wählen -> kein Dialog, Profil wechselt sofort (Bestandsverhalten, `activeWorkProfileIdProvider` prüfen).
- [x] **W2 Timer läuft, Abbrechen:** Dialog sichtbar (Titel, Text mit beiden **Profilnamen**, Buttons `Abbrechen`/`Beenden und wechseln`); Abbrechen -> Profil bleibt, `stopRunningForSwitch` nie aufgerufen.
- [x] **W3 Bestätigen:** `Beenden und wechseln` -> `stopRunningForSwitch('default')` (Argument prüfen), danach Profil gewechselt.
- [x] **W4 Fehler:** Fake liefert `false` -> Profil bleibt, Snackbar `dashboardSaveError` (de-Text), Dialog zu.
- [x] **W5 Aktives Profil erneut wählen:** kein Dialog, kein Stop, kein Wechsel.
- [x] **W6 `isLoading`:** kein Dialog, Wechsel sofort.
- [x] **W7 Settings-Tab-Szenario:** nur der Switcher im Baum, Dashboard-VM **nicht** vorher gelesen, Fake zählt `build`: Guard instanziiert es per `ref.read` und fragt trotzdem (Entscheidung 8).
- [x] **W8 Anlegen, kein Timer:** `addProfile` läuft wie bisher (bestehender Test bleibt grün).
- [x] **W9 Anlegen, Timer läuft, Abbrechen:** `mockRepository.addProfile` nie aufgerufen (`verifyNever`), kein Profil, aktives Profil unverändert, Anlegen-Dialog bleibt mit Name offen.
- [x] **W10 Anlegen, Bestätigen:** Reihenfolge Stop -> `addProfile` -> Wechsel (`verifyInOrder` bzw. Aufruf-Log im Fake); Text nennt den **eingegebenen** Namen als Ziel.
- [x] **W11 Anlegen, Stop-Fehler:** kein `addProfile`, Snackbar `dashboardSaveError`, Anlegen-Dialog offen, Button wieder aktiv (`_isSaving` zurückgesetzt).
- [x] **W12 en:** Dialogtexte mit `Locale('en')`.
- [x] **W13 Löschen aktives Profil bei laufendem Timer:** kein Bestätigungsdialog (nur der bestehende "Profil löschen?"-Dialog), Fake-`stopRunningForSwitch` nie aufgerufen (Entscheidung 5).
- [x] Rot (Dialog fehlt), dann Impl:
  - `profile_switch_confirm_dialog.dart` (`showProfileSwitchConfirmDialog`).
  - `WorkProfileSwitcher.onSelected`: Notifier/`ScaffoldMessenger`/Namen/L10n **vor** dem ersten `await` lesen (Widget kann beim Wechsel neu bauen), `context.mounted` nach jedem `await`; aktives Profil -> return; sonst `checkSwitchAllowed(confirm: () => showProfileSwitchConfirmDialog(...))`, bei `allowed` `setActiveProfile(...)`, bei `saveFailed` Snackbar `dashboardSaveError`, `cancelled`/`busy` nichts.
  - `AddWorkProfileDialog._save`: nach `unfocus` und `_isSaving = true`, **vor** `addProfile`, Guard mit `toName = name`; Messenger/L10n wie bisher vor dem `await`; bei `!= allowed`: `_isSaving = false` (nur wenn `mounted`), `saveFailed` -> Snackbar, return.
- [x] Mutationsproben: Guard-Aufruf im Switcher entfernen -> W2/W3/W4 rot; Guard vor `addProfile` hinter den API-Aufruf verschieben -> W9 rot; `_isSaving`-Reset entfernen -> W11 rot.
- [x] Alle Tests grün (inkl. TZ-Läufe).

### Schritt 5: Doku `mobile/CLAUDE.md`
- [x] Abschnitt "Profilwechsel (#388)": Satz "Ein Bestätigungsdialog … nicht Teil von PR 1 (offen)" und "ein Guard vor dem API-Aufruf fehlt noch" ersetzen durch den neuen Punkt **Bestätigungsdialog (PR 2)**: `WorkProfileViewModel.checkSwitchAllowed` (Ergebnis-Enum, `_switchPending`), Guard-Orte (Wechsler `onSelected`, `AddWorkProfileDialog` vor dem API-Aufruf), `DashboardViewModel.isTimerRunning`/`stopRunningForSwitch` (normaler Stop-Pfad, Post-Check `!_isRunning`, Profil-/Ladelauf-Prüfung), Fehler = Snackbar `dashboardSaveError` und kein Wechsel; bewusst ohne Guard: `deleteProfile(aktiv)`, Logout, Neustart/gemerktes Profil (Einfrieren bleibt gültig). Neue Wechselpfade müssen den Guard nutzen. "Bekannte Grenzen" (1)/(2) präzisieren: Dialog vermindert, verhindert aber Parallelbetrieb nicht (Timer in B starten ist weiter möglich, Eintrag-Write-Fehler #412). Test-Dateien nennen.
- [x] Keine widersprüchlichen Aussagen in "Fehler beim Speichern (#402)" prüfen (Verweis auf #388 ergänzen, falls nötig).

## Umsetzungsstand (Developer)
Schritte 0-5 erledigt. Abweichungen: (1) `isLoading`-Sonderfall im Guard entfallen, `isTimerRunning` ist beim Laden `false` (G5 bleibt als Charakterisierung, Mutation nicht rot); (2) Guard erlaubt den Wechsel, wenn das Dashboard-VM nicht baubar ist (Bestandstest `work_profile_switcher_test` ohne Firebase-Override sonst rot), Test G8; (3) S7 im VM nicht erzeugbar (Post-Check nicht per Mutation belegt), W6 entfaellt (durch S9/G5 abgedeckt); (4) Mutation "eigener Eintrag statt startOrStopTimer" nicht durchgefuehrt.

## Validierung (vor PR)
- Aus `mobile/`: `dart format --set-exit-if-changed lib test && flutter analyze --no-fatal-infos && dart run custom_lint && flutter test`.
- `TZ=Europe/Berlin flutter test` (CI), zusätzlich `TZ=UTC`, `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland` für `dashboard_view_model_switch_test`, `work_profile_view_model_guard_test`, `work_profile_switcher_switch_guard_test`, `work_profile_switcher_test`, `work_profile_view_model_test`, `dashboard_view_model*_test`.
- Neue Test-Dateien 3x wiederholen (Flakiness durch Scheduler-Reihenfolge).
- Kein `build_runner` nötig; falls entgegen Plan `@GenerateMocks` ergänzt wurde: `dart run build_runner build --delete-conflicting-outputs`, Diff in `*.mocks.dart` prüfen.
- `388-pr-pr2.md` (oder Ergänzung zu `388-pr.md`): Rot-Nachweise, Mutationsproben, Hinweis "Texte nur de/en per ARB", Verweis auf #412/#413.
- Manuelle Verifikation (nicht automatisierbar): Gerät/Emulator mit Premium-Konto und zwei Profilen: Timer in A läuft, Wechsel -> Dialog; Abbrechen: nichts ändert sich; "Beenden und wechseln": A-Eintrag beendet, B aktiv, Rückwechsel zeigt A beendet; Flugmodus: Wechsel scheitert mit Snackbar; "Neues Profil" mit laufendem Timer: Abbrechen legt kein Profil an; Dialog in EN prüfen.

## Risiken
- `stopRunningForSwitch` hängt am Stop-Pfad (#402/#379-Tests sind das Sicherheitsnetz); keine Änderung dort, nur neue Methode darauf.
- Der Post-Check `!_isRunning` ist die einzige Absicherung gegen "Stop ohne Wirkung -> trotzdem wechseln" (Known Limit #402-4); S7/W-Fake-Test sind Pflicht.
- Nach `await` im Switcher kann das Widget neu gebaut/disposed sein (Wechsel invalidiert VM, Tab-Wechsel): alles Nötige vorher lesen, `context.mounted` prüfen.
- Dialog-Text zeigt nur das alte Profil als Stopp-Ziel; der Nutzer sieht nicht, wie lange A lief. Bewusst wie im Web.
- Dialog verhindert Parallelbetrieb nicht (Start in B bleibt möglich), nur das Einfrieren beim Wechsel.

## Offene Fragen an die Hauptsession
Keine blockierenden. Annahmen, die ich getroffen habe (bitte bei Widerspruch melden): (1) 3 statt 4 ARB-Keys, Fehlertext = `dashboardSaveError`; (2) Anlegen-Dialog bleibt bei Abbrechen/Fehler offen; (3) Wahl des bereits aktiven Profils öffnet nie einen Dialog.
