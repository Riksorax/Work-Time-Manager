---
name: playbook-flutter
description: "Regeln, Checklisten und Vorlagen für Arbeit an der Flutter-App (mobile/): Analyse, TDD-Plan, Umsetzung, Tests, UI-Prüfung, Review. Verwenden, wenn ein Issue die Flutter-App betrifft; die Phase bestimmt, welche Referenz gelesen wird. Nicht für Web oder Backend."
---
# Playbook: Flutter (mobile/)

Wird von den Agents `analyst`, `developer` und `reviewer` (Modul `core`) geladen. Nur die Referenz der
laufenden Phase lesen, nicht alle.

## Phase → Referenz

| Phase | Referenz | Ergebnis |
|---|---|---|
| Analyse | [references/analyse.md](references/analyse.md) | `mobile/thoughts/<nr>-research.md` |
| Plan | [references/plan.md](references/plan.md) | `mobile/thoughts/<nr>-plan.md` (TDD, zur Freigabe) |
| Umsetzung | [references/implement.md](references/implement.md) | Code, Plan abgehakt |
| Validierung | [references/validate-tests.md](references/validate-tests.md) und [references/validate-ui.md](references/validate-ui.md) | Abschnitte „Validierung“ und „UI-Review“ im Plan |
| Review | [references/review.md](references/review.md) | Commit und PR |

## Annahmen über das Projekt
- Flutter-Code in `mobile/` (abweichender Ordner: `--mobile-dir` beim Installieren)
- Clean Architecture (`domain/`, `data/`, `presentation/`, `core/`), Riverpod, ARB-Lokalisierung
- `mobile/CLAUDE.md` beschreibt Architektur und Regeln und geht diesem Playbook vor

## Kurzregeln (gelten in jeder Phase)
- Generierte Dateien (`*.g.dart`, `*.mocks.dart`, `app_localizations*.dart`) nie von Hand ändern
- Layer-Reihenfolge `domain` → `data` → `core/providers` → `presentation` → `l10n`
- Texte nie hart kodiert, ARB in allen Sprachen
- Tests datums- und zeitzonenunabhängig
- Projektspezifisches (Datenpfade, Repository-Varianten, Feature-Gates) steht in `mobile/CLAUDE.md` oder in einem
  Projekt-Playbook, nicht hier
