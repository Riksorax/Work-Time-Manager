# Mobile-Research: #369 — Reports-Kalender: Feiertags-Tooltip bleibt bei englischer Oberfläche deutsch
Datum: 2026-10-04

## Aufgabe
Im Reports-Kalender (`_Calendar` in `reports_page.dart`) soll der Feiertagsname in der App-Sprache erscheinen
(wie das Dashboard-Banner aus #279/#368): über `getGermanHolidayIds` + `GermanHolidayLocalizedName.localizedName(l10n)`.
Danach `getGermanHolidayNames` auf weitere Aufrufer prüfen, ggf. entfernen. Test mit EN-Locale.
Nicht Teil: Berechnungslogik, Bundesland-Zuordnung, Web/Backend. Label `bug`, Plattform nur Mobile.

Akzeptanzkriterien (abgeleitet): (1) Tooltip in EN = englischer Name, in DE unverändert; (2) Semantics-Label
(`holidaySemanticSuffix`) ebenfalls lokalisiert; (3) Test mit EN-Locale; (4) Entscheidung zu `getGermanHolidayNames`.

## Betroffene Dateien
| Datei | Warum |
|---|---|
| `mobile/lib/presentation/screens/reports_page.dart` Z. 1974-1979 | `holidayNames = getGermanHolidayNames(...)` (`Map<DateTime,String>`), `holidays = holidayNames.keys.toSet()` |
| dito Z. 2124-2125, 2149-2153 | `holidayName` pro Zelle, `Tooltip(message: holidayName)` |
| dito Z. 2178-2179 | **Semantics-Label** nutzt denselben `holidayName` (`l10n.holidaySemanticSuffix(holidayName)`), im Issue nicht erwähnt, wird automatisch mitgefixt |
| `mobile/lib/presentation/utils/holiday_name_localizer.dart` | Extension `GermanHoliday.localizedName(AppLocalizations)`, exhaustives `switch`, bereits fertig |
| `mobile/lib/domain/utils/german_holidays.dart` | `getGermanHolidayNames` (Z. 24), `getGermanHolidayIds` (Z. 142), `getGermanHolidays` (Z. 14) |
| `mobile/lib/l10n/app_de.arb` / `app_en.arb` | Keys `holidayNewYear` ... `holidayRepentanceDay` (17) existieren bereits; kein neuer Key nötig |
| `mobile/test/domain/utils/german_holidays_test.dart` Z. 101-117, 199-205 | Test auf `getGermanHolidayNames` und Paritätstest |
| `mobile/test/domain/utils/german_holidays_fixture.dart` Z. 161 | `germanHolidayGermanNames` (Kommentar verweist auf `getGermanHolidayNames`) |
| `mobile/test/presentation/screens/reports_page_widget_test.dart` | Vorlage für Widget-Test (FakeReportsViewModel, FakeSettingsViewModel) |

## Ist-Zustand
- `_CalendarState.build` hat bereits `l10n = AppLocalizations.of(context)` (Z. 1963) und `locale = Localizations.localeOf(context).toString()` (Z. 1964). Locale-Zugriff ist also vorhanden, nichts Neues nötig.
- Namen werden an genau zwei Stellen verwendet: Tooltip (Z. 2150) und Semantics-Suffix (Z. 2179). `holidays`-Set nur für rote Markierung (Key-Lookup).
- Alle Aufrufer von `getGermanHolidayNames`:
  - lib: `reports_page.dart:1977` (einziger produktiver Aufrufer) und intern `german_holidays.dart:15` (`getGermanHolidays` ruft es auf).
  - test: `german_holidays_test.dart:103` (Schlüsselwerte-Test, prüft deutsche Namen) und `:201` (Paritätstest Ids vs. Namen).
- `getGermanHolidays` (List) hat keinen lib-Aufrufer, nur Tests (german_holidays_test.dart, viele Stellen). `holiday_today_provider.dart` nutzt bereits `getGermanHolidayIds`.
- Reports-Tests (`reports_page_*test.dart`) enthalten aktuell keine Feiertags-/Bundesland-Tests; `FakeSettingsViewModel` liefert `SettingsEntity()` ohne Bundesland.

## Datenfluss
`settingsViewModelProvider` (bundesland) -> `_CalendarState.build` -> `getGermanHolidayNames(year, bundesland)` -> `Map<DateTime,String>` -> Tooltip/Semantics.
Soll: -> `getGermanHolidayIds(year, bundesland)` -> `Map<DateTime,GermanHoliday>`; pro Zelle `holidayIds[DateTime(y,m,d)]?.localizedName(l10n)`. Reine Presentation, kein ViewModel/UseCase/Repo/DataSource betroffen. `holidays`-Set bleibt `holidayIds.keys.toSet()`.
Beide Maps haben identische Schlüssel (lokale Mitternacht), Paritätstest sichert das ab.

## Plattformübergreifend
Nur Mobile. Web hat eigene Variante (ngx-translate, siehe 279-Koordination); kein Backend-/Firestore-Bezug, keine Rules, keine Provider-Änderung, kein build_runner, keine neuen ARB-Keys (`flutter gen-l10n` nicht nötig).

## Entfernbarkeit von `getGermanHolidayNames`
Technisch ja, aber nicht trivial:
- `getGermanHolidays` baut darauf auf (müsste auf `getGermanHolidayIds(...).keys.toList()` umgestellt werden; die Berechnung ist deckungsgleich).
- Zwei Tests in `german_holidays_test.dart` hängen daran. Der Paritätstest (Z. 199-205) verliert seinen Sinn (die Parität war nur nötig, solange zwei Implementierungen existieren); die ID-Fixture-Tests (Z. 187-197) decken Datum+Land bereits ab. Der Test Z. 101-117 (Schlüssel = reine Datumswerte) müsste auf `getGermanHolidayIds` umgeschrieben werden (gleiche Datums-Assertions, ID statt String; die Namenssemantik prüft `holiday_name_localizer_test.dart`).
- `germanHolidayGermanNames` (Fixture) wird weiter vom Localizer-Test gebraucht; nur der Kommentar zu `getGermanHolidayNames` anpassen.
- Doc-Kommentare in `german_holidays.dart` (Z. 18-23, 134-139) und Hinweise in `thoughts/*` (historisch, nicht ändern) anpassen. Ältere Doku `thoughts/356-*` ist nur Archiv.
- Vorteil: ein einziger Rechenpfad, 17 hartkodierte deutsche Strings und doppelte Länder-Switch-Logik (~85 Zeilen) fallen weg, kein Drift-Risiko.

## Offene Fragen
1. `getGermanHolidayNames` im selben PR entfernen? Empfehlung: ja (Issue nennt "ggf. entfernen", einziger Aufrufer verschwindet). `getGermanHolidays` intern auf `getGermanHolidayIds(...).keys.toList()` umstellen, Paritätstest löschen, Z.-101-Test auf Ids umschreiben. Alternative (nur umstellen, Funktion behalten) wäre toter Code mit Doppelpflege.
2. Semantics-Suffix mitlokalisieren? Empfehlung: ja, passiert automatisch, wenn `holidayName` aus dem Localizer kommt; im Test mitprüfen (`find.bySemanticsLabel`/`tester.getSemantics`).
3. Test-Scope: Empfehlung Widget-Test in `reports_page_widget_test.dart` (oder neue Datei `reports_page_holiday_test.dart`) mit festem Datum, z. B. `selectedDay = DateTime(2026, 10, 3)` (Tag der Deutschen Einheit, bundesweit), Bundesland z. B. `Bundesland.bayern`, Locale `en` -> Tooltip "German Unity Day" und Semantics enthält ", holiday: German Unity Day"; Gegenprobe `de` -> "Tag der Deutschen Einheit". Tooltip per `tester.longPress` auf `find.text('3')` bzw. `find.byTooltip('German Unity Day')` prüfen (Tooltip-Message ist per `find.byTooltip` auffindbar, kein Long-Press nötig). `FakeSettingsViewModel` muss um Bundesland erweitert werden (Feld/Parameter), nicht von Datum/Zeitzone abhängig; `ReportsState.selectedMonth/focusedDay` fest setzen. Zustimmung?
4. Soll auch ein ARB-Key-Wechsel in `holidaySemanticSuffix` nötig sein? Nein, Platzhalter `{name}` reicht (DE/EN vorhanden).

## Risiken
- Test-Setup: `setUpAll(() => initializeDateFormatting('de_DE', null))` im bestehenden Test; für EN-Locale zusätzlich `initializeDateFormatting('en', null)` bzw. prüfen, ob das Delegate-Setup ausreicht, sonst `LocaleDataException` bei `DateFormat.yMMMM('en')`/`EEEE`.
- Semantics-Label formatiert Datum hart mit `'EEEE, d. MMMM yyyy'` (Z. 2179): in EN unschön ("d." mit Punkt), eigenständiges Thema, nicht Teil von #369; nur beim Test-Assert beachten (nicht auf vollen String prüfen, nur `contains('German Unity Day')`).
- `_Calendar` ist privat; Test muss über `ReportsPage` pumpen (großes Fenster 800x3000 wie im Bestandstest), `isPremiumProvider` und `sharedPreferencesProvider` überschreiben.
- Entfernen von `getGermanHolidayNames` ändert Test-Dateien, die `getGermanHolidays` testen, nur indirekt; Regression über Fixture-Tests (16 Länder x Jahre) abgesichert. `TZ=Europe/Berlin flutter test` (CI) muss grün bleiben, DST-Test (german_holidays_test Z. 36ff) deckt `getGermanHolidays` weiter ab.
- Format/Analyse: `dart format`, `flutter analyze`, `custom_lint`; ungenutzter Import `german_holidays.dart` bleibt in reports_page nötig (für `getGermanHolidayIds`), neuer Import `../utils/holiday_name_localizer.dart` nötig.

## Entscheidungen zu den offenen Fragen (Hauptsession)

Alle Empfehlungen übernommen: (1) `getGermanHolidayNames` im selben PR entfernen, `getGermanHolidays` auf `getGermanHolidayIds(...).keys.toList()` umstellen, Paritätstest löschen, Namen-Test auf IDs umschreiben, Kommentare/Doc-Kommentare anpassen; (2) Semantics-Suffix (`holidaySemanticSuffix`) mitlokalisieren; (3) Widget-Test über `ReportsPage` (Fenster 800x3000), festes Datum 2026-10-03, Bundesland Bayern, Locale `en` → `find.byTooltip('German Unity Day')`, Semantics enthält 'German Unity Day'; Gegenprobe `de` ('Tag der Deutschen Einheit'); `FakeSettingsViewModel` um ein Bundesland erweitern; `initializeDateFormatting('en')` falls nötig; (4) hartes Datumsformat `'EEEE, d. MMMM yyyy'` im Semantics-Label bleibt außerhalb von #369 (im Test nur auf `contains` prüfen).
