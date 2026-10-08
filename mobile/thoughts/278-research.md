# Mobile-Research: #278 — Urlaubskontingent / Resturlaub
Datum: 2026-10-03

Verbindlich: `thoughts/278-coordination.md` (Vertrag, Entscheidungen). Backend (#359) und Web (#360) sind in `develop`. Issue hat keine Kommentare.

## Aufgabe
Mobile-Teil (PR 3): Nutzer pflegt einen Jahres-Urlaubsanspruch (ganze Tage, 0-366, Default 30, je Arbeitszeit-Profil). Resturlaub = Anspruch - Anzahl `vacation`-Einträge im Kalenderjahr (auch Wochenende, `holiday` zählt nicht, nie auf 0 geklemmt, kein Übertrag). Kranktage = Anzahl `sick`-Einträge. Free-Feature.

Akzeptanzkriterien Mobile:
- Einstellungsfeld "Urlaubsanspruch pro Jahr" (Default 30, Validierung 0-366).
- Rest lokal berechnet (offline), identisch zu Backend `ReportCalculator.CalculateYearlyLeave`.
- Anzeige Rest in Settings und Dashboard; Reports zeigen Kranktage und Urlaub genommen/Rest.
- Jahreswechsel setzt von selbst zurück (nur Jahr Y wird gezählt).
- Sync des Anspruchs über Firestore/API, ohne Werte alter Clients zu überschreiben.

Nicht Teil: Übertrag, anteilige Berechnung, Halbtage, Anspruch pro Vorjahr, Migration des anonymen Anspruchs, neue Endpunkte.

## Betroffene Dateien
| Datei | Warum |
|---|---|
| `lib/domain/entities/settings_entity.dart` | Feld `vacationDaysPerYear` (Default 30). Achtung: es gibt `copyWith`, `copyWithBundesland`, `copyWithTimezoneOverride` (jeweils vollständiger Konstruktoraufruf) plus `props`: das Feld muss in **allen vier** Stellen ergänzt werden, sonst geht es bei Bundesland-/Zeitzonen-Änderung auf 30 zurück. |
| `lib/domain/repositories/settings_repository.dart` | `int getVacationDaysPerYear()` / `Future<void> setVacationDaysPerYear(int)` |
| `lib/data/repositories/settings_repository_impl.dart` | Pref-Key `vacation_days_per_year_$_userId$_profileSuffix` (neben `_targetHoursKey`/`_workdaysKey`), Getter (Default 30, defensiv clamp/Typ), Setter + `_syncToFirestore({'vacationDaysPerYear': n})`, `syncFromFirestore()` um Feld erweitern |
| `lib/presentation/view_models/settings_view_model.dart` | `NoOpSettingsRepository` (implementiert Interface, muss neue Methoden bekommen), `_init()` (Wert lesen, in `SettingsEntity`), `updateVacationDaysPerYear(int)` (Muster `updateWeeklyTargetHours`, plus Leave-Provider invalidieren) |
| `lib/presentation/state/settings_state.dart` | vermutlich unverändert (hält `SettingsEntity`), prüfen |
| `lib/data/datasources/remote/api_data_source.dart` (`saveSettings`) / `api_client.dart` | keine Änderung nötig: Read-Modify-Write `{...current, ...neu}`, GET liefert `vacationDaysPerYear` seit #359 und wird durchgereicht. Nur Test ergänzen. |
| `lib/domain/utils/leave_balance_utils.dart` (neu) | reine Funktion + Wertklasse, z. B. `LeaveBalance {year, entitlement, taken, remaining, sickDays}` und `calculateLeaveBalance(entries, year, entitlement)` bzw. aus `List<MonthSummary>` |
| `lib/domain/utils/yearly_report_utils.dart` | Quelle der Zählung (`MonthSummary.vacationDays/sickDays`, `switch (entry.type)`), bleibt unverändert |
| `lib/presentation/state/yearly_report_state.dart` | optional Getter für Rest/Anspruch; `totalVacationDays/totalSickDays` existieren |
| `lib/presentation/view_models/leave_balance_view_model.dart` (neu, manueller `NotifierProvider`) | lädt 12 Monate des laufenden Jahres über `workRepositoryProvider.getWorkEntriesForMonth` (Hybrid-Layer, offline/ausgeloggt via Local) + Anspruch aus `settingsRepositoryProvider`; Free, ohne Premium-/Login-Gate |
| `lib/presentation/widgets/leave_balance_card.dart` (neu) | wiederverwendbare Karte für Dashboard und Settings (Rest "18 von 30 Tagen", Überschreitung als Text + Farbe, Anspruch 0, Kranktage) |
| `lib/presentation/widgets/edit_vacation_days_modal.dart` (neu) | Bottom-Sheet analog `edit_target_hours_modal.dart` (TextFormField, `digitsOnly`, Validator 0-366) |
| `lib/presentation/screens/settings_page.dart` | `ListTile` "Urlaubsanspruch pro Jahr" in `leftColumnChildren` (nach Arbeitstage, ca. Z. 90) plus Resturlaub-Karte |
| `lib/presentation/screens/dashboard_screen.dart` | Karte in/unter `overtimeStats` (Z. ~120, `isWide` Zwei-Spalten-Layout beachten) |
| `lib/presentation/screens/reports_page.dart` | Jahresreport (`_YearlyReportViewState`, Z. 1366-1560): Zeilen "Urlaubsanspruch/Resturlaub" ergänzen. Siehe Frage 1 zu Premium. |
| `lib/presentation/view_models/reports_view_model.dart` (`saveWorkEntry` Z. 148, `deleteWorkEntry` Z. 163, Batch Z. ~539) | Invalidierungspunkte für den Leave-Provider |
| `lib/l10n/app_de.arb`, `app_en.arb` | neue Keys (siehe unten), danach `flutter gen-l10n` |
| `test/...` | `domain/utils/leave_balance_utils_test.dart`, Repo-Test (Key mit Profil-Suffix, Default, Sync), ViewModel-/Widget-Tests, `api_data_source_test` (Feld wird durchgereicht) |
| Mocks (`*.mocks.dart`): `dashboard_view_model_test`, `theme_view_model_test`, `reports_view_model_test`, `yearly_report_view_model_test` | mocken `SettingsRepository`: nach Interface-Änderung per `build_runner` neu generieren (nicht editieren) |

## Ist-Zustand
- Anspruch/Rest existieren nicht. Zählung je Monat ist vorhanden (`calculateMonthSummary`, jeder Eintrag = 1 Tag, `vacation`/`sick`/`holiday` getrennt) und deckt sich mit Backend-Regel 2.3 (Wochenende zählt, `holiday` nicht, ein Eintrag je Tag über Id `yyyy-MM-dd`, daher keine Doppelzählung). Es fehlt Anspruch, Rest, Jahres-Ladepfad ohne Premium.
- `SettingsEntity.copyWith` kennt `bundesland`/`timezoneOverride` bewusst nicht (eigene `copyWith*`-Methoden). Neues Feld in alle Varianten.
- Jahresreport ist **Login- und Premium-gated** (`loginRequiredYearly`, `PremiumBlurGate`; Weekly/Monthly ebenso). `YearlyReportViewModel.loadYear` lädt 12 Monate parallel + optionale API-Verfeinerung der Überstunden (hier irrelevant). Wiederverwendbar, aber nicht als Free-Quelle, weil `_loadIfNeeded` nur im gated Zweig läuft und das ViewModel zusätzlich API-Aufrufe macht. Für den Free-Rest daher ein eigener schlanker Loader, der nur `getWorkEntriesForMonth` + `calculateMonthSummary`/Zählfunktion nutzt.
- `syncFromFirestore()` liest nur `weeklyTargetHours` und `workdays`. Der Aufruf in `settingsRepositoryProvider` ist fire-and-forget (nicht awaited, `if (userId != null)`), `SettingsViewModel` lädt nicht neu: bestehendes Verhalten, ein vom Web gesetzter Anspruch erscheint nach Neuaufbau des Providers/App-Neustart (gleiches Verhalten wie Soll-Stunden).
- Anonym (`userId == 'local'`): Pref-Key `..._local`, kein Sync. DataSync beim Login (`DataSyncService`) migriert nur Einträge und Gleitzeit, **keine** Einstellungen (auch `weeklyTargetHours` nicht). Anspruch bleibt wie Soll-Stunden unmigriert.
- Settings-Schreiben: `saveSettings` = GET (voller Server-Stand inkl. `vacationDaysPerYear`) + Merge + PUT. Backend `SaveAsync` nutzt `MergeFields` und ignoriert `null`. Ein alter Mobile-Client reicht das gelesene Feld einfach durch, überschreibt nichts. Ein neuer Client sendet das Feld immer (aus GET), schreibt bei Nie-gesetzt nur 30 (= effektiver Default). Der Wert 0-366 wird vom Backend validiert (400 sonst, `_syncToFirestore` loggt nur `logger.w`, lokaler Wert bleibt: Client-Validierung ist Pflicht).

## Datenfluss
Settings: `SettingsPage` -> `EditVacationDaysModal` -> `SettingsViewModel.updateVacationDaysPerYear` -> `SettingsRepositoryImpl.setVacationDaysPerYear` -> SharedPreferences + `_syncToFirestore` -> `ApiDataSource.saveSettings` (GET+PUT) -> Backend -> `users/{uid}[/profiles/{id}]/settings/current.vacationDaysPerYear`. Zurück beim Login/Provider-Aufbau: `syncFromFirestore` -> Pref.

Rest: `DashboardScreen`/`SettingsPage`/Jahresreport -> `leaveBalanceViewModelProvider` -> `workRepositoryProvider` (Hybrid: Api bzw. Local, je Profil) `getWorkEntriesForMonth` x12 + `settingsRepository.getVacationDaysPerYear()` -> `calculateLeaveBalance` (domain/utils) -> `LeaveBalanceCard`.

Invalidierung: Eintrag speichern/löschen/Batch (`ReportsViewModel`), Anspruch ändern, Profilwechsel (`activeWorkProfileIdProvider` ist im Hybrid-Repo-Watch, Provider hängt über `ref.watch(workRepositoryProvider)` automatisch dran, wie `YearlyReportViewModel.build`), Login/Logout (ebenso). Dashboard speichert nur `type: work` (Timer), braucht keine Invalidierung.

## Rechenregel / Paritätstests
Funktion rein, Jahr als Parameter (kein `DateTime.now()` in der Funktion, Tests datumsunabhängig). Gleiche Fälle wie `ReportCalculatorTests.YearlyLeave_*` (Backend) und `leave-calculator.spec.ts` (Web):
1. vacation 2x, sick 1x, holiday 1x, work 1x, Anspruch 30 -> taken 2, remaining 28, sick 1.
2. Jahresgrenze: 31.12.2025 und 01.01.2026 vacation, 31.12.2026 sick, 01.01.2027 sick, Jahr 2026 -> taken 1, sick 1.
3. Samstag 2026-06-06 vacation zählt.
4. Anspruch 3, 5 vacation -> remaining -2 (nicht geklemmt).
5. Kein Eintrag, Anspruch 0 -> 0/0/0. Fehlender Anspruch -> Default 30 (Repo-Test: Getter ohne Key = 30).
Zählung kann aus `MonthSummary` (Summe `vacationDays`) oder direkt aus Einträgen kommen. Empfehlung: Funktion nimmt `List<WorkEntryEntity>` des Jahres (filtert `date.year == year`, eine Quelle der Wahrheit, 1:1 wie Backend/Web) und der Loader ruft sie mit den zusammengeführten Monatslisten auf. `YearlyReportState`-Getter bleiben unberührt.

## UI-States
| State | Lösung |
|---|---|
| loading | `LoadingIndicator`/kleiner Spinner in der Karte, Vorwert stehen lassen |
| data Rest >= 0 | "18 von 30 Tagen", Fortschrittsbalken, Zeilen Genommen/Anspruch/Kranktage |
| Rest < 0 | negativer Wert, Text "N Tage über dem Anspruch" (nicht nur Farbe), Balken voll |
| Anspruch 0 | Rest = -genommen, Hinweis + Link zu Einstellung, Balken ausblenden |
| empty | "0 von 30 Tagen" (Rest bleibt sinnvoll) |
| error | Inline-Fehler mit Retry, kein stilles 0/30 (`logger.e` an Crashlytics) |
| premium-locked | **entfällt** für Karte (Free). Nur der bestehende Jahresreport bleibt gated. |
| ausgeloggt | funktioniert lokal (Hybrid Local), kein Login-Gate |

## Texte (ARB; DE duzen, EN mit; vorhandene Keys `vacationDaysLabel`="Urlaubstage:" / `sickDaysLabel`="Krankheitstage:" wiederverwenden wo "Doppelpunkt-Label" passt)
Neu, jeweils mit `@key`-Beschreibung in `app_de.arb`: `vacationEntitlementTitle` (Urlaubsanspruch pro Jahr), `vacationEntitlementValue` ({days} Tage), `editVacationEntitlementTitle`, `vacationEntitlementFieldLabel` (Tage pro Jahr), `vacationEntitlementHint` ("In ganzen Tagen (0-366)"), `vacationEntitlementInvalid` ("Bitte gib eine ganze Zahl von 0 bis 366 ein."), `remainingVacationTitle` (Resturlaub), `remainingVacationOf` ({remaining} von {total} Tagen), `vacationTakenLabel` (Genommen), `vacationEntitlementLabel` (Anspruch), `vacationOverEntitlement` (ICU-Plural: "{days, plural, =1{1 Tag über dem Anspruch} other{{days} Tage über dem Anspruch}}"), `sickDaysYearLabel` ("Kranktage {year}"), `leaveLoadError`, `leaveRetry`, `vacationEntitlementZero`, `leavePastYearNote` (Resturlaub nur fürs laufende Jahr). Es gibt im Projekt noch keinen ICU-Plural in der ARB: erste Nutzung, `flutter gen-l10n` und `intl`-Version prüfen (Web-Texte unter `web/public/i18n/de.json`, Block `leave.*`, als Textvorlage; Web nutzt zwei Keys One/Other, Flutter kann nativ plural).

## Plattformübergreifend
Nur Mobile. Backend/Web fertig. Keine Firestore-Rule-Änderung (`settings/{doc}` abgedeckt). Parität: Web zeigt Rest im laufenden Jahr, Vorjahre nur Genommen + Kranktage (Entscheidung 3), Mobile gleich. Web-Referenz: `web/src/app/domain/services/leave-calculator.ts`, `leave-balance-card.html`, i18n `leave.*`/`settings.vacationDays*`. Unterschied: Web hat eigenen freien 4. Reports-Tab "Jahr" (nicht gated, auch anonym lokal); Mobile-Jahresreport ist Premium + Login.

## Technik
- `build_runner`: **neue @riverpod-Provider sind nicht nötig** (ViewModel manuell per `NotifierProvider`, Regel in `mobile/CLAUDE.md`; Repo/Provider-Verdrahtung unverändert, `settingsRepositoryProvider` bleibt). Nötig aber für die Mockito-`*.mocks.dart` (SettingsRepository-Interface wächst) und `flutter gen-l10n` für ARB.
- Alle Tests mit festem Datum/Jahr; `now` nicht in der Funktion. Loader nimmt Jahr als Parameter, Default aus injizierbarer Quelle.
- Fehler an Crashlytics via `logger.e`.

## Risiken
- **Premium-Falle**: Karte nicht in `YearlyReportView` (gated) einhängen. Acceptance "Kranktage in den Reports" kollidiert sonst mit "Free" (Frage 1).
- **Unvollständige copyWith-Varianten** setzen Anspruch stillschweigend zurück (siehe Entity).
- **Settings-Sync alter Clients**: unkritisch (Backend Nullable-Merge, alter Mobile-Client reicht GET-Wert durch). Kritisch dagegen: ein Mobile-Client, der vor dem ersten `syncFromFirestore` speichert (Pref hat Default 30, Server z. B. 25) - `saveSettings` liest aber den Serverstand (GET) und schreibt nur das geänderte Feld, daher nur beim Ändern des Anspruchs selbst relevant. Gleiches Stale-Risiko wie Soll-Stunden.
- **Stale Anzeige nach Sync**: `syncFromFirestore` ist nicht awaited, `SettingsViewModel._init` kann den alten Pref lesen. Ein im Web geänderter Anspruch erscheint ggf. erst nach Neustart. Optional: nach `syncFromFirestore` Leave-/Settings-State invalidieren (nur Hinweis, bestehendes Muster).
- **Veraltete Zahl nach Eintragsänderung**: jeder Schreibpfad (Reports save/delete/Batch, Edit-Modal läuft über `ReportsViewModel`) muss den Leave-Provider invalidieren. Größtes Funktionsrisiko.
- **Datenmenge**: 12 Monatsabfragen je Laden (Dashboard + Settings). Ein geteilter Provider (kein autoDispose-Dopplung), nur laufendes Jahr, Laden einmalig + Invalidierung.
- **Jahreswechsel bei offener App**: Jahr beim Laden aus `DateTime.now()`; offene App ohne Neuladen zeigt altes Jahr. Beim Wiederaufnehmen/Invalidierung neu bestimmen (Test mit festem Jahr).
- **Eingabevalidierung** (Dezimal/negativ/>366/leer): Backend lehnt per 400 ab, `_syncToFirestore` verschluckt Fehler, lokaler Wert wäre inkonsistent. Client-Validierung strikt, ganze Zahl, kein stilles Runden.
- **Anonym -> Login**: Anspruch (und Soll-Stunden) werden nicht migriert, Wert fällt auf Server-Wert/30. Konsistent zu bestehendem Verhalten; Web migriert dagegen den Anspruch (Web-Entscheidung 4).
- **Pro Profil**: Pref-Key mit `_profileSuffix`, Zählung über Profil-Einträge (Hybrid-Repo bekommt `profileId` schon). Profilwechsel muss Leave-Provider neu laden.
- **ICU-Plural** erstmals in ARB: Generatorverhalten testen (de/en `gen-l10n`).
- Layout: Dashboard Zwei-Spalten (`isWide`) und `ResponsiveCenter`; Karte darf Timer-/Überstunden-Bereich nicht verdrängen; kleines Display.

## Offene Fragen (mit Empfehlung)
1. **Premium-Gate Reports/Kranktage**: Jahresreport ist Login+Premium-gated, #278 ist Free. Wo sieht ein Free-Nutzer "Kranktage" und "Urlaub genommen/Rest in Reports"? Empfehlung: Free-Karte "Urlaub & Krank {Jahr}" (Rest, Genommen, Anspruch, Kranktage) in Settings und Dashboard (wie Vertrag), Reports-Premium-Jahresreport bekommt zusätzlich Zeilen Anspruch/Rest. Kein neuer freier Reports-Tab. Kranktage für Free sind damit in der Karte sichtbar (Reports-Kriterium erfüllt für Premium, für Free über Karte). Alternative: Karte oben im Daily-Tab (Free) - mehr Scope, nur wenn gewünscht.
2. **Dashboard-Platzierung**: Karte unter `overtimeStats` (Hauptspalte) als kompakte Zeile "Resturlaub 18/30" mit Tap zur Detailansicht, oder volle Karte. Empfehlung: kompakte Karte unter den Überstunden, Detail (Genommen/Anspruch/Kranktage) nur in Settings.
3. **Anonyme Nutzer**: Karte auch ausgeloggt (lokal)? Empfehlung: ja (Free, Hybrid), ohne Login-Hinweis.
4. **Anspruch aus anonymem Modus beim Login migrieren**: Soll-Stunden/Arbeitstage werden auch nicht migriert. Empfehlung: nicht (Parität zu bestehendem Mobile-Verhalten), in PR-Beschreibung vermerken. Web migriert; Abweichung dokumentieren.
5. **Invalidierung**: expliziter `ref.invalidate(leaveBalanceViewModelProvider)` in `ReportsViewModel.saveWorkEntry/deleteWorkEntry/Batch` (kleinster Eingriff) statt neuem Stream im Hybrid-Repo. Empfehlung: explizit.
6. **`syncFromFirestore` nicht awaited**: nur Anspruch aufnehmen (Stale-Hinweis akzeptieren) oder zusätzlich State nachziehen? Empfehlung: nur Feld aufnehmen, Verhalten wie Soll-Stunden, kein Umbau.
7. **Plural**: ICU-`plural` in ARB (erste Nutzung) oder zwei Keys wie Web? Empfehlung: ICU-Plural, nativer Flutter-Weg, mit Test für 1 und >1.
8. **Anspruch-Eingabe**: Bottom-Sheet-Modal (wie Soll-Stunden) mit Validierung 0-366, ganze Zahl. Empfehlung ja.
9. **Rest in Vorjahren** im Premium-Jahresreport: Vorjahre nur Genommen/Kranktage (Entscheidung 3). Empfehlung: Rest/Anspruch-Zeilen nur wenn `year == aktuelles Jahr`, sonst Hinweis `leavePastYearNote`.

## Entscheidungen zu den offenen Fragen (Hauptsession)

Alle Empfehlungen übernommen: (1) Free-Karte (Rest, Genommen, Anspruch, Kranktage) in Settings und Dashboard, im Premium-Jahresreport zusätzlich Zeilen Anspruch/Rest, kein neuer freier Reports-Tab; (2) Dashboard: kompakte Karte unter den Überstunden (Rest „n von m Tagen"), Detail in Settings; (3) Karte auch für ausgeloggte Nutzer (lokal); (4) Anspruch aus dem anonymen Modus wird beim Login nicht migriert (wie Soll-Stunden), als Abweichung zum Web in der PR-Beschreibung vermerken; (5) explizites `ref.invalidate` in `ReportsViewModel` (save/delete/batch); (6) `syncFromFirestore` nur um das Feld erweitern, kein Umbau; (7) ICU-Plural in der ARB (de + en); (8) Anspruch-Eingabe als Bottom-Sheet wie bei den Soll-Stunden, ganze Zahl 0–366, clientseitig validiert; (9) Rest/Anspruch im Jahresreport nur fürs laufende Jahr, Vorjahre Genommen/Kranktage plus Hinweistext. `SettingsEntity`: Feld in `copyWith`, `copyWithBundesland`, `copyWithTimezoneOverride` und `props` aufnehmen; Mocks per build_runner neu generieren.
