# /web-review — Phase 5: Angular-Code reviewen und PR erstellen

Aktiviere den Web-Reviewer-Agenten (lies `.claude/agents/web-reviewer.md` vollständig).

Feature: $ARGUMENTS

## Voraussetzung
- `npm test` grün ✅
- `npm run build -- --configuration production` erfolgreich ✅
- `web/thoughts/$ARGUMENTS-ui-report.md` vorhanden ✅

## Aufgabe

1. Führe den vollständigen Code-Review anhand der Checkliste durch:
   - Architektur (Layer-Grenzen, Hybrid-Service, Premium-Gate)
   - Angular-Qualität (OnPush, Signals, inject(), @if/@for, takeUntilDestroyed)
   - Firebase Web SDK v10 (keine Compat-API)
   - Feature-Parität mit Flutter (Domain-Logik identisch)
   - UI & Responsiveness (Mobile/Tablet/Desktop/Dark Mode)
   - Accessibility (aria-labels, Kontrast, Tab-Reihenfolge)
   - Code-Hygiene (kein console.log, kein any, deutsche Texte)

2. Erstelle eine Liste der Issues:
   - 🔴 Kritisch (blockiert PR)
   - 🟡 Minor (sollte behoben werden)
   - 🟢 Hinweis (optional)

3. Erstelle Conventional Commit Message mit Scope `web/[feature]`

4. Erstelle PR-Beschreibung nach Template (Feature-Parität-Tabelle inklusive)

5. Speichere PR-Beschreibung: `web/thoughts/$ARGUMENTS-pr.md`

6. Erstelle PR via `gh pr create` wenn alle kritischen Issues behoben sind
