# Mobile-Plan: #369 — Reports-Kalender: Feiertags-Tooltip bleibt bei englischer Oberfläche deutsch
Research: mobile/thoughts/369-research.md (inkl. "Entscheidungen zu den offenen Fragen")

## Ziel
Der Feiertagsname im Reports-Kalender (Tooltip und Semantics-Label) erscheint in der App-Sprache
(`getGermanHolidayIds` + `GermanHolidayLocalizedName.localizedName(l10n)`). `getGermanHolidayNames`
wird entfernt, `getGermanHolidays` nutzt nur noch `getGermanHolidayIds`.

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Neue Entity / Feld? | Nein | `GermanHoliday`-Enum und Localizer existieren (#279/#368) |
| Repository-Interface ändern? | Nein | Reine Presentation/Domain-Util; Hybrid-, Firebase-, Local-, ApiDataSource unberührt |
| Neuer Provider? | Nein, kein build_runner | `settingsViewModelProvider` wird bereits gelesen |
| Premium-Gate? | Keins | Kalender-Tooltip ist nicht Premium-gebunden |
| Pro Arbeitszeit-Profil? | Nicht betroffen | Bundesland kommt aus den bestehenden Settings, `profileId` unverändert |
| Backend-Änderung nötig? | Nein | Nur Mobile |
| Neue Texte? | Nein | 17 Feiertags-Keys und `holidaySemanticSuffix` existieren in de + en; kein `flutter gen-l10n` |
| `getGermanHolidayNames` entfernen? | Ja, im selben PR | Einziger lib-Aufrufer entfällt. Ein Rechenpfad, kein Drift, ca. 85 Zeilen und 17 deutsche Strings weniger. `getGermanHolidays` wird zu `getGermanHolidayIds(...).keys.toList()` (Ergebnis identisch, DST-Test sichert ab) |
| Semantics-Label mitlokalisieren? | Ja | Nutzt dieselbe Variable, kein Zusatzaufwand |
| Hartes Datumsformat `'EEEE, d. MMMM yyyy'` im Semantics-Label | Nicht ändern | Außerhalb #369; Test prüft nur `contains` |
| Testort | `reports_page_widget_test.dart` erweitern (keine neue Datei) | Fakes und Setup sind dort schon vorhanden |

## Dateien
| Datei | neu/geändert | Zweck |
|---|---|---|
| `mobile/test/presentation/screens/reports_page_widget_test.dart` | geändert | `FakeSettingsViewModel` bekommt optionalen `Bundesland`-Parameter (Default null, Bestandstest unverändert). Neue Widget-Tests EN/DE. `setUpAll` um `initializeDateFormatting('en', null)` ergänzen |
| `mobile/lib/presentation/screens/reports_page.dart` | geändert | `_CalendarState.build` (ca. Z. 1974-1979, 2124-2153, 2178-2179): `holidayIds = getGermanHolidayIds(...)`, `holidays = holidayIds.keys.toSet()`, pro Zelle `holidayName = holidayIds[DateTime(y,m,d)]?.localizedName(l10n)`. Neuer Import `../utils/holiday_name_localizer.dart` |
| `mobile/test/domain/utils/german_holidays_test.dart` | geändert | Test Z. 101-117 auf `getGermanHolidayIds` umschreiben (gleiche Daten, Assert auf `GermanHoliday.easterMonday` o. ä. statt String); Paritätstest Z. 199-206 löschen |
| `mobile/test/domain/utils/german_holidays_fixture.dart` | geändert | Nur Kommentar bei `germanHolidayGermanNames` (ca. Z. 161): Verweis auf `getGermanHolidayNames` entfernen; die Map bleibt für den Localizer-Test |
| `mobile/lib/domain/utils/german_holidays.dart` | geändert | `getGermanHolidayNames` (ab Z. 24) samt Länder-Switch löschen; `getGermanHolidays` (Z. 14) auf `getGermanHolidayIds(...).keys.toList()`; Doc-Kommentare Z. 18-23 und 134-139 anpassen |

Enum-Namen der `GermanHoliday`-Werte vor dem Umschreiben des Tests in `german_holidays.dart` nachschlagen.

## Schritte (TDD)

### Schritt 1: Presentation-Test zuerst (rot)
- [x] Test in `reports_page_widget_test.dart`:
  - `FakeSettingsViewModel({this.bundesland})` liefert `SettingsEntity(bundesland: bundesland)`.
  - Helfer zum Pumpen mit Parameter `Locale`; festes Datum `DateTime(2026, 10, 3)` für `focusedDay`, `selectedDay`, `selectedMonth`, `workEntries: const {}`, Fenster 800x3000, `isPremiumProvider` und `sharedPreferencesProvider` überschrieben.
  - Bundesland `Bundesland.bayern`. Der 3.10. ist bundesweiter Feiertag, unabhängig von Wochentag/Zeitzone/`DateTime.now()`.
  - Test A (en): `find.byTooltip('German Unity Day')` findsOneWidget; `find.byTooltip('Tag der Deutschen Einheit')` findsNothing; Semantics-Label der Zelle `contains('German Unity Day')` (via `tester.getSemantics`/`find.bySemanticsLabel(RegExp(...))`, `ensureSemantics()` mit `addTearDown(handle.dispose)`).
  - Test B (de): Gegenprobe `find.byTooltip('Tag der Deutschen Einheit')` findsOneWidget, Semantics `contains('Tag der Deutschen Einheit')`.
  - Test C (Bundesland null, optional): kein Tooltip `German Unity Day`/`Tag der Deutschen Einheit` (kein Feiertag ohne Bundesland).
- [x] `flutter test test/presentation/screens/reports_page_widget_test.dart` muss rot sein: Test A schlägt fehl, weil der Tooltip den deutschen Namen trägt. Rot-Beleg für den Bericht festhalten. Falls der Test schon an `LocaleDataException` scheitert, erst `initializeDateFormatting('en')` ergänzen, damit der Fehlschlag am Tooltip liegt.
- [x] Impl: `reports_page.dart` wie oben (Schritt 4 dieses Plans = Fix); Tests A/B/C grün.

### Schritt 2: Domain-Tests vorbereiten (vor Entfernen der Funktion)
- [x] Test `german_holidays_test.dart`: Z.-101-Test auf `getGermanHolidayIds` umschreiben (Bayern 2024/2027, Ostermontag, Christi Himmelfahrt, Pfingstmontag, Fronleichnam; Schlüssel = lokale Mitternacht-Daten, Assert auf Enum-Wert). Läuft grün gegen den bestehenden Code.
- [x] Paritätstest Z. 199-206 löschen. Fixture-Tests (Z. 184-197) decken Datum und Land weiter ab.
- [x] `german_holidays_fixture.dart`: Kommentar anpassen.

### Schritt 3: Domain-Impl
- [x] `german_holidays.dart`: `getGermanHolidayNames` entfernen, `getGermanHolidays` umstellen, Doc-Kommentare anpassen.
- [x] `grep -rn getGermanHolidayNames mobile/lib mobile/test` muss leer sein (`thoughts/*` bleibt historisch).
- [x] Bestehender DST-Test und `getGermanHolidays`-Tests (landesspezifisch, Z. 120-172) bleiben unverändert und grün.

### Schritt 4: Presentation-Impl
- [x] Fix in `reports_page.dart` (siehe Dateien). Das Localizer-Switch ist exhaustiv, kein `!`-Cast nötig (`?.localizedName`). Unbenutzte Variable `holidayNames` darf nicht übrig bleiben.

### Schritt 5: Texte / Provider
- Entfällt (keine ARB-Änderung, kein build_runner).

## Validierung
- `cd mobile && dart format --set-exit-if-changed lib test && flutter analyze --no-fatal-infos && dart run custom_lint && flutter test`
- Zusätzlich `TZ=Europe/Berlin flutter test test/domain/utils test/presentation/screens/reports_page_widget_test.dart` (und einmal mit `TZ=UTC`), da CI in Berlin-Zeit läuft. Alle Daten sind fest, keine `DateTime.now()`-Abhängigkeit.

## Risiken
- EN-Locale braucht Datumsdaten (`initializeDateFormatting('en', null)`), sonst `LocaleDataException`.
- `find.byTooltip` kann bei Mehrfach-Treffern (Zelle plus Semantics-Wrapper) mehr als ein Widget finden. Dann auf `findsWidgets` mit präzisem Zell-Finder wechseln statt die Implementierung anzupassen.
- Der Kalender lädt Feiertage nur für `widget.selectedDate.year`; bleibt unverändert (außerhalb #369).
