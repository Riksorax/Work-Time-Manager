# /mobile-plan — Phase 2: Mobile-Implementierungsplan erstellen

Issue: $ARGUMENTS

Voraussetzung: `mobile/thoughts/$ARGUMENTS-research.md` existiert und ihre offenen Fragen sind
beantwortet. Falls nicht: zuerst `/mobile-analyze $ARGUMENTS`.

Starte den Subagent `mobile-planner` (Agent-Tool, `subagent_type: mobile-planner`) mit diesem Auftrag:

> Aus `mobile/thoughts/$ARGUMENTS-research.md` den TDD-Plan erstellen: Architektur-Entscheidungen
> (Tabelle im Agenten), alle neuen/geänderten Dateien mit Pfad, Schritte in Layer-Reihenfolge,
> jeder Schritt beginnt mit dem Test. Ergebnis: `mobile/thoughts/$ARGUMENTS-plan.md`. Kein Code.

Danach in der Hauptsession: Den Nutzer den Plan freigeben lassen (Pfad nennen, nicht den ganzen
Plan ausgeben). Nächster Schritt: `/mobile-implement $ARGUMENTS`.
