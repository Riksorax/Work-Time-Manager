# Mobile-Research: #388 — Mobile-Dashboard: Profilwechsel bei laufendem Timer, Restrisiken und fehlende Tests
Datum: 2026-10-04
Typ: Bug-/Absicherungs-Analyse (Folge-Issue zu #380). Kein Code geändert. Die Race (Abschnitt 4) ist per temporärem Probe-Test in `fakeAsync` reproduziert (Datei danach wieder gelöscht, `git status` sauber).

## Aufgabe
Issue-Text (Label `bug`, keine Kommentare): Mobile gilt als „grundsätzlich sicher“ beim Profilwechsel (`ref.watch` an den Repos, Rebuild löst `_init` aus, `onDispose` bricht Timer ab, Repos konstruktor-gebunden). Zu klären:
1. Einfrieren des laufenden Timers explizit entscheiden und dokumentieren, ggf. Bestätigungsdialog „Beenden und wechseln“ wie Web (#380 Stufe 2, neue ARB-Keys de/en).
2. In-flight-Race prüfen (Wechsel im Netzwerkfenster einer Schreibaktion).
3. Fehlenden Profilwechsel-Test im `DashboardViewModel` schreiben (Profil-Fakes, FakeClock aus #379).
4. Kein UI-Hinweis beim Wechsel mit laufendem Timer.

Akzeptanz (abgeleitet): Verhalten per Test abgesichert, Entscheidung zum Einfrieren dokumentiert, optional Dialog.
Nicht Teil: parallele Timer pro Profil (Web-Option c), Reparatur bereits verfälschter Daten, Backend-/Web-Änderungen.

## Kernbefunde (Kurzfassung)
- Die Issue-Annahme „konstruktor-gebunden, also nie ins falsche Profil“ gilt **nicht vollständig**: `_recalculateStateAndSave` löst `saveWorkEntryUseCaseProvider` erst **nach** den Saldo-`await`s auf und landet bei einem Wechsel im neuen Profil (Abschnitt 4, per Probe belegt).
- Die Reihenfolge ist auf Mobile umgekehrt wie im Web: erst Saldo, dann Eintrag. Das Issue (Eintrag gespeichert, Saldo noch nicht) beschreibt das harmlose Gegenfenster; das gefährliche ist „Saldo gespeichert, Eintrag noch nicht“.
- `ref.mounted` bleibt über einen Provider-Rebuild `true` (riverpod 3.0.3): die einzigen Überholungs-Guards sind `_initGen`/`stale()` in `_load`. `_recalculateStateAndSave`, `_startTimerIfNeeded`-Folgeaufrufe und der Reinit nach Mitternacht haben keinen Gen-Guard.
- Einfrieren und Autosave sind sicher (belegt): nach dem Wechsel keine Writes mehr, Rückwechsel setzt den Timer fort.

## Betroffene Dateien
| Datei | Warum |
|---|---|
| `mobile/lib/core/providers/providers.dart` (Z. 124-200, 247-282) | `settings/work/overtimeRepositoryProvider` watchen `activeWorkProfileIdProvider` und bauen Repos mit `profileId` im Konstruktor; `ActiveWorkProfileIdNotifier` (`String?`, `null` = Standard, in SharedPreferences je Nutzer gemerkt, `setActiveProfile` setzt `state` synchron, Prefs-Write danach, Aufrufer awaiten nicht) |
| `mobile/lib/presentation/view_models/dashboard_view_model.dart` | `build` (Z. 45-66), `_load`/`_init`/`_initGen`, `onDispose`, `_autoSave` (Z. 311), `_recalculateStateAndSave` (Z. 510-609, Race), `_ensureCurrentDay`, alle Schreibaktionen |
| `mobile/lib/presentation/widgets/work_profile_switcher.dart` (Z. 56) | einziger interaktiver Wechsel: `onSelected` ruft direkt `setActiveProfile`, kein Hinweis/Guard. Eingebunden im AppBar von Dashboard, Reports, Settings (`*_page.dart`/`dashboard_screen.dart:78`), also bei laufendem Timer überall bedienbar |
| `mobile/lib/presentation/view_models/work_profile_view_model.dart` | `addProfile` wechselt nach dem Anlegen **automatisch** ins neue Profil; `deleteProfile` löscht per API **zuerst**, wechselt danach auf Standard (Z. 39-52) |
| `mobile/lib/presentation/widgets/add_work_profile_dialog.dart`, `manage_work_profiles_dialog.dart` | Aufrufer von `addProfile`/`deleteProfile` (Bestätigungsdialog „unwiderruflich“ beim Löschen existiert) |
| `mobile/lib/data/repositories/work_repository_impl.dart`, `firebase_overtime_repository_impl.dart`, `hybrid_*_impl.dart`, `settings_repository_impl.dart` | Profil als `final`-Feld; Overtime-Repo hält zusätzlich einen Cache pro Instanz; Settings-Keys mit Profil-Suffix |
| `mobile/lib/presentation/view_models/settings_view_model.dart` (Z. 154-175, 232-243) | watcht Overtime-UseCase und Settings-Repo (Rebuild bei Wechsel, anders als im Web `SettingsPageService`); `setOvertimeBalance` ruft `dashboard.updateOvertimeFromSettings` |
| `mobile/test/support/dashboard_harness.dart`, `fake_repositories.dart`, `fake_clock.dart` | Testbasis (#379); Harness überschreibt Repos mit festen `overrideWithValue` und kennt kein Profil |
| `mobile/test/presentation/widgets/work_profile_switcher_test.dart` | Muster für Widget-Tests des Wechslers (nur Premium/Paywall-Fälle) |
| `mobile/lib/l10n/app_de.arb` / `app_en.arb` | nur Option B: neue Keys (vorhanden: `cancel`, `switchProfileTooltip`, `deleteProfile*`) |
| `mobile/CLAUDE.md` | Entscheidung/Verhalten dokumentieren (neuer Abschnitt analog „Tageswechsel (#379)“) |

## Datenfluss
Wechsel: `WorkProfileSwitcher.onSelected` -> `ActiveWorkProfileIdNotifier.setActiveProfile` (`state = id` sofort, danach Prefs) -> `workRepositoryProvider`/`overtimeRepositoryProvider`/`settingsRepositoryProvider` invalidiert -> UseCases (`getTodayWorkEntry`, `saveWorkEntry`, `getOvertime`, ...) invalidiert -> `DashboardViewModel` invalidiert.
Laden: `_init` -> `_load` -> `ref.read(getTodayWorkEntryUseCaseProvider)` + `ref.read(overtimeRepositoryProvider)` zu Beginn -> `getTodayWorkEntry.call()` -> `ensureOvertimeLoaded`/`ensureLastUpdateLoaded` -> `DashboardState` per Konstruktor -> `_startTimerIfNeeded`.
Schreiben: Aktion -> `_ensureCurrentDay` -> `_recalculateStateAndSave` -> `overtimeRepository.saveOvertime` -> `saveLastUpdateDate` -> `_checkOvertimeWarning` -> `state = …` -> `ref.read(saveWorkEntryUseCaseProvider).call(entry)` -> `_startTimerIfNeeded`. Autosave: 30-s-Tick -> `_autoSave` -> `ref.read(saveWorkEntryUseCaseProvider)`.
Persistenz: `HybridWorkRepositoryImpl` -> `WorkRepositoryImpl(profileId)` -> `ApiDataSource` -> .NET-Backend (`?profileId=`); ausgeloggt SharedPreferences (`Local*`, nicht profilgebunden; Profile gibt es ohne Login nicht, der Wechsler ist dann unsichtbar).

## 1. Ist-Zustand Mobile

### 1.1 Wie das Profil an den Repos hängt
- `activeWorkProfileIdProvider` ist ein manueller `NotifierProvider<…, String?>`. `build` watcht `authStateProvider` (Login/Logout setzt zurück auf Standard) und liest den gemerkten Wert aus SharedPreferences.
- Alle drei Repo-Provider (`@riverpod`, autoDispose) **watchen** das aktive Profil und geben es dem Konstruktor von `WorkRepositoryImpl`/`FirebaseOvertimeRepositoryImpl`/`SettingsRepositoryImpl` mit. Ein einmal gebautes Repo behält sein Profil. Das ist der Unterschied zum Web-Getter-Muster (`activeProfileIdForApi` zum Aufrufzeitpunkt).
- Die UseCases (`saveWorkEntryUseCase`, `getTodayWorkEntryUseCase`, `getOvertimeUseCase`, …) watchen die Repos, sind also mit-invalidiert. **Entscheidend ist daher, wann ein Aufrufer den Provider auflöst**, nicht dass die Repos gebunden sind.

### 1.2 Was bei einem Wechsel im DashboardViewModel passiert (riverpod 3.0.3, aus dem Paketquelltext geprüft)
1. `setActiveProfile` setzt `state` synchron. Die Invalidierung läuft kaskadierend **sofort**: `invalidateSelf` ruft `runOnDispose()` unmittelbar auf. Damit laufen die `ref.onDispose`-Callbacks des ViewModels sofort: `_timer`/`_autoSaveTimer` abgebrochen, `_initGen++`. Der eigentliche Rebuild folgt erst mit dem Scheduler-Task (`Timer(Duration.zero)` im ProviderScope), oder früher, wenn jemand einen dirty Provider per `ref.read` liest.
2. `build()` läuft auf **derselben Notifier-Instanz** neu: `_loadedOk = false`, neuer `ref.listen(todayProvider)`, neues `ref.onDispose`, `Future.microtask(_init)`, State = `DashboardState.initial` (Ladezustand). Danach lädt `_init` das Profil B.
3. Wichtig: Beim Rebuild (im Gegensatz zum echten Dispose) wird `ref.mounted` **nicht** `false` (`mounted => !_element._disposed`, `_disposed` nur in `dispose()`, dokumentiert: „will not be executed when a provider rebuilds“). Der Code-Kommentar-Gedanke „`!ref.mounted` verwirft überholte Aktionen“ trägt für Profilwechsel also nicht; nur `_initGen` in `_load` (`stale()`) schützt Ladeläufe.
4. `_load` ist gegen Überholung abgesichert (Gen-Guard nach jedem `await`; vorhandener Test „ueberholter _init bei Rebuild: neuer Lauf gewinnt“ in `dashboard_view_model_day_change_test.dart` Z. 149).

### 1.3 Einfrieren bei laufendem Timer (belegt per Probe)
- Jede Schreibaktion speichert sofort; der Autosave schreibt denselben, unveränderten Eintrag erneut (`_autoSave`-Kommentar). Der Eintrag bleibt also im alten Profil mit `workStart`, ohne `workEnd` gespeichert („laufend“).
- Probe (FakeClock 10:00, A-Eintrag Start 08:00 laufend, Wechsel auf B nach 65 s): vor dem Wechsel 2 Autosaves (30 s, 60 s) in A; nach dem Wechsel 0 Writes in A und B über weitere 5 Minuten, Timer-Zähler 0. Rückwechsel auf A: genau 1 Timer, `workEnd == null`, Brutto 2:06:05 (Start 08:00 bis 10:06:05, also **inklusive der in B verbrachten Zeit**). Das entspricht der Issue-Beschreibung.
- Konsequenzen des Einfrierens: (a) Zeit in B zählt in A weiter; (b) bei Nichtrückkehr bleibt A offen; ein laufender Eintrag läuft nach #379 über Mitternacht weiter und wird nie automatisch beendet (wie nach einem App-Neustart, siehe unten); wie Reports/Kalender einen offenen Eintrag in A darstellen, wurde nicht untersucht; (c) A und B können gleichzeitig laufen (jeder Wechsel auf B lädt B unabhängig, parallele Erfassung in zwei Profilen, in Web ebenfalls akzeptiert).
- Konsistenz zu bestehendem Verhalten: Der Zustand „Eintrag läuft serverseitig, App lädt neu“ ist nach App-Neustart/Logout/Login ohnehin der Normalfall (Timer startet aus dem gespeicherten `workStart`). Einfrieren beim Profilwechsel ist semantisch „dieses Profil wird geschlossen, ohne etwas zu ändern“. Es ändert nie Daten, deshalb ist es der sichere Boden (Web: Stufe 1, Option d).

### 1.4 `_ensureCurrentDay` / Tageswechsel (#379) und Autosave
- `_ensureCurrentDay` lässt laufende Einträge unberührt; sonst wartet es auf `_initRun`, prüft `current()` (`_loadedOk` und Tag) und lädt ggf. nach. Nach einem Profilwechsel ist `_loadedOk == false`, bis B geladen ist: eine Aktion, die in dieser Zeit angestoßen wird, wartet auf B und wirkt dann konsistent auf B (kein Datenmix). Ein Profilwechsel ist kein `dayChange` (normale `lastUpdate`-Heuristik; `_onDayChange` ignoriert laufende Einträge).
- Autosave ist sicher: Der Timer wird bei Invalidierung sofort gecancelt; ein bereits laufender `_autoSave` hat den UseCase **vor** dem `await` aufgelöst (alter Provider, altes Repo). Theoretisch löst ein Autosave-Tick in der Zeitspanne zwischen Invalidierung und Rebuild nicht mehr aus, weil der Timer schon weg ist.
- Der Kommentar in `_autoSave` („Reinit findet nie bei laufendem Timer statt“) ist durch den Profilwechsel überholt (Profilwechsel invalidiert auch bei laufendem Timer); das Ergebnis bleibt aber richtig, weil `onDispose` den Timer abräumt.

### 1.5 Wechsel-Pfade (wo wird gewechselt)
| Pfad | Verhalten heute |
|---|---|
| Wechsler im AppBar (Dashboard/Reports/Settings) | direkt `setActiveProfile`, kein Hinweis |
| `addProfile` (Dialog, Premium) | API-Anlage, `invalidate(workProfiles)`, dann **automatischer** Wechsel ins neue Profil; alter Timer wird eingefroren |
| `deleteProfile` | API-Löschung zuerst, dann bei aktivem Profil Wechsel auf Standard. **Fenster:** zwischen API-Delete und Wechsel kann ein Autosave (alle 30 s) in das gerade gelöschte Profil schreiben. Laut Web-Befund (#380) prüft das Backend `ProfileScope` keine Profilexistenz (verwaiste Dokumente); hier nicht erneut verifiziert. Web hat das mit „zuerst wechseln, dann API, bei Fehler zurück“ geschlossen. Das Löschen **inaktiver** Profile ist unkritisch |
| Login/Logout/Kontowechsel | `ActiveWorkProfileIdNotifier.build` setzt zurück; Dashboard lädt neu; gleiche Einfrier-Semantik für den Cloud-Eintrag |
| App-Neustart | gemerktes Profil wird wiederhergestellt, Dashboard lädt es; kein Wechsel im eigentlichen Sinn |
Alle Wege außer dem Wechsler laufen durch `WorkProfileViewModel`/`ActiveWorkProfileIdNotifier`; es gibt keinen zentralen Guard-Hook (Web: `requestSwitch` im Core).

## 2. Weitere Stellen (nur gemeldet)
- `SettingsViewModel` watcht `getOvertimeUseCaseProvider` und `settingsRepositoryProvider` und lädt beim Wechsel neu; `setOvertimeBalance` liest die Provider zum Aufrufzeitpunkt (Saldo und `updateOvertimeFromSettings` im selben, dann aktuellen Profil). Das Web-Problem (`SettingsPageService._loadOvertime` ohne Profil-Trigger) existiert auf Mobile in der Form nicht (nur Code-Lektüre, nicht per Test belegt).
- `ReportsViewModel` und `YearlyReportViewModel` lesen `activeWorkProfileIdProvider` (`ref.read`); nicht Teil dieses Issues, nicht untersucht.
- `_checkOvertimeWarning` liest `settingsRepositoryProvider` nach den `await`s; nach einem Wechsel würden die Schwellwerte von B geprüft (nur Benachrichtigung, geringfügig).

## 3. In-flight-Race (Frage 2), belegt am Code und per Probe
Ablauf in `_recalculateStateAndSave(updatedEntry, save: true)` für einen **abgeschlossenen** Eintrag (`workStart != null && workEnd != null`, also Stop, `setManualEndTime`, `setManualStartTime`/`updateBreak`/`deleteBreak`/`startOrStopBreak` auf beendetem Eintrag):
1. sync: `overtimeRepository = ref.read(overtimeRepositoryProvider)` (Profil A, gebunden)
2. `await saveOvertime(total)`, `await saveLastUpdateDate`, `await _checkOvertimeWarning` (zwei Netzwerkrunden plus ggf. Benachrichtigung = **Fenster 1**)
3. `if (!ref.mounted) return;` (greift beim Rebuild nicht, siehe 1.2)
4. `state = state.copyWith(workEntry: updatedEntry, totalOvertime: …)` (überschreibt den State des neuen Profils)
5. **erst jetzt** `ref.read(saveWorkEntryUseCaseProvider)` (dirty Provider, wird beim `read` neu gebaut, also Profil B), `await call(updatedEntry)` (**Fenster 2**: Repo schon gebunden)
6. `_startTimerIfNeeded()`; bei Stop eines Vortags danach `_init(dayChange: true)`.

Probe (Mo 2026-10-05, Uhr 17:00, A: Start 08:00 laufend, Saldo 120 min; B: fertiger Eintrag 09:00–12:00, Saldo 30 min; Stop in A, Wechsel auf B im Fenster, danach Freigabe):

| Wechsel im … | Saldo | Eintrag | Zustand danach |
|---|---|---|---|
| **Fenster 1** (Saldo-Write hängt) | A: 135 min | **B**: 08:00–17:00 überschreibt B-Eintrag 09:00–12:00 (A-Eintrag bleibt in A „laufend“ und ohne Ende) | Dashboard zeigt unter B den A-Eintrag und A-Saldo 135 (State überschrieben) |
| **Fenster 2** (Eintrag-Write hängt) | A: 135 min | A: 08:00–17:00 | konsistent; B-State bleibt B (09:00–12:00) |

Beantwortung der Issue-Frage: Die konstruktor-gebundenen Repos schließen die Race **nicht** vollständig aus. Sie schützen nur Writes, deren Provider vor dem Wechsel aufgelöst wurde (Saldo-Repo, Fenster 2, Autosave). Der Eintrag-Write löst den UseCase zu spät auf. Gleiche Datenverfälschung wie im Web (Eintrag unter falschem Profil, A-Saldo-Wert abgekoppelt vom Eintrag, B-Tageseintrag überschrieben, `lastUpdated`-Heuristik von B in Folge möglicherweise falsch), nur mit umgekehrter Reihenfolge.
Folgen, die nur aus dem Code abgeleitet sind (nicht per Test belegt): (a) Start-/Pause-/Neue-Session-Aktionen (ohne `workEnd`) speichern **keinen** Saldo und lösen den UseCase ohne `await` vor dem `ref.read` auf; ihr Fenster ist praktisch nur das `await _ensureCurrentDay()`. (b) Nach dem Eintrag-Write ruft eine überholte Aktion `_startTimerIfNeeded()` und ggf. `_init(dayChange: true)` auf dem neuen Profil auf (bei Stop eines Vortags, extrem selten; ein zusätzlicher Reload mit falscher Basis-Annahme).
Dauer des Fensters 1: zwei sequenzielle API-Aufrufe (bei schlechtem Netz Sekunden). Auslöser sind einfache Nutzeraktionen (Stop-Klick, dann direkt Profilmenü). Der Schweregrad entspricht dem Web-Fund aus #380 (dort Stufe 1, „schwerer Fund“).

Lösungsrichtung (Konzept, kein Code): Pro Aktion beim Start (nach `_ensureCurrentDay`, synchron zusammen mit dem Lesen des `state`) die UseCases/Repos **und** `_initGen` festhalten und alle Writes der Aktion mit den festgehaltenen Objekten ausführen (Eintrag und Saldo landen immer zusammen im Profil der Aktion); nach jedem `await` bei überholtem `gen` keinen `state`-Schreibzugriff, kein `_startTimerIfNeeded`, keinen Reinit mehr. Optional: Saldo/Warnung ebenfalls mit festgehaltenen Werten. Entspricht dem `ActionCtx` aus Web-PR 1.

## 4. Fehlende Tests (Frage 3)
Es gibt keinen Profilwechsel-Test für das Dashboard. `activeWorkProfileIdProvider` kommt in Tests nur in `work_profile_view_model_test.dart`, `reports_view_model_test.dart` und `yearly_report_view_model_test.dart` vor. Der `Harness` überschreibt Repos mit festen Werten (`overrideWithValue`), die auf kein Profil reagieren; auch `overtimeRepositoryProvider`/`settingsRepositoryProvider` sind fest. Benötigt:
- Profil-Quelle: `activeWorkProfileIdProvider.overrideWith(<Test-Notifier mit build() = null, setActiveProfile setzt state>)` (kein Auth/Prefs nötig).
- Repos je Profil: `workRepositoryProvider.overrideWith((ref) => ref.watch(active) == null ? workA : workB)`, ebenso Overtime und Settings (unterschiedliche `workdays`/`weeklyHours`).
- Erweiterung `test/support/fake_repositories.dart`: Hold-Möglichkeit für `saveOvertime` und `saveWorkEntry` (Completer, analog `holdReads`/`holdOvertimeLoad`), Schreib-Log mit Repo-Name.
- Wechsel auslösen: `setActiveProfile('B')`, danach `async.elapse(Duration.zero)` (Scheduler-Task) und `flushMicrotasks`, wie im vorhandenen Rebuild-Test.

## 5. Optionen für das Einfrieren (Frage 4)
| Option | Inhalt | Aufwand | Risiko |
|---|---|---|---|
| **A** Einfrieren dokumentieren + Tests (+ Race-Fix, siehe unten) | Verhalten wie heute, in `mobile/CLAUDE.md` als bewusste Entscheidung festhalten; Tests für Einfrieren, Rückwechsel, Autosave, In-flight; Race-Fix im VM | S-M: VM-Änderung klein (festhalten + Gen-Guard in `_recalculateStateAndSave`), Testharness-Erweiterung, ca. 10-14 Tests, keine ARB-Keys | niedrig; Verhalten für Nutzer unverändert; Restnachteil: Zeit in B zählt in A weiter, offene Einträge bei vergessenem Profil, kein UI-Hinweis |
| **B** Dialog „Abbrechen / Beenden und wechseln“ (wie Web #380 Stufe 2) | Wechsler und `addProfile` fragen bei laufendem Timer; Bestätigung stoppt/speichert im alten Profil (Pflichtpausen wie Stop-Button) und wechselt erst danach; Speicherfehler: kein Wechsel, Snackbar | M-L: neue Methode `stopRunningForSwitch(): Future<bool>` im VM (dabei `_recalculateStateAndSave` mit Ergebnis/Rollback ausstatten), Guard im Wechsler (`onSelected`) und im `AddWorkProfileDialog` (vor dem API-Aufruf), 4 ARB-Keys de/en + `flutter gen-l10n`, Widget- und VM-Tests, ca. 12-16 Tests zusätzlich | mittel: Eingriff in zentralen, stark getesteten Stop-Pfad; Nebeneffekt: stilles Beenden der Arbeitszeit nur nach expliziter Bestätigung; kein zentraler Hook wie `requestSwitch` (zwei Aufrufer) |
| C parallele Timer pro Profil | nicht empfohlen (Web: gleiche Einschätzung, XL) | XL | hoch |

Mobile-Besonderheiten für B:
- Auslöser nur UI: `WorkProfileSwitcher.onSelected` und `AddWorkProfileDialog` (Guard **vor** dem API-Aufruf, wie Web-Entscheidung O1, sonst verwaistes Profil bei „Abbrechen“). `deleteProfile` des aktiven Profils bleibt ohne Dialog (Eintrag wird ohnehin gelöscht), Logout/Neustart ebenfalls.
- Der Dialog gehört in die UI-Schicht (VM hat keinen Context); VM liefert nur „läuft ein Timer?“ und `stopRunningForSwitch`. Prüfung „läuft“ über den Dashboard-State (`workEntry` läuft, `!isLoading`); der Provider ist nicht autoDispose, wird aber erst beim ersten Lesen gebaut (Frage 8).
- Bestehender Nebenbefund im Stop-Pfad (nur Code-Lektüre): `startOrStopTimer` cancelt `_timer` vor dem Speichern; wirft `saveOvertime` (nicht abgefangen, anders als der Eintrag-Write seit #336), bleibt der State „laufend“ ohne Timer und die Exception geht an den Aufrufer. Für B zwingend zu behandeln (Ergebnis + Rollback), für A kein Teil des Issues.
- Neue Keys (de duzend, Beschreibung `@key` verpflichtend), Vorschlag in Anlehnung an Web: `switchWhileRunningTitle` „Zeiterfassung läuft“, `switchWhileRunningText` (Platzhalter `from`/`to`; „Im Profil „{from}“ läuft noch eine Zeiterfassung. Sie wird beendet und gespeichert, bevor du in das Profil „{to}“ wechselst.“), `stopAndSwitchButton` „Beenden und wechseln“, `switchSaveFailed` „Wechsel abgebrochen: Die Zeiterfassung konnte nicht gespeichert werden.“; „Abbrechen“ = vorhandenes `cancel`. Englisch parallel, Namen der Profile statt IDs im Text.

**Empfehlung:** Race-Fix + Tests + Dokumentation des Einfrierens sofort (Option A als verbindlicher Boden, deckt den Datenverlust-Pfad). Den Dialog (B) als eigenen, nachgelagerten PR, weil (1) das Einfrieren selbst keine Daten ändert und dem Neustart-Verhalten entspricht, (2) B den zentralen Stop-Pfad umbaut und eigene ARB-/Widget-Tests braucht, (3) Web denselben Schnitt gewählt hat (Stufe 1 vor Stufe 2). Falls UX-Parität zum Web gewünscht ist, ist B danach klein genug und baut auf dem Race-Fix (festgehaltener Kontext) auf.

## 6. Testplan (Frage 5)
Grundsätze: feste lokale Daten (`DateTime(2026, 10, 5, …)`, Montag; Wochentage sind zonenunabhängig, wie im Harness), `FakeClock` mit `bind(async)`, alles in `fakeAsync` über `scenario(...)`/`Harness` (Timer-Leak-Check am Ende), keine `DateTime.now()`, keine Zeitzonenannahme. CI: `TZ=Europe/Berlin flutter test` (`.github/workflows/ci.yml`); lokal zusätzlich `TZ=UTC`, `America/Los_Angeles`, `Pacific/Auckland`. Test-Datei: `test/presentation/view_models/dashboard_view_model_profile_test.dart` (+ Harness-Erweiterung in `test/support`).

ROT vor Fix (Race, per Probe bereits rot nachgewiesen):
1. Stop in A, Wechsel im Saldo-Fenster: Eintrag landet in A (nicht B), B-Eintrag und B-Saldo unverändert, State = B (Eintrag/Total von B), kein A-Eintrag unter B.
2. `it.each` für alle Aktionen mit abgeschlossenem Eintrag (Stop, `setManualEndTime`, `setManualStartTime`, `updateBreak`, `deleteBreak`, `startOrStopBreak`) im Saldo-Fenster: alle Writes im Profil des Aktionsbeginns.

GRÜN (Charakterisierung, sichert Einfrieren und bekannte Garantien):
3. Einfrieren: A läuft (mit Autosaves vorher), Wechsel auf B: nach 5 Minuten 0 Writes in A und B, `periodicTimerCount` entspricht B, State = B-Eintrag, Basis/Total aus B-Saldo (A 120 min, B 30 min), Soll/`isExtraDay` aus B-Settings (z. B. B `workdays` Di-Do, Montag = Zusatztag).
4. Rückwechsel: A-Eintrag unverändert (`workEnd == null`, kein Write beim Wechsel), 1 Timer, Brutto aus Differenz der Fake-Uhr (Zeit in B zählt mit).
5. Autosave nach Wechsel: 31 s nach dem Wechsel kein Write mit A-Eintrag in B (und umgekehrt bei Parallelbetrieb A frozen/B läuft).
6. Wechsel im Eintrag-Fenster: beide Writes in A, kein `_startTimerIfNeeded` für B (Timerzahl wie B).
7. Überholter Lauf A -> B -> A mit `holdReads`: Endzustand A, kein B-Timer (analog vorhandenem Rebuild-Test); Wechsel während `holdOvertimeLoad`: später Ergebnis von A wird verworfen.
8. Tageswechsel x Profilwechsel: Wechsel um 23:59:50, Mitternacht danach: genau ein gültiger Endzustand, Profilwechsel nutzt die `lastUpdate`-Heuristik (kein `dayChange`).
9. Cleanup: nach `dispose` kein Timer (Timer-Zähler 0).
10. `WorkProfileViewModel`: `addProfile` mit laufendem Dashboard-Timer (Repo gemockt, Container wie in `work_profile_view_model_test.dart`) friert ein; `deleteProfile(aktiv)`: Reihenfolge der Aufrufe festhalten (heute API-Delete vor Wechsel; bei Umstellung auf „zuerst wechseln“ ROT/GRÜN-Test, Fehler-Rückwechsel).
Option B zusätzlich: VM-Test `stopRunningForSwitch` (Reihenfolge Saldo, Eintrag, danach Wechsel; Pflichtpausen identisch zu `startOrStopTimer`; Speicherfehler: Rollback, kein Wechsel; Timer wurde zwischenzeitlich gestoppt), Widget-Tests Wechsler (kein Timer: kein Dialog; Abbrechen: Profil bleibt, kein Write; Bestätigen; Fehler: Snackbar `switchSaveFailed`; de/en-Text; `AddWorkProfileDialog`: Abbrechen legt nichts an).
Mutationsprüfung nach dem Fix (Quelle ändern, wieder zurücksetzen): festhalten der UseCases entfernen -> Tests 1/2 rot; Gen-Guard vor `state =`/`_startTimerIfNeeded` entfernen -> Test 6/7 rot; `onDispose`-Timer-Abbruch entfernen -> Test 3/5 rot.

## 7. Aufteilung in PRs (Frage 6)
- **PR 1 (Refs #388, nicht `Closes`, falls B folgt):** Harness-Erweiterung + Profil-Tests (Rot-Nachweis für Test 1/2 zuerst), Race-Fix in `dashboard_view_model.dart` (Aktionskontext festhalten, Gen-Guard), optional `deleteProfile`-Reihenfolge, Abschnitt „Profilwechsel (#388)“ in `mobile/CLAUDE.md` mit der Entscheidung „Einfrieren, keine Daten ändern; Rückwechsel setzt fort; Dialog optional“; ggf. korrigierter Kommentar in `_autoSave`. Keine ARB-Keys, keine UI-Änderung, nur Mobile.
- **PR 2 (`Closes #388`, nur bei Option B):** `stopRunningForSwitch` (+ Ergebnis/Rollback in `_recalculateStateAndSave`), Guard in `WorkProfileSwitcher` und `AddWorkProfileDialog`, 4 ARB-Keys de/en, VM- und Widget-Tests, Doku-Ergänzung.
- Bei Option A allein: PR 1 mit `Closes #388`.
- Folge-Issues (von der Hauptsession anzulegen, falls gewünscht): Exception-Behandlung im Stop-Pfad (Nebenbefund, siehe 5), Behandlung offener Einträge in Reports/Kalender (nicht untersucht).

## Plattformübergreifend
Nur Mobile. Web hat Stufe 1 und 2 umgesetzt (`web/thoughts/380-*.md`, `web/CLAUDE.md` „Profilwechsel (#380)“); Texte der Dialog-Keys zur Parität an Web anlehnen. Kein Backend-Endpunkt, keine Firestore-Regel, keine Migration (`DataSyncService` nicht betroffen). Backend-Hinweis aus dem Web-Befund: `ProfileScope` prüft keine Profilexistenz (verwaiste Dokumente bei Schreibzugriff in gelöschtes Profil); Verifikation gehört zu `server/`, nicht zu diesem Issue. Rechenlogik (Überstunden/Pausen) unverändert.

## Offene Fragen (mit Empfehlung)
1. Einfrieren: Option A (dokumentieren + Tests + Race-Fix) jetzt und Dialog (B) als separaten Folge-PR, oder B sofort im selben Zug? Empfehlung: A zuerst (PR 1), B als PR 2 nach Entscheidung zur UX-Parität mit dem Web.
2. Soll die in-flight-Race als **Bugfix** (Fehlerklasse „Datenverlust in B“, Label `bug`) in PR 1 gelöst werden, mit Semantik „alle Writes einer Aktion landen im Profil des Aktionsbeginns, nur Folgeschritte werden bei Überholung abgebrochen“ (wie Web)? Empfehlung: ja; die Alternative „komplett abbrechen“ würde A inkonsistent lassen (Saldo gespeichert, Eintrag nicht).
3. `deleteProfile(aktiv)`: Reihenfolge umstellen („zuerst auf Standard wechseln, dann API, bei Fehler zurück“, wie Web) in PR 1? Empfehlung: ja (kleiner Eingriff in `WorkProfileViewModel`, schließt das Autosave-Fenster, Test 10).
4. Bei Option B: `addProfile` mit Guard **vor** dem API-Aufruf (wie Web O1: bei „Abbrechen“ kein neues Profil)? Empfehlung: ja.
5. Bei Option B: `deleteProfile(aktiv)`, Logout und App-Neustart bleiben ohne Dialog (Einfrieren bzw. Eintrag ist ohnehin weg)? Empfehlung: ja.
6. Nebenbefund Stop-Pfad (Exception aus `saveOvertime` nach `_timer.cancel()`) separat als Issue oder in PR 2 mitnehmen? Empfehlung: in PR 2 (wird dort für Rollback ohnehin benötigt); bei Option A nur als Folge-Issue melden, vorher per Test bestätigen.
7. Parallelbetrieb (A eingefroren und laufend, B startet eigenen Timer) und offene Einträge bei vergessenem Profil: als bekannte Grenze akzeptieren und dokumentieren? Empfehlung: ja, ohne Auto-Stop.
8. Bei Option B: Guard-Abfrage „läuft ein Timer?“ über `ref.read(dashboardViewModelProvider)` (instanziiert das VM, falls noch nicht geschehen) oder nur, wenn es bereits existiert? Empfehlung: lesen und bei `isLoading` kein Dialog (wie Web), da das VM beim Start der Home-Shell ohnehin gebaut wird; im Plan per Widget-Test mit Settings-Tab als Startseite absichern.
9. Testharness: `Harness` um optionalen Profil-Modus erweitern (empfohlen, wiederverwendbar für #388-Folgetests) oder eigene Datei `dashboard_profile_harness.dart`? Empfehlung: Erweiterung von `dashboard_harness.dart` mit optionalem Parameter, bestehende Szenarien unverändert.

## Risiken
- Die Race-Behebung berührt den zentralen Schreibpfad (`_recalculateStateAndSave`, von allen Aktionen und #379-Tests genutzt): alle bestehenden VM-Tests (`dashboard_view_model*_test.dart`, `day_change`) müssen unverändert grün bleiben.
- Bereits verfälschte Daten (A-Eintrag in B, A-Saldo bei abweichendem Eintrag) werden nicht repariert; Hinweis für PR/Release Notes wie im Web.
- Einfrieren bleibt Nutzer-sichtbar riskant (Zeit von B zählt in A, offene Einträge); ohne Option B bleibt das ein dokumentiertes Verhalten, kein Fix.
- Riverpod-Verhalten (`ref.mounted` bleibt über Rebuild `true`, `onDispose` läuft bei Invalidierung, nicht beim Rebuild) ist Version-3.0.3-spezifisch; Tests sollten es indirekt mitprüfen (Rebuild per Profilwechsel), damit ein Riverpod-Update es nicht unbemerkt ändert.
- Tests mit `fakeAsync` und Scheduler-Task (`async.elapse(Duration.zero)` nach dem Wechsel) sind empfindlich gegen vergessenes Elapsen; im Harness kapseln (`switchProfile(id)`-Helper).

## Entscheidungen zu den offenen Fragen (Hauptsession)

1. Option A zuerst als PR 1 (Race-Fix + Profil-Tests + Doku, `Refs #388`). Option B (Dialog) danach als PR 2 (`Closes #388`), Entscheidung dazu nach PR 1 (UX-Parität zum Web).
2. Race als Bugfix in PR 1: Alle Writes einer Aktion landen im Profil des Aktionsbeginns, nur Folgeschritte werden abgebrochen (wie Web). Reihenfolge Saldo/Eintrag beibehalten, aber mit Profil-/Generationsprüfung (nicht stillschweigend verteilen).
3. `deleteProfile(aktiv)`: zuerst ins Standard-Profil wechseln, dann API, bei Fehler zurück (wie Web), in PR 1.
4. (PR 2) `addProfile` mit Guard vor dem API-Aufruf (wie Web O1).
5. (PR 2) `deleteProfile(aktiv)`, Logout, App-Neustart ohne Dialog.
6. Nebenbefund Stop-Pfad (`_timer` vor `saveOvertime` abgebrochen, Exception nicht gefangen): in PR 1 per Test bestätigen; behoben wird er in PR 2, sonst als Folge-Issue (Hauptsession legt es an).
7. Parallelbetrieb (A eingefroren, B läuft) und offene Einträge bei vergessenem Profil als bekannte Grenze dokumentieren, kein Auto-Stop.
8. (PR 2) Guard liest das Dashboard-VM per `ref.read`; bei `isLoading` kein Dialog.
9. `Harness` um einen optionalen Profil-Modus erweitern (kein neues Harness).
