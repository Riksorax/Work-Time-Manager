# Mobile-Plan: #354 — Wochen-Reflexion: Schlüssel ohne ISO-Wochenjahr
Research: mobile/thoughts/354-research.md (inkl. "Entscheidungen zu den offenen Fragen")

## Ziel
Der Dokument-Schlüssel `yyyy-Www` der Wochen-Reflexion nutzt das ISO-Wochenjahr (`isoWeekYear`) statt des Kalenderjahrs des Montags; Jahr und Wochenzahl werden im ViewModel aus demselben Montagsdatum berechnet. Der PDF-Dateiname des Wochenberichts bekommt dasselbe ISO-Jahr.

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Neue Entity / Feld? | Nein. Nur Doc-Kommentar an `WeeklyReflectionEntity.id` (ISO-Wochenjahr, Vertrag für Web) | Schlüsselformat bleibt `yyyy-Www`, nur die Jahresquelle ändert sich |
| Repository-Interface ändern? | Nein. `getReflection(year, week)` / `saveReflection` bleiben; Impl, DataSource, ApiDataSource unberührt | Schlüsselberechnung gehört in die Präsentation/ViewModel-Ebene (Entscheidung 3), kein Hybrid-/Local-Pendant vorhanden (bewusst) |
| Signaturänderung ViewModel/Dialog | `WeeklyReflectionViewModel.loadReflection(DateTime startOfWeek)` berechnet `isoWeekYear`/`isoWeekNumber` selbst. `WeeklyReflectionDialog` bekommt `startOfWeek` (DateTime) statt `year`/`week`; Titel nutzt `isoWeekNumber(startOfWeek)` | Aufrufer können Jahr und Woche nicht mehr inkonsistent übergeben (Fehler an der Wurzel) |
| Altdaten | Kein Lesefallback, keine Migration (Entscheidung 1). In PR-Beschreibung vermerken, dazu Korrektur der Issue-Aussage: KW 52/53 waren nicht falsch zugeordnet, nur Montage am 29.-31.12. mit KW 1 | Feature erst seit #236 (2026-09-16); Fallback in Kollisionsjahren mehrdeutig |
| Neuer Provider? | Nein; `weeklyReflectionViewModelProvider` bleibt manuell, `providers.dart` unverändert, kein build_runner für Provider nötig | Signatur der Provider unverändert |
| Mocks | Neue Testdatei mit `@GenerateMocks([WeeklyReflectionRepository])` -> build_runner nur für `*.mocks.dart` | mockito-Konvention |
| Premium-Gate? | Unverändert | Kein neues Feature |
| Pro Arbeitszeit-Profil? | Nein; Reflexion ist nicht profilgebunden | Unverändert |
| Backend-Änderung nötig? | Nein; Web/Backend nutzen den Pfad nicht, Firestore Rules unverändert | Research |
| PDF-Dateiname | `PdfReportService.exportWeeklyReport` berechnet das Jahr intern aus `startOfWeek` via `isoWeekYear`; Signatur unverändert | Entscheidung 2. Hinweis: Dateiname ist unpadded (`KW1_...`), Beispiel Mo 29.12.2025 ergibt `Wochenbericht_KW1_2026.pdf` (die Research-Angabe "KW01_2025" ist nicht korrekt, ISO-Jahr ist 2026) |
| Neue Texte? | Nein, keine ARB-Änderung | Titel nutzt vorhandenen Key `weeklyReflectionDialogTitle(int)` |

## Dateien
| Datei | neu/geändert | Zweck |
|---|---|---|
| `mobile/test/presentation/view_models/weekly_reflection_view_model_test.dart` | neu | ViewModel-Tests Schlüsselberechnung (feste Daten) |
| `mobile/test/presentation/view_models/weekly_reflection_view_model_test.mocks.dart` | neu (generiert) | Mock `MockWeeklyReflectionRepository`, nicht editieren |
| `mobile/lib/presentation/view_models/weekly_reflection_view_model.dart` | geändert | `loadReflection(DateTime startOfWeek)`, Schlüssel aus `isoWeekYear`/`isoWeekNumber` |
| `mobile/lib/presentation/widgets/weekly_reflection_dialog.dart` | geändert | Parameter `startOfWeek` statt `year`/`week`; Titel aus `isoWeekNumber` |
| `mobile/lib/presentation/screens/reports_page.dart` (~756-759) | geändert | `WeeklyReflectionDialog(startOfWeek: startOfWeek)` |
| `mobile/test/presentation/screens/reports_page_test.dart` | geändert | Reflexions-Widgettest auf festes Datum, `getReflection(2026, 1)` verifizieren; neuer Test für Kollisionspaar |
| `mobile/test/core/services/pdf_report_service_test.dart` | geändert | Fake fängt `filename` ab; Dateiname-Tests |
| `mobile/lib/core/services/pdf_report_service.dart` (Z. 151) | geändert | Dateiname mit `isoWeekYear(startOfWeek)` (+ Import `domain/utils/iso_week.dart`) |
| `mobile/lib/domain/entities/weekly_reflection_entity.dart` | geändert | Doc-Kommentar an `id`: Jahr ist ISO-Wochenjahr, nicht Kalenderjahr; Vertrag für Web |
| `/home/user/Work-Time-Manager/CLAUDE.md` | geändert | Pfadtabelle: Zeile `users/{uid}/weekly_reflections/{yyyy-Www}` (ISO-Wochenjahr, nur Mobile, nicht profilgebunden; Felder `whatWentWell`, `whatWasHard`, `updatedAt`) |

## Schritte (TDD — jeder Schritt beginnt mit dem Test)

Feste Testdaten (keine `DateTime.now()`, keine Zeitzonenabhängigkeit; Montage als `DateTime(y, m, d)`):
| Montag | erwarteter Schlüssel |
|---|---|
| 2025-12-29 | `2026-W01` (year 2026, week 1) |
| 2024-12-30 | `2025-W01` |
| 2024-01-01 | `2024-W01` (Gegenprobe Kollision: ungleich zum Schlüssel von 2024-12-30) |
| 2026-03-09 (normale Woche) | `2026-W11` |
| 2026-12-28 (KW-53-Jahr) | `2026-W53` (Kalenderjahr = ISO-Jahr, kein Fehler) |

### Schritt 1: Domain
- [x] Kein Test nötig (reiner Doc-Kommentar; `isoWeekYear` bereits in `test/domain/utils/iso_week_test.dart` getestet). Prüfen, ob `iso_week_test.dart` die Montage 2025-12-29, 2024-12-30, 2024-01-01 und 2026-12-28 schon abdeckt; fehlende Fälle ergänzen.
- [x] Impl: Doc-Kommentar an `WeeklyReflectionEntity.id`.

### Schritt 2: Data
- [x] Keine Änderung (Repository-Interface, Impl, `FirestoreDataSource`, `ApiDataSource` bleiben). Kein Test.

### Schritt 3: Provider
- [x] Keine Änderung in `lib/core/providers/`. Nur `dart run build_runner build --delete-conflicting-outputs` für das neue `*.mocks.dart` (nach Schreiben des Tests).

### Schritt 4: Presentation
ViewModel (Test zuerst, rot):
- [x] `test/presentation/view_models/weekly_reflection_view_model_test.dart`: `ProviderContainer` mit `weeklyReflectionRepositoryProvider.overrideWithValue(mock)`; für jede Zeile der Tabelle `loadReflection(montag)` und `verify(getReflection(year, week))` bzw. `state.reflection.id`.
- [x] Test: Kollisionspaar 2024-01-01 und 2024-12-30 ergeben unterschiedliche `reflection.id` (`2024-W01` vs `2025-W01`).
- [x] Test: Repository liefert `null` -> leere Reflexion mit ISO-Schlüssel (2025-12-29 -> `2026-W01`); Repository wirft -> leere Reflexion mit richtigem Schlüssel.
- [x] Test: Repository `null` (ausgeloggt, `overrideWithValue(null)`) -> leere Reflexion mit ISO-Schlüssel, kein Repository-Aufruf.
- [x] Test: `saveReflection` nach `loadReflection(2025-12-29)` ruft `saveReflection` mit Entity `id == '2026-W01'` (captureAny).
- [x] Impl `weekly_reflection_view_model.dart`: `loadReflection(DateTime startOfWeek)`; `year = isoWeekYear(startOfWeek)`, `week = isoWeekNumber(startOfWeek)` einmal berechnen und für alle drei Zweige (Repository null, Treffer, Fehler) verwenden. Import `../../domain/utils/iso_week.dart`.

Widget/Dialog (Test zuerst, rot):
- [x] `reports_page_test.dart`, bestehender Test `Wochen-Reflexion Button öffnet Dialog und speichert`: `initialState` mit festem Datum `selectedDay: DateTime(2025, 12, 31)`, `selectedMonth: DateTime(2025, 12, 31)` (Woche Mo 2025-12-29, wie bereits der KW-Test) statt `DateTime.now()`-Default (`selectedDay` null -> `DateTime.now()`). `verify(getReflection(2026, 1))` statt `any, any`; `captured.year == 2026`, `captured.week == 1`, `captured.id == '2026-W01'`. Der Aufwand ist gering (zwei Felder im `copyWith`).
- [x] Neuer Widget-Test im selben File: Montag 2024-12-30 (selectedDay 2024-12-31) -> `getReflection(2025, 1)`; (optional, parametrisiert zusammen mit 2024-01-02 -> `getReflection(2024, 1)`) belegt, dass die Kollisionswochen getrennte Schlüssel bekommen.
- [x] Dialogtitel im Test: `find.textContaining('KW 1')` bzw. der Text aus `weeklyReflectionDialogTitle(1)` (genauen Wortlaut aus `app_de.arb` übernehmen).
- [x] Impl `weekly_reflection_dialog.dart`: Feld `final DateTime startOfWeek;`, `loadReflection(widget.startOfWeek)`, Titel `weeklyReflectionDialogTitle(isoWeekNumber(widget.startOfWeek))`.
- [x] Impl `reports_page.dart`: `WeeklyReflectionDialog(startOfWeek: startOfWeek)`; `weekNumber` bleibt für Titel/PDF.
- [x] Weitere Test-/Code-Treffer für `WeeklyReflectionDialog(year:` per Grep prüfen und anpassen (laut Research einziger Aufrufer; kein eigener Dialog-Test vorhanden).

PDF-Dateiname (Test zuerst, rot):
- [x] `pdf_report_service_test.dart`: `_FakePrintingPlatform` speichert zusätzlich `lastFilename`. Tests mit `exportWeeklyReport`: Mo 2025-12-29, `weekNumber: 1` -> `Wochenbericht_KW1_2026.pdf`; Mo 2024-12-30 -> `Wochenbericht_KW1_2025.pdf`; normale Woche Mo 2026-01-05, `weekNumber: 2` -> `Wochenbericht_KW2_2026.pdf`. Locale `de` reicht.
- [x] Impl `pdf_report_service.dart` Z. 151: `${isoWeekYear(startOfWeek)}` statt `${startOfWeek.year}`.

### Schritt 5: Texte
- [x] Keine ARB-Änderung, kein `flutter gen-l10n`.

### Schritt 6: Doku
- [x] Root-`CLAUDE.md`: Zeile in der Firestore-Pfadtabelle (nur Doku). Keine Änderung an `web/CLAUDE.md`.

## Validierung
- `cd mobile && dart run build_runner build --delete-conflicting-outputs` (nur wegen neuem `*.mocks.dart`)
- `dart format --set-exit-if-changed lib test && flutter analyze --no-fatal-infos && dart run custom_lint && flutter test`
- Zielgerichtet vorab: `flutter test test/presentation/view_models/weekly_reflection_view_model_test.dart test/presentation/screens/reports_page_test.dart test/core/services/pdf_report_service_test.dart test/domain/utils/iso_week_test.dart`

## Hinweise für die PR-Beschreibung
- Bewusster Verzicht auf Fallback/Migration für Altdaten (nur Woche 29.12.2025 -> alter Schlüssel `2025-W01` theoretisch betroffen, keine Kollision).
- Korrektur der Issue-Aussage: nicht KW 52/53, sondern Wochen mit Montag 29.-31.12. und ISO-KW 1.
- Nicht in diesem PR: `reports_page_test.dart` nutzt in den Insights-Tests weiterhin `DateTime.now()`; nur der Reflexions-Test wird umgestellt.
