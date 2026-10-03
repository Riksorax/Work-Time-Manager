# Mobile-Plan: #362 — Datumsarithmetik über die Zeitumstellung
Research: mobile/thoughts/362-research.md (inkl. „Entscheidungen zu den offenen Fragen")

## Ziel
`Duration(days: N)`-/`TZDateTime.add`-Arithmetik auf Kalendertage (`DateTime(y, m, d + N)`) umstellen, damit
Streak-Erkennung, Datumsbereich- und Wochennavigation in den Berichten und die Erinnerungsplanung über die
Zeitumstellung korrekt bleiben. Absicherung durch Tests mit festen Daten, die unter `TZ=Europe/Berlin` zuerst rot sind.

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Neue Entity / Feld? | Nein | Reine Rechenlogik |
| Repository-Interface ändern? | Nein | Hybrid-/Firebase-/Local-/ApiDataSource unberührt |
| Neuer Provider? | Nein, kein build_runner | Keine `@riverpod`-Änderung |
| Premium-Gate? | Nein | Kein Feature-Bezug |
| Pro Arbeitszeit-Profil? | Nein | Kein Datenzugriff betroffen |
| Backend-Änderung nötig? | Nein | Web/Backend laut Research sauber |
| Neue Texte? | Nein | Keine ARB-Keys |
| Gemeinsamer Helfer | Neue Datei `domain/utils/date_utils.dart` mit `addCalendarDays(DateTime, int)`, `datesInRange(DateTime start, DateTime end)` (normalisiert, ordnet min/max, liefert alle Kalendertage inklusive Endtag) und `shiftWeekStart(DateTime weekStart, int weeks)` (= `addCalendarDays(d, 7 * weeks)`, normalisiert auf Mitternacht) | Logik aus dem Widget extrahieren, damit sie unter dem vorhandenen Domain-TZ-Lauf getestet wird; Arbeitstag-Filter bleibt in `reports_page` (`_isWorkday`) |
| `german_holidays.dart` | Privates `_addDays` entfällt, nutzt `addCalendarDays` | Entscheidung 2; Verhalten identisch, bestehende Tests sichern ab |
| Notification | Reine Top-Level-Funktion `nextWeeklyOccurrence(tz.TZDateTime now, int day, int hour, int minute)` in `notification_service.dart`, `now` injiziert; Aufrufer übergibt `tz.TZDateTime.now(tz.local)`. Delta-Formel, kein `while`/`.add` | Entscheidung 6; Test setzt `tz.local` selbst auf Berlin, unabhängig von der Prozess-TZ |
| `selectDate` | Normalisiert am Eingang auf lokale Mitternacht | Entscheidung 3; Härtung |
| Wochenstart-Stellen (overtime_utils, reports_view_model, dashboard_view_model) | Auf `addCalendarDays(date, -(weekday-1))` / `+6` umstellen, ohne eigene Tests | Entscheidung 5; bestehende Tests sind der Regressionsschutz |
| CI | Option A: Schritt `ci.yml` Z. 51-52 durch `TZ=Europe/Berlin flutter test` (ganze Suite) ersetzen; normaler UTC-Lauf bleibt | Entscheidung 4, nur nach lokalem Nachweis (Schritt 6) |

## Dateien
| Datei | neu/geändert | Zweck |
|---|---|---|
| `mobile/lib/domain/utils/date_utils.dart` | neu | `addCalendarDays`, `datesInRange`, `shiftWeekStart` |
| `mobile/lib/domain/utils/german_holidays.dart` | geändert | `_addDays` -> `addCalendarDays` (Z. 28-39, 113, 140) |
| `mobile/lib/domain/utils/insights_utils.dart` | geändert | Streak-Schleife Z. 151-153 mit `addCalendarDays(day, 1)` |
| `mobile/lib/domain/utils/overtime_utils.dart` | geändert | Härtung Z. 44-45 |
| `mobile/lib/presentation/screens/reports_page.dart` | geändert | `_selectDateRange` nutzt `datesInRange`; Z. 716/744 `shiftWeekStart(startOfWeek, ∓1)`; Z. 699 `addCalendarDays(startOfWeek, 6)` |
| `mobile/lib/presentation/view_models/reports_view_model.dart` | geändert | `selectDate` (Z. 182) normalisiert; Härtung Z. 311-312 |
| `mobile/lib/presentation/view_models/dashboard_view_model.dart` | geändert | Härtung Z. 121 |
| `mobile/lib/core/services/notification_service.dart` | geändert | `nextWeeklyOccurrence` extrahieren, Z. 164-182 ersetzen |
| `.github/workflows/ci.yml` | geändert | Z. 51-52 auf volle Suite unter Berlin (bedingt) |
| `mobile/test/domain/utils/date_utils_test.dart` | neu | Helfer-Tests |
| `mobile/test/domain/utils/insights_utils_test.dart` | geändert | Streak-Fixtures um Umstellung |
| `mobile/test/presentation/view_models/reports_view_model_test.dart` | geändert (Datei prüfen, sonst neu) | `selectDate`-Normalisierung |
| `mobile/test/core/services/notification_service_test.dart` | geändert | Tests für `nextWeeklyOccurrence` |

## Schritte (TDD)
Arbeitsweise je Schritt: Test schreiben, unter `TZ=Europe/Berlin` laufen lassen und Rot bestätigen
(wo ein Fehler existiert), Fix, Grün; danach unter UTC (ohne `TZ`) Grün bestätigen. Fixtures nur feste Daten,
kein `DateTime.now()`. Pro Fundstelle ein eigener Commit (Entscheidung 1: ein PR).

### Schritt 1: Domain — Helfer
- [x] Test `test/domain/utils/date_utils_test.dart`:
  - `addCalendarDays`: 30.03.2025 +1 = 31.03.2025 00:00; 26.10.2025 +1 = 27.10.2025 00:00 (Herbst, vorher 23:00 am selben Tag);
    29.03.2025 +7 = 05.04.2025 00:00; 31.03.2025 −7 = 24.03.2025 00:00; 27.10.2025 −7 = 20.10.2025 00:00; Monats-/Jahreswechsel (31.12.2025 +1).
    Assertion über `hour == 0`, `minute == 0`, y/m/d.
  - `datesInRange`: 24.10.-28.10.2025 = 5 Tage inkl. 28.10., alle Mitternacht; 28.03.-01.04.2025 = 5 Tage inkl. 01.04.; vertauschte Reihenfolge liefert gleiches Ergebnis; Start = Ende = 1 Tag; Endtag = Umstellungstag 26.10. korrekt.
  - `shiftWeekStart`: Mo 20.10.2025 +1 = Mo 27.10.2025; Mo 31.03.2025 −1 = Mo 24.03.2025; Mo 24.03.2025 +1 = Mo 31.03.2025; Mo 27.10.2025 −1 = Mo 20.10.2025 (jeweils Mitternacht, `weekday == 1`).
  - Rot unter Berlin heißt hier: Datei fehlt; die Rot-Nachweise am bestehenden Verhalten erfolgen in den Schritten 2-4.
- [x] Impl `date_utils.dart`; `german_holidays.dart` auf den Helfer umstellen (`german_holidays_test.dart` bleibt grün).

### Schritt 2: Domain — `detectOvertimeStreak`
- [x] Test in `insights_utils_test.dart` (Fixtures aus Research; jeweils Mo-Fr 9 h bei Soll 8 h):
  - 24.03.-04.04.2025 (Frühjahr): currentStreak 10, longest 10 (vorher Berlin 0/5).
  - 20.10.-31.10.2025 (Herbst): 10/10; zusätzlich 22.-30.10.2025 mit allen 7 Wochentagen als Arbeitstag: 9/9 (Umstellungssonntag 26.10. wird nur einmal gezählt).
  - Optional 25.03.-05.04.2024 und 21.10.-01.11.2024 als weitere Umstellungen.
  - Rot unter Berlin bestätigen, grün unter UTC wie bisher.
- [x] Impl: Schleife in `insights_utils.dart` mit `addCalendarDays(day, 1)`.

### Schritt 3: Domain — Härtung Wochenstart (ohne eigene Tests)
- [x] `overtime_utils.dart` Z. 44-45 auf `addCalendarDays`; bestehende `overtime_utils_test.dart` müssen unter UTC und Berlin grün bleiben.

### Schritt 4: Presentation — Reports (ViewModel + Seite)
- [x] ViewModel-Test (`ProviderContainer(overrides: [...])`, Mocks wie im bestehenden Reports-VM-Test): `selectDate(DateTime(2025, 10, 26, 23))` und `selectDate(DateTime(2025, 3, 23, 23))` setzen `selectedDay` auf lokale Mitternacht (rot unter Berlin und UTC, da heute nicht normalisiert).
- [x] Impl `selectDate` normalisiert; Härtung `reports_view_model.dart` Z. 311-312 und `dashboard_view_model.dart` Z. 121 auf `addCalendarDays` (bestehende Tests grün, keine neuen).
- [x] `reports_page.dart`: `_selectDateRange` über `datesInRange` + `_isWorkday`-Filter; Pfeile über `shiftWeekStart(startOfWeek, -1/+1)`; Z. 699 `addCalendarDays(startOfWeek, 6)`.
  Die Fehler selbst sind durch die Helfer-Tests aus Schritt 1 abgedeckt (reines Verdrahten). Der Rot-Nachweis am Altverhalten steht im Probelauf-Skript des Entwicklers (Berlin: 24.10.-28.10.2025 lieferte 4 Tage, Mo 20.10.2025 +7 blieb in der Woche). Falls `reports_page_widget_test.dart` unter Berlin ohne Aufwand testbar ist, optional ein Widget-Test „Pfeil nächste Woche aus Mo 20.10.2025 zeigt Woche ab 27.10." (MaterialApp mit `AppLocalizations`-Delegates, `locale: Locale('de')`); sonst entfällt er.

### Schritt 5: Core — Notification
- [x] Test in `notification_service_test.dart` (`setUpAll`: `tz.initializeTimeZones()`, `tz.setLocalLocation(tz.getLocation('Europe/Berlin'))`, danach wieder auf den vorherigen Wert zurücksetzen, falls andere Tests in der Datei UTC erwarten; `now` fest injiziert), Erinnerung 08:00:
  - Fr 28.03.2025 (now 10:00), Ziel So (7) -> So 30.03.2025 08:00, `timeZoneOffset` +02:00 (vorher 09:00).
  - Sa 29.03.2025, Ziel Mo (1) -> Mo 31.03.2025 08:00.
  - Mo 24.03.2025 nach 08:00, Ziel Mo -> Mo 31.03.2025 08:00.
  - Fr 24.10.2025, Ziel Di (2) -> Di 28.10.2025 08:00 (vorher 07:00); Mo 20.10.2025 nach 08:00, Ziel Mo -> Mo 27.10.2025 08:00.
  - Grenzfälle: gleicher Wochentag, Zeit noch offen -> heute; gleicher Wochentag, Zeit vorbei -> +7; Monats-/Jahreswechsel.
  - Rot gegen die alte Logik: Test zuerst gegen eine Kopie der alten Berechnung bzw. durch Extraktion ohne Fix (Funktion mit alter Logik) laufen lassen, dann Fix.
- [x] Impl: `nextWeeklyOccurrence` (`delta = (day - now.weekday + 7) % 7`, `TZDateTime(tz.local, now.year, now.month, now.day + delta, hour, minute)`, falls `isBefore(now)` dann `+ 7` Kalendertage); `_scheduleWeeklyNotification` ruft sie auf. Separater Commit.

### Schritt 6: CI (nur bedingt)
- [x] Lokal `TZ=Europe/Berlin flutter test` mindestens 3x hintereinander ausführen (auch zu verschiedenen Tageszeiten wenn möglich) und einmal ohne `TZ`. Nur wenn alle Läufe grün sind: `ci.yml` Z. 51-52 durch Schritt „Test (TZ=Europe/Berlin)" mit `TZ=Europe/Berlin flutter test` ersetzen (normaler UTC-Lauf bleibt). Andernfalls Schritt weglassen, Beobachtungen (flackernde Tests) als Rückmeldung an die Hauptsession, Option B (Domain-Ordner bleibt) gilt dann weiter.
- [x] Weder Ordner-Ausnahmen noch Änderungen an Bestandstests ohne Rücksprache.

### Schritt 7: Texte
- Entfällt (keine ARB-Keys, kein `flutter gen-l10n`, kein build_runner).

## Validierung
- `dart format --set-exit-if-changed lib test`
- `flutter analyze --no-fatal-infos`, `dart run custom_lint`
- `flutter test` (UTC) und `TZ=Europe/Berlin flutter test`
- Regression: Streak-Fixtures unter UTC unverändert 10/10 bzw. 9/9.
