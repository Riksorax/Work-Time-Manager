# /web-plan — Phase 3: Angular-Implementierungsplan erstellen

Issue: $ARGUMENTS

Voraussetzung: `web/thoughts/$ARGUMENTS-research.md` (sonst `/web-analyze $ARGUMENTS`) und
`web/thoughts/$ARGUMENTS-ui-report.md` (sonst `/web-design $ARGUMENTS`) existieren.

Starte den Subagent `web-planner` (Agent-Tool, `subagent_type: web-planner`) mit diesem Auftrag:

> Aus Research und UI-Report für Issue #$ARGUMENTS plus dem Flutter-ViewModel den TDD-Plan
> erstellen: Architektur-Entscheidungen (Hybrid-Service, Signals, Routing, Premium-Gate), alle
> neuen/geänderten Dateien mit Pfad, Schritte in Layer-Reihenfolge (jeder beginnt mit dem Test),
> Signal-Design und Hybrid-Service-Logik skizzieren. Ergebnis: `web/thoughts/$ARGUMENTS-plan.md`.
> Kein Code.

Danach in der Hauptsession: Den Nutzer den Plan freigeben lassen (Pfad nennen, nicht den ganzen
Plan ausgeben). Nächster Schritt: `/web-implement $ARGUMENTS`.
