# /mobile-plan — Phase 2: Mobile-Implementierungsplan erstellen

Aktiviere den Mobile-Planner-Agenten (lies `.claude/agents/mobile-planner.md` vollständig).

Issue: $ARGUMENTS

## Voraussetzung
`mobile/thoughts/$ARGUMENTS-research.md` existiert. Falls nicht: zuerst `/mobile-analyze $ARGUMENTS`.

## Aufgabe
1. Research-Datei lesen.
2. Architektur-Entscheidungen treffen (Tabelle im Agenten).
3. Alle neuen/geänderten Dateien mit Pfad auflisten.
4. Schritte in Layer-Reihenfolge, jeder Schritt beginnt mit dem Test.
5. Speichern unter `mobile/thoughts/$ARGUMENTS-plan.md` und Freigabe einholen.

**Kein Code schreiben — nur den Plan.**
