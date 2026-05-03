# /web-plan — Phase 3: Angular-Implementierungsplan erstellen

Aktiviere den Web-Planner-Agenten (lies `.claude/agents/web-planner.md` vollständig).

Feature: $ARGUMENTS

## Voraussetzung
Prüfe ob diese Dateien existieren:
- `web/thoughts/$ARGUMENTS-research.md` ✅ (sonst: `/web-analyze $ARGUMENTS`)
- `web/thoughts/$ARGUMENTS-ui-report.md` ✅ (sonst: `/web-design $ARGUMENTS`)

## Aufgabe

1. Lese Research + UI-Report des Features
2. Lese das Flutter-ViewModel für Business-Logic-Details
3. Triff Architektur-Entscheidungen (Hybrid-Service, Signals, Routing, Premium-Gate)
4. Liste **alle** neuen/geänderten Dateien mit vollständigen Pfaden
5. Erstelle Implementierungsschritte in Layer-Reihenfolge (domain → data → features)
   - Jeder Schritt beginnt mit dem Test
6. Skizziere Signal-Design für Service + Component
7. Skizziere Hybrid-Service-Logik (Auth-State-Switch)

Speichere unter: `web/thoughts/$ARGUMENTS-plan.md`

**Kein Code schreiben — nur den Plan.**
