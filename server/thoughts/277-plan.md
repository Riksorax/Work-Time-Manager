# Backend-Plan: #277 Home-Office-Flag (Free)
Erstellt: 2026-10-16
Research: server/thoughts/277-research.md
Branch: `feature/277-homeoffice-api` (PR 1, "Refs #277"), Commit-Muster `feat(api): Home-Office-Flag am Arbeitseintrag (#277)`

## Ziel
`isHomeOffice` als additives, nullable Feld an `WorkEntryDto`/`DayData`. GET liefert immer ein bool (fehlend = `false`). PUT schreibt das Feld nur bei `true`/`false`; fehlt es, bleibt ein gespeicherter Wert unberührt.

## Vertrag (zuerst; Web und Mobile hängen davon ab)
| Teil | Festlegung |
|---|---|
| Route | unverändert: `GET/PUT /api/work-entries...`, `?profileId=` wie bisher |
| JSON | `isHomeOffice: boolean` (camelCase) |
| GET | immer `true` oder `false` |
| PUT | `true`/`false` schreibt; `null`/fehlend = unangetastet (alte Clients); `false` löscht fachlich |
| Firestore | `days.{d}.isHomeOffice` (bool), Root und `profiles/{id}`; fehlend = `false` |
| Kompatibilität | rein additiv, kein Pflichtfeld, kein Default-Zwang |
| Rules / Secrets / Migration | keine |

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Typ in `DayData`/DTO | `bool?` | `null` unterscheidet "nicht gesendet" von `false` |
| Null-Schutz | `SetOptions.MergeFields` mit Feldliste aus `FirestoreMappings` | bewährtes Muster (`SettingsMergeFields`), unit-testbar |
| Server-Validierung nach Typ | keine | Clients ignorieren das Flag bei Nicht-Work-Tagen (Vertrag 2.1) |
| Report-Änderung | keine | Home-Office-Zählung rechnet Mobile lokal (#282) |
| Neuer Endpunkt / Auth-Test | nein | `EndpointAuthTests` deckt `PUT /api/work-entries` bereits ab |

## Dateien
| Datei | neu/geändert | Zweck |
|---|---|---|
| `src/WorkTimeManager.Api/Firestore/Documents/DayData.cs` | geändert | Property `IsHomeOffice` (`bool?`) |
| `src/WorkTimeManager.Api/Contracts/WorkEntryDto.cs` | geändert | `bool? IsHomeOffice { get; init; }` |
| `src/WorkTimeManager.Api/Firestore/FirestoreMappings.cs` | geändert | `ToDto`, `ToDocument`, `DayMergeFields(dto, dayKey)` |
| `src/WorkTimeManager.Api/Firestore/WorkEntryRepository.cs` | geändert | `SaveAsync` nutzt `SetOptions.MergeFields(DayMergeFields(...))` statt `MergeAll` |
| `tests/WorkTimeManager.Api.Tests/FirestoreMappingsTests.cs` | geändert | Mapping- und Feldlisten-Tests |
| `tests/WorkTimeManager.Api.Tests/Integration/RepositoryIntegrationTests.cs` | geändert | Emulator-Tests (`[SkippableFact]`) |
| `server/CLAUDE.md` | geändert | Abschnitt "Home-Office (#277)", Endpunkt-Zeile PUT |
| `CLAUDE.md` (Root) | geändert | Pfadtabelle Zeile "Arbeitseintrag": Feld `isHomeOffice` ergänzen |

## Schritte (TDD, jeder Schritt beginnt mit dem Test; feste Daten, kein `DateTime.Now`)

### Schritt 1: Mapping GET
- [ ] Test `WorkEntry_MissingHomeOffice_MapsToFalse`: `DayData` mit `IsHomeOffice = null` -> `ToDto(...).IsHomeOffice == false`
- [ ] Test `WorkEntry_StoredHomeOfficeTrue_MapsToTrue`
- [ ] Impl: `DayData.IsHomeOffice`, `WorkEntryDto.IsHomeOffice`, `ToDto`: `IsHomeOffice = day.IsHomeOffice ?? false`

### Schritt 2: Mapping PUT und Feldliste
- [ ] Test `WorkEntry_ToDocument_PassesHomeOfficeThrough` (true, false, null)
- [ ] Test `WorkEntry_RoundTrip_PreservesFields` (bestehend) um `IsHomeOffice = true` erweitern
- [ ] Test `DayMergeFields_WithoutHomeOffice_OmitsHomeOfficePath`: Liste enthält `days.5.date`, `...workStart`, `...breaks` usw., **nicht** `days.5.isHomeOffice`
- [ ] Test `DayMergeFields_WithHomeOfficeTrueOrFalse_IncludesPath` (beide Werte; `false` darf nicht wie `null` behandelt werden)
- [ ] Test Flutter-Format: Schlüssel ohne führende Null (`FirestoreMappings.DayKey` für Tag 5 -> `"5"`, Pfad `days.5.isHomeOffice`)
- [ ] Test Drift-Schutz: alle `[FirestoreProperty]`-Namen von `DayData` außer `isHomeOffice` sind in der Feldliste (Reflection)
- [ ] Impl: `ToDocument` reicht durch; `DayMergeFields` pure und `internal static`

### Schritt 3: Repository
- [ ] Integrationstests `[SkippableFact]` (Emulator, feste Daten z. B. 2026-06-05, kein "heute"):
  - `WorkEntry_HomeOffice_RoundTrips`: PUT `true` -> GET `true`
  - `WorkEntry_PutWithoutHomeOffice_KeepsStoredTrue`: PUT `true`, dann PUT ohne Feld (Zeiten geändert) -> GET weiter `true`, Zeiten neu
  - `WorkEntry_PutHomeOfficeFalse_OverwritesTrue`
  - `WorkEntry_LegacyDocumentWithoutField_ReadsFalse_AndStaysFieldFreeAfterPutWithoutField`
  - `WorkEntry_HomeOffice_IsIsolatedPerProfile` (Standard vs. `profileId`, Muster `WorkEntry_DifferentProfiles_AreIsolated`)
- [ ] Impl: `SaveAsync` -> `SetAsync(update, SetOptions.MergeFields(FirestoreMappings.DayMergeFields(entry, dayKey)), ct)`; sonst unverändert (Dictionary-Aufbau, Profilpfad über `ProfileScope`)

### Schritt 4: Auth
- [ ] Nichts Neues: `EndpointAuthTests` (PUT ohne Token -> 401) bleibt grün. Kurz prüfen, dass der PUT-Test ein DTO ohne das Feld sendet (Rückwärtskompatibilität).

### Schritt 5: Doku
- [ ] `server/CLAUDE.md`: Absatz "Home-Office (#277)" wie die Absätze zu #278/#279: Feld, GET immer bool, PUT-Semantik (`null`/fehlend unangetastet, `false` überschreibt), Typen-Hinweis (Clients ignorieren bei Nicht-Work), Deploy-Reihenfolge API vor Clients; Endpunkt-Zeile PUT ergänzen ("merge in days-Map, `isHomeOffice` nur wenn gesetzt")
- [ ] Root-`CLAUDE.md`: Feldliste der Zeile "Arbeitseintrag" um `isHomeOffice` ergänzen

## Validierung
Aus `server/`: `dotnet build WorkTimeManager.slnx -c Release && dotnet test WorkTimeManager.slnx -c Release`. In Cloud-Sessions werden die Emulator-Tests übersprungen (erwartet); das Verhalten von `MergeFields` mit Tages-Pfaden sollte mindestens einmal mit Docker/Emulator laufen, bevor PR 2/3 darauf bauen (CI führt sie aus, falls Docker dort verfügbar ist, sonst lokal).

## Checkliste vor dem PR
- [ ] Endpunkt unverändert in der authentifizierten Gruppe, UID aus Token
- [ ] Profilbezug: Test mit `profileId`
- [ ] Nur additive Vertragsänderung
- [ ] Keine Rechenlogik-Änderung, daher nichts nach Web zu spiegeln
- [ ] Build und Tests grün
- [ ] `server/CLAUDE.md` und Root-`CLAUDE.md` aktualisiert
- [ ] PR-Text: Deploy API vor Clients, keine Rules/Secrets/Migration; Refs #277
