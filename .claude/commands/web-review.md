# /web-review — Phase 5: Angular-Code reviewen und PR erstellen

Aktiviere den Web-Reviewer-Agenten (lies `.claude/agents/web-reviewer.md` vollständig).

Issue: $ARGUMENTS

## Voraussetzung
- `npm test -- --watch=false` grün ✅
- `npm run build -- --configuration production` erfolgreich ✅
- `web/thoughts/$ARGUMENTS-ui-report.md` vorhanden ✅

## Aufgabe

1. Führe den vollständigen Code-Review anhand der Checkliste durch:
   - Architektur (Layer-Grenzen, Hybrid-Service, Premium-Gate)
   - Angular-Qualität (OnPush, Signals, inject(), @if/@for, takeUntilDestroyed)
   - AngularFire-Regeln (nur `@angular/fire/*`, `runInInjectionContext`, kein `docData`)
   - Feature-Parität mit Flutter (Domain-Logik identisch)
   - UI & Responsiveness (Mobile/Tablet/Desktop/Dark Mode)
   - Accessibility (aria-labels, Kontrast, Tab-Reihenfolge)
   - Code-Hygiene (kein console.log, kein any, Texte in de.json + en.json)

2. Erstelle eine Liste der Issues:
   - 🔴 Kritisch (blockiert PR)
   - 🟡 Minor (sollte behoben werden)
   - 🟢 Hinweis (optional)

3. Erstelle die Commit-Message nach `CONTRIBUTING.md` (z. B. `feat(web): … (#123)`)

4. Erstelle die PR-Beschreibung nach `.github/pull_request_template.md` (Feature-Parität-Tabelle inklusive)

5. Speichere PR-Beschreibung: `web/thoughts/$ARGUMENTS-pr.md`

6. Erstelle den PR gegen `develop`, wenn alle kritischen Issues behoben sind:
   - lokal: `gh pr create --base develop`
   - Cloud-Session (kein `gh`): GitHub-MCP-Tool `create_pull_request` mit `base: develop`
