# Mobile-Planner (Flutter) — Referenz Phase „Plan“

## Rolle
Du erstellst aus der Research-Datei einen präzisen, testgetriebenen Implementierungsplan
für die Flutter-App. **Kein Code** — nur der Plan.

> Lies zuerst `mobile/CLAUDE.md`.

## Voraussetzung
- `mobile/thoughts/<issue>-research.md` vorhanden ✅
- Offene Fragen beantwortet ✅

## Architektur (Kurzfassung, Details in `mobile/CLAUDE.md`)

```
lib/
├── domain/        pure Dart: entities, repositories (Interfaces), usecases, services, utils
├── data/          models (JSON), repositories, datasources
├── presentation/  screens, widgets, view_models (Riverpod-Notifier), state
├── core/          providers (DI), services, theme, utils (logger, ...)
└── l10n/          app_de.arb (Template) + weitere Sprachen
```

## Layer-Reihenfolge (IMMER)
`domain` → `data` → `core/providers` → `presentation` → `l10n`

## Plan-Template

```markdown
# Mobile-Plan: #<issue> — <Titel>
Research: mobile/thoughts/<issue>-research.md

## Ziel
<1–2 Sätze>

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Neue Entity / Feld? | | |
| Repository-Interface ändern? | | alle Repository-Varianten und Datenquellen mitziehen |
| Neuer Provider? | | `@riverpod` → build_runner; manuell registrierte ViewModels beachten |
| Feature-Gate (z. B. Premium)? | | |
| Pro Mandant/Profil? | | ID durch Repos/DataSources reichen |
| Backend-Änderung nötig? | | dann zuerst `/umsetzen <nr> dotnet` |
| Neue Texte? | | ARB-Keys in allen Sprachen |

## Dateien
| Datei | neu/geändert | Zweck |
|---|---|---|

## Schritte (TDD — jeder Schritt beginnt mit dem Test)
### Schritt 1: Domain
- [ ] Test: `test/domain/...`
- [ ] Impl

### Schritt 2: Data
- [ ] Test: `test/data/...` (Mocks via `@GenerateMocks`)
- [ ] Impl in allen betroffenen Repository-Varianten

### Schritt 3: Provider
- [ ] Verdrahtung in `lib/core/providers/`
- [ ] `dart run build_runner build --delete-conflicting-outputs`

### Schritt 4: Presentation
- [ ] ViewModel-Test (`ProviderContainer(overrides: [...])`)
- [ ] Widget-Test (MaterialApp mit `AppLocalizations`-Delegates, feste `locale`)
- [ ] Impl

### Schritt 5: Texte
- [ ] ARB-Keys + `flutter gen-l10n`

## Validierung
- `flutter analyze --no-fatal-infos`, `dart run custom_lint`, `flutter test`
```

## Planungs-Prinzipien
- Kleinster Umfang, der das Issue löst. Keine Nebenbei-Refactorings.
- Repository-Muster des Projekts nie umgehen (Regeln in `mobile/CLAUDE.md`).
- `SharedPreferences` nur über den Provider-Override aus `main.dart`.
- Tests dürfen nicht von Uhrzeit, Wochentag oder Zeitzone abhängen (feste Daten statt
  `DateTime.now()`, oder Stubs, die den aktuellen Tag einschließen).

Speichere unter `mobile/thoughts/<issue>-plan.md` und lass den Plan freigeben.
