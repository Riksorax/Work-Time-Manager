# Mobile-Plan: #278 — Urlaubskontingent / Resturlaub
Research: mobile/thoughts/278-research.md (inkl. Entscheidungen), Vertrag: thoughts/278-coordination.md

## Ziel
Nutzer pflegt je Arbeitszeit-Profil einen Jahres-Urlaubsanspruch (ganze Tage 0-366, Default 30); die App berechnet offline den Resturlaub (Anspruch minus `vacation`-Einträge im Kalenderjahr, nie geklemmt) und zeigt ihn als Free-Karte in Settings und Dashboard, im Premium-Jahresreport zusätzlich Anspruch/Rest. Regel identisch zu Backend `CalculateYearlyLeave`.

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Neue Entity / Feld? | `SettingsEntity.vacationDaysPerYear` (Default 30) in Konstruktor, `copyWith`, `copyWithBundesland`, `copyWithTimezoneOverride`, `props`. Neue Wertklasse `LeaveBalance` in `domain/utils/leave_balance_utils.dart` | Sonst fällt Wert bei Bundesland-/Zeitzonenwechsel auf 30 zurück |
| Repository-Interface ändern? | Ja: `SettingsRepository.getVacationDaysPerYear()` / `setVacationDaysPerYear(int)`. Nur `SettingsRepositoryImpl` + `NoOpSettingsRepository` implementieren es (kein Hybrid/Firebase/Local-Split bei Settings). `ApiDataSource.saveSettings` unverändert (Read-Modify-Write reicht Feld durch), nur Test | Settings liegen in SharedPreferences + API-Sync |
| Neuer Provider? | `leaveBalanceViewModelProvider` als manueller `NotifierProvider` neben seinem Notifier. Kein `@riverpod`, `providers.dart` unverändert | Regel in `mobile/CLAUDE.md`; build_runner nur für Mockito-Mocks |
| Premium-Gate? | Keines. Karte nicht in `YearlyReportView` einhängen; dort nur zusätzliche Zeilen im bereits gated Block (nur laufendes Jahr) | Free-Feature; Jahresreport bleibt Login+Premium |
| Pro Arbeitszeit-Profil? | Pref-Key `vacation_days_per_year_$_userId$_profileSuffix`; Zählung über `workRepositoryProvider` (Hybrid, bekommt `profileId`); Provider watcht `workRepositoryProvider` und damit Profil-/Login-Wechsel | Parität zu `workdays_...` |
| Backend-Änderung nötig? | Nein, #359 ist in `develop`. Mobile rechnet lokal, nutzt `GET /reports/yearly` nicht | Offline-Fähigkeit |
| Neue Texte? | Ja, ARB de (duzen) + en, ICU-Plural erstmals, `flutter gen-l10n` | siehe Schritt 5 |

Abweichend vom Naheliegenden: Funktion nimmt `List<WorkEntryEntity>` (nicht `MonthSummary`) und filtert selbst auf `date.year == year`; Jahr/`now` immer Parameter; expliziter `ref.invalidate` statt Repo-Stream; Anspruch wird beim Login nicht migriert (PR-Text: Abweichung zum Web); `syncFromFirestore` nur um das Feld erweitert, bekannte Stale-Anzeige bis Neustart akzeptiert.

## Dateien
| Datei | neu/geändert | Zweck |
|---|---|---|
| `lib/domain/utils/leave_balance_utils.dart` | neu | `LeaveBalance{year, entitlement, taken, remaining, sickDays}`, `calculateLeaveBalance(entries, year, entitlement)`, Konstanten `defaultVacationDaysPerYear=30`, `maxVacationDaysPerYear=366` |
| `lib/domain/entities/settings_entity.dart` | geändert | Feld in 4 Stellen |
| `lib/domain/repositories/settings_repository.dart` | geändert | Getter/Setter |
| `lib/data/repositories/settings_repository_impl.dart` | geändert | Pref-Key, Getter (Default 30, defensiv), Setter + `_syncToFirestore`, `syncFromFirestore` |
| `lib/presentation/view_models/settings_view_model.dart` | geändert | `NoOpSettingsRepository`, `_init`, `updateVacationDaysPerYear` (+ invalidate Leave) |
| `lib/presentation/view_models/leave_balance_view_model.dart` | neu | manueller `NotifierProvider`, State loading/data/error |
| `lib/presentation/state/leave_balance_state.dart` | neu | State-Klasse (oder `AsyncValue<LeaveBalance>` falls im Projekt üblich; beim Impl nach bestehendem Muster entscheiden) |
| `lib/presentation/widgets/leave_balance_card.dart` | neu | Karte, Variante `compact` (Dashboard) und `detailed` (Settings) |
| `lib/presentation/widgets/edit_vacation_days_modal.dart` | neu | Bottom-Sheet analog `edit_target_hours_modal.dart` |
| `lib/presentation/screens/settings_page.dart` | geändert | ListTile Anspruch (nach Arbeitstage) + Detailkarte |
| `lib/presentation/screens/dashboard_screen.dart` | geändert | kompakte Karte unter `overtimeStats` (`isWide` beachten) |
| `lib/presentation/screens/reports_page.dart` | geändert | Jahresreport: Zeilen Anspruch/Rest nur für laufendes Jahr, sonst Hinweis |
| `lib/presentation/view_models/reports_view_model.dart` | geändert | `ref.invalidate(leaveBalanceViewModelProvider)` in save/delete/Batch |
| `lib/l10n/app_de.arb`, `app_en.arb` | geändert | Keys; generierte `app_localizations*.dart` per gen-l10n |
| `test/domain/utils/leave_balance_utils_test.dart` | neu | Parität |
| `test/domain/entities/settings_entity_test.dart` | neu | copyWith-Varianten, props |
| `test/data/repositories/settings_repository_impl_test.dart` | neu (falls nicht vorhanden) | Key, Default, Sync |
| `test/data/datasources/remote/api_data_source_test.dart` | geändert | Feld wird durchgereicht |
| `test/presentation/view_models/leave_balance_view_model_test.dart`, `settings_view_model_test.dart`, `reports_view_model_test.dart` | neu/geändert | |
| `test/presentation/widgets/leave_balance_card_test.dart`, `edit_vacation_days_modal_test.dart`, `test/presentation/screens/settings_page_test.dart` | neu/geändert | |
| `*.mocks.dart` (dashboard-, theme-, reports-, yearly_report-VM-Tests) | regeneriert | build_runner, nicht editieren |

## Schritte (TDD)

### Schritt 1: Domain
- [x] Test `test/domain/utils/leave_balance_utils_test.dart` (feste Daten, Jahr als Parameter, kein `DateTime.now()`), Fixtures wie Backend `ReportCalculatorTests.YearlyLeave_*` / Web `leave-calculator.spec.ts`:
  1. vacation 2x, sick 1x, holiday 1x, work 1x, Anspruch 30 -> taken 2, remaining 28, sick 1
  2. Jahreswechsel: 31.12.2025 + 01.01.2026 vacation, 31.12.2026 + 01.01.2027 sick, Jahr 2026 -> taken 1 (01.01.2026), sick 1 (31.12.2026); zusätzlich Jahr 2025 -> taken 1
  3. Samstag 2026-06-06 vacation zählt
  4. Anspruch 3, 5 vacation -> remaining -2
  5. leer + Anspruch 0 -> 0/0/0; leer + 30 -> remaining 30
  6. `holiday` nie in taken; Einträge anderer Jahre ignoriert
- [x] Test `settings_entity_test.dart`: Default 30; `copyWith(vacationDaysPerYear: 25)` ändert nur das Feld; `copyWithBundesland` und `copyWithTimezoneOverride` erhalten 25; `props` unterscheidet 25 und 30 (Equality).
- [x] Impl `leave_balance_utils.dart` (rein, ohne Flutter-Import), `SettingsEntity` (alle vier Stellen), Interface `SettingsRepository`.

### Schritt 2: Data
- [x] Test `settings_repository_impl_test.dart` (`SharedPreferences.setMockInitialValues`, Mock `ApiDataSource` via `@GenerateMocks`): Getter ohne Key = 30; Setter schreibt Key `vacation_days_per_year_<uid>_<profileSuffix>`; Profil A/B getrennt; anonym `_local`, kein API-Aufruf; eingeloggt ruft `saveSettings({'vacationDaysPerYear': n})`; API-Fehler -> lokaler Wert bleibt, kein Throw; Getter clamped/defensiv bei Fremdtyp bzw. außerhalb 0-366 -> 30; `syncFromFirestore` übernimmt `vacationDaysPerYear`, ignoriert fehlendes/ungültiges Feld (Pref unverändert).
- [x] Test `api_data_source_test.dart`: `saveSettings` mergt Server-GET inkl. `vacationDaysPerYear` mit Änderung (Feld bleibt bei Änderung anderer Felder erhalten).
- [x] Impl in `settings_repository_impl.dart`. Keine Änderung an Hybrid/Firebase/Local-Work-Repos.

### Schritt 3: Provider / Presentation-Logik
- [x] Test `leave_balance_view_model_test.dart` (`ProviderContainer`, Overrides für `workRepositoryProvider` und `settingsRepositoryProvider` mit Mocks; Jahr über injizierbare Quelle/Clock-Provider, fester Wert 2026): lädt 12 Monate via `getWorkEntriesForMonth` (12 Aufrufe, Jahr 2026), Rest korrekt; Anspruch aus Repo; Fehler -> error-State + kein stilles 0/30; `ref.invalidate` lädt neu; Jahreswechsel (Clock 2026 -> 2027) bestimmt Jahr beim Neuladen neu; kein Premium-/Login-Gate (ausgeloggt/Local funktioniert).
- [x] Test `settings_view_model_test.dart`: `_init` liest Anspruch in `SettingsEntity`; `updateVacationDaysPerYear(25)` ruft Repo-Setter, aktualisiert State, invalidiert Leave-Provider; Bundesland-/Zeitzonenwechsel behält Anspruch; Wert außerhalb 0-366 wird nicht gespeichert (Guard).
- [x] Test `reports_view_model_test.dart`: `saveWorkEntry`, `deleteWorkEntry` und Batch invalidieren `leaveBalanceViewModelProvider` (Zähler am Override-Notifier/`build`-Aufrufe prüfen).
- [x] Impl: `leave_balance_view_model.dart` (+ State), `NoOpSettingsRepository` (Default 30 / no-op), `updateVacationDaysPerYear`, Invalidierung in `ReportsViewModel`.
- [x] `dart run build_runner build --delete-conflicting-outputs` (Mocks der Tests mit `SettingsRepository`; keine `@riverpod`-Änderung).

### Schritt 4: Presentation (UI)
- [x] Widget-Test `leave_balance_card_test.dart` (MaterialApp mit `AppLocalizations`-Delegates, `locale: Locale('de')`, Provider überschrieben mit festen States): data -> "18 von 30 Tagen", Genommen/Anspruch/Kranktage (detailed); Rest < 0 -> "2 Tage über dem Anspruch" als Text, Balken voll; "1 Tag über dem Anspruch" (Plural); Anspruch 0 -> Hinweistext, Balken ausgeblendet; leer -> "0 von 30 Tagen"; loading -> Spinner, Vorwert bleibt; error -> Fehlertext + Retry ruft Reload; compact zeigt nur Rest-Zeile; en-Locale prüft englische Texte.
- [x] Widget-Test `edit_vacation_days_modal_test.dart`: Vorbelegung; gültige Werte 0, 30, 366 speichern; 367, -1, 3.5, leer, Text -> `vacationEntitlementInvalid`, kein Speichern; digitsOnly.
- [x] Widget-Test `settings_page_test.dart` erweitern: ListTile "Urlaubsanspruch pro Jahr" mit Wert, Tap öffnet Modal, Speichern ruft `updateVacationDaysPerYear`; Karte sichtbar ohne Premium.
- [x] Dashboard-Test (sofern bestehender Screen-Test vorhanden, sonst schlanker neuer): kompakte Karte unter Überstunden, Layout schmal und `isWide`, ohne Login sichtbar.
- [x] Jahresreport-Test (`reports_page`-Test bzw. Widget-Test der `_YearlyReportView`-Zeilen): laufendes Jahr zeigt Anspruch/Rest, Vorjahr (fester Jahrgang, Clock-Parameter) zeigt Genommen/Kranktage + `leavePastYearNote`.
- [x] Impl: Card, Modal, Settings-Tile + Karte, Dashboard-Karte, Jahresreport-Zeilen. Karte im Free-Bereich, nicht im Premium-Gate; Tap auf Dashboard-Karte navigiert zu Settings-Tab/Detail (kleinster Eingriff, falls kein Navigationsmuster existiert: kein Tap).

### Schritt 5: Texte
- [x] Keys in `app_de.arb` (mit `@key`-Beschreibung, du-Form) und `app_en.arb`: `vacationEntitlementTitle`, `vacationEntitlementValue` ({days}), `editVacationEntitlementTitle`, `vacationEntitlementFieldLabel`, `vacationEntitlementHint`, `vacationEntitlementInvalid`, `remainingVacationTitle`, `remainingVacationOf` ({remaining},{total}), `vacationTakenLabel`, `vacationEntitlementLabel`, `vacationOverEntitlement` (ICU-Plural, `days` als `int`: `=1`/`other`), `sickDaysYearLabel` ({year}), `leaveLoadError`, `leaveRetry`, `vacationEntitlementZero`, `leavePastYearNote`. Vorhandene `vacationDaysLabel`/`sickDaysLabel` wiederverwenden wo passend.
- [x] `flutter gen-l10n`; prüfen, dass `intl`-Version und Generator Plural mit Placeholder-Typ `int` akzeptieren. Plural-Tests (1 und >1, de und en) stecken in den Widget-Tests aus Schritt 4. Reihenfolge praktisch: ARB-Keys vor den Widget-Tests anlegen, damit sie kompilieren.

## Validierung
- `dart format --set-exit-if-changed lib test`
- `flutter analyze --no-fatal-infos`, `dart run custom_lint`, `flutter test`
- Manuell (UI-Review): Dashboard schmal/breit, Settings, ausgeloggt, Profilwechsel, Eintrag speichern/löschen aktualisiert die Zahl.
- PR-Beschreibung: Abweichung zum Web (Anspruch beim Login nicht migriert), bekannte Stale-Anzeige nach `syncFromFirestore`, Refs #278 (Eltern-Issue erst nach diesem PR schließen).

## Umsetzungsnotizen (Implement-Phase)
- Pref-Key hat kein Trennzeichen vor dem Profil-Suffix: `vacation_days_per_year_<uid><suffix>` (Parität zu `workdays_...`).
- State: `LeaveBalanceState` (isLoading/hasError/balance, wie `YearlyReportState`); Jahr-Quelle `leaveBalanceNowProvider` (Clock-Provider, manuell).
- ICU-Plural (`vacationOverEntitlement`, `days` int) funktioniert mit gen-l10n/intl 0.20; keine zwei Keys nötig.
- Dashboard-Karte ohne Tap: HomeScreen-Tabindex ist lokaler State, kein Navigationsmuster.
- Jahresreport: `YearlyLeaveRows` (public, testbar) in `reports_page.dart`.
- `settings_page_test.dart`: Viewport 800x2400 gesetzt (lazy ListView), Leave-VM gefaket.
- Bekannt: `german_holidays_test.dart` schlägt mit TZ=Europe/Berlin fehl (unverändert, vorbestehend).
