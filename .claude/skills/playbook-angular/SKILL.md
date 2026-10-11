---
name: playbook-angular
description: "Regeln, Checklisten und Vorlagen für die Angular-Web-App (web/): Flutter→Angular-Portierung (Analyse, UI-Design, Plan) sowie Umsetzung und Review von Angular-Code (Signals, OnPush, Vitest, ngx-translate). Verwenden, wenn ein Issue die Angular-Web-App betrifft. Nicht für Flutter oder Backend."
---
# Playbook: Angular (web/)

Wird von den Agents `analyst`, `developer` und `reviewer` (Modul `core`) geladen. Nur die Referenz der
laufenden Phase lesen.

## Phase → Referenz

| Phase | Referenz | Ergebnis |
|---|---|---|
| Analyse (Port) | [references/analyse.md](references/analyse.md) | `web/thoughts/<nr>-research.md` |
| UI-Design (Port) | [references/design.md](references/design.md) | HTML/SCSS und `web/thoughts/<nr>-ui-report.md` |
| Plan | [references/plan.md](references/plan.md) | `web/thoughts/<nr>-plan.md` (zur Freigabe) |
| Umsetzung | [references/implement.md](references/implement.md) | Code, Tests und Production-Build grün |
| Review | [references/review.md](references/review.md) | Commit, PR, `web/thoughts/<nr>-pr.md` |

Analyse, UI-Design und Plan setzen eine **Flutter-App als Vorlage** voraus. Ohne Vorlage: Plan mit dem Nutzer
abstimmen und direkt mit der Umsetzung beginnen.

## Annahmen über das Projekt
- Angular-Code in `web/` (abweichender Ordner: `--web-dir`), Layer `shared/models`+`domain` → `core/services` → `features`
- `web/CLAUDE.md` beschreibt Architektur, Dateinamen und Regeln und geht diesem Playbook vor
- Vitest, ngx-translate, Angular Material (M3)

## Kurzregeln (gelten in jeder Phase)
- OnPush, `inject()`, `@if`/`@for`, kein explizites `standalone: true`, kein `CommonModule`
- `takeUntilDestroyed()` für Subscriptions, Signals statt Subjects wo möglich
- Neue Texte über ngx-translate in allen Sprachdateien
- `npm test -- --watch=false` immer mit `--watch=false`
