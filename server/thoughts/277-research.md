# Backend-Research: #277 Home-Office-Flag (Free)
Datum: 2026-10-16
Grundlage: thoughts/277-coordination.md (Vertrag 2.1 bis 2.3), Code-Stand `develop` 8c59eab. Entscheidung Eigentümer: `isHomeOffice` als bool.

## Aufgabe
Pro Tageseintrag ein optionales Flag "von zu Hause gearbeitet". Backend nimmt es über `PUT /api/work-entries` an und liefert es über die GET-Endpunkte aus. Additiv, keine neue Route, kein neuer Pfad, keine Rechenlogik.
Akzeptanz: (1) GET liefert immer ein bool, fehlendes Feld = `false`; (2) PUT ohne Feld lässt ein gespeichertes `true` unangetastet; (3) PUT `true` setzt, PUT `false` schreibt `false`; (4) Root- und Profilpfad (`?profileId=`) identisch; (5) Flutter-Format bleibt (days-Schlüssel ohne führende Null, Zeiten als `Timestamp`).

## Betroffene Dateien
| Datei | Warum |
|---|---|
| `src/WorkTimeManager.Api/Firestore/Documents/DayData.cs` | neues `[FirestoreProperty("isHomeOffice")] bool? IsHomeOffice` |
| `src/WorkTimeManager.Api/Contracts/WorkEntryDto.cs` | `bool? IsHomeOffice { get; init; }` (additiv) |
| `src/WorkTimeManager.Api/Firestore/FirestoreMappings.cs` | `ToDto` (`?? false`), `ToDocument` (durchreichen), neuer Helfer für die Merge-Feldliste des Tages |
| `src/WorkTimeManager.Api/Firestore/WorkEntryRepository.cs` | `SaveAsync`: Null-Schutz (siehe unten) |
| `tests/.../FirestoreMappingsTests.cs` | Mapping- und Feldlisten-Tests |
| `tests/.../Integration/RepositoryIntegrationTests.cs` | `[SkippableFact]` gegen Emulator (Cloud-Session: übersprungen) |
| `server/CLAUDE.md` | Endpunkt-/Feldbeschreibung (Abschnitt wie "Bundesland (#279)") |

Nicht betroffen: `ReportCalculator`/`ReportDtos`/`ReportEndpoints` (keine Ortslogik), `WorkEntryEndpoints.cs` (DTO wird 1:1 gebunden), `Program.cs`, Auth, `web/firestore.rules` (`work_entries/{entryId}` ist `isOwner`-basiert ohne Feldliste, Root und `profiles/{id}`), Root-`CLAUDE.md` Pfadtabelle (kein neuer Pfad; höchstens ein Feldhinweis in der Zeile "Arbeitseintrag").

## Ist-Zustand und Kernproblem (Datenverlust durch alte Clients)
- `SaveAsync` baut `{ days: { "<d>": DayData-POCO } }` und schreibt mit `SetOptions.MergeAll`. MergeAll merged auf Blattfeld-Ebene: jedes Feld des POCO wird geschrieben, auch `null`. Das ist bei `Description`/`ManualOvertimeMinutes` gewollt (der Client sendet immer den vollen Tag), würde aber bei `IsHomeOffice == null` ein gespeichertes `true` durch `null` ersetzen. Genau das tun ausgelieferte Clients (Mobile 1.6.x, Web ohne Flag): sie senden das Feld nicht.
- Dasselbe Muster ist bereits gelöst: `SettingsRepository` nutzt `SetOptions.MergeFields(FirestoreMappings.SettingsMergeFields(dto))` (#278/#279), Feldliste lässt nicht gesetzte Felder aus; Tests `Settings_PutWithoutVacationField_DoesNotMergeVacationField` etc.
- Lösungsansatz für den Tag: `SetOptions.MergeFields(...)` mit expliziten `FieldPath("days", dayKey, "<feld>")` für alle bisherigen Tagesfelder (`date, workStart, workEnd, type, isManuallyEntered, manualOvertimeMinutes, description, breaks`) und `isHomeOffice` nur, wenn `dto.IsHomeOffice != null`. Das Feldlisten-Bauen gehört als pure Funktion nach `FirestoreMappings` (unit-testbar ohne Firestore), analog `SettingsMergeFields`.
- Verhalten bei `MergeFields` mit verschachtelten Pfaden: der Daten-Dictionary muss die Pfade enthalten (tut er, `days.<d>` ist das POCO); `breaks` ist ein Array-Blatt und wird ersetzt wie bisher. Verhalten ist ohne Emulator nicht lokal prüfbar (Docker fehlt in Cloud-Sessions, `[SkippableFact]`), siehe Risiko 1.
- `PUT` antwortet mit dem empfangenen DTO (`Results.Ok(entry)`), also kann `isHomeOffice` in der PUT-Antwort `null` sein, wenn der Client es nicht gesendet hat. Clients nutzen die Antwort nicht (Web `map(() => void 0)`), nur ein Hinweis in der Doku. Kein Änderungsbedarf.
- `GetMonthAsync`/`GetDayAsync`/`GetWeekAsync`/`GetYearAsync` laufen alle über `FirestoreMappings.ToDto` -> eine Stelle genügt. Reports lesen die DTOs, ignorieren das Feld.

## Datenfluss
Client -> `PUT /api/work-entries?profileId=` -> `WorkEntryDto` (Model Binding, `IsHomeOffice` `null` wenn fehlend) -> `WorkEntryRepository.SaveAsync` -> `FirestoreMappings.ToDocument` + Feldliste -> `ProfileScope.Collection(...)/work_entries/{yyyy-MM}` `days.{d}.isHomeOffice`.
GET: Firestore `MonthDocument.Days` -> `ToDto` (`day.IsHomeOffice ?? false`) -> JSON `isHomeOffice: true|false`.

## Plattformübergreifend
Backend zuerst (PR 1 laut Koordinationsplan), dann Web und Mobile. Alte Clients bleiben durch Null-Schutz kompatibel; neue Clients senden immer explizit `true`/`false`. Rechenlogik unberührt (Home-Office beeinflusst weder Soll, Pausen noch Überstunden), daher kein Spiegeln nach Web/Domain nötig. Deploy: API vor Clients (`main` -> `deploy-api.yml`), keine Rules, keine Secrets, keine Migration.

## Offene Fragen
Keine blockierenden. Zur Kenntnis:
1. Auf Typen `vacation/sick/holiday` ignorieren Clients das Flag; das Backend speichert, was es bekommt, und validiert nicht (keine Server-Validierung nach Typ, Vertrag 2.1). Empfehlung: so lassen.

## Risiken
1. `MergeFields` mit verschachtelten Tages-Pfaden ist im Repo für Tage neu (Settings nutzen flache Namen). Verhalten gegen den Emulator im CI/lokal absichern: Integrationstest "PUT ohne Feld lässt `true` stehen" ist Pflicht, läuft nur mit Docker. Rückfall, falls MergeFields mit Zahl-Schlüsseln Probleme macht: den Tages-Dictionary aus dem POCO selbst aufbauen (Feld `isHomeOffice` bei `null` weglassen) und weiter `MergeAll` nutzen; Feldnamen dafür aus den `[FirestoreProperty]`-Attributen, nicht doppelt hartkodieren.
2. Drift der Feldliste: kommt später ein weiteres Tagesfeld hinzu und wird in der Liste vergessen, wird es nie geschrieben. Gegenmaßnahme: Mapping-Test, der die Feldliste gegen alle `[FirestoreProperty]`-Namen von `DayData` abgleicht (Reflection), `isHomeOffice` als einziges bedingtes Feld.
3. Der JSON-Binder kennt `isHomeOffice: null` und fehlendes Feld gleich (beides `null`): gewollt (beides = unangetastet). Ein Client kann das Flag nur über explizites `false` löschen.
