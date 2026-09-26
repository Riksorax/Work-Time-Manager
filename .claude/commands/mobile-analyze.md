# /mobile-analyze — Phase 1: Mobile-Aufgabe analysieren

Aktiviere den Mobile-Analyst-Agenten (lies `.claude/agents/mobile-analyst.md` vollständig).

Issue: $ARGUMENTS

## Aufgabe

1. Lies das GitHub-Issue #$ARGUMENTS inkl. Kommentaren
   (GitHub-MCP `issue_read`, lokal `gh issue view $ARGUMENTS --comments`).
2. Finde alle betroffenen Dateien in `mobile/lib/` und `mobile/test/`.
3. Beschreibe den Datenfluss und bei Bugs die Ursache.
4. Prüfe, ob Web oder Backend mitbetroffen sind.
5. Liste offene Fragen und Risiken.
6. Speichere unter `mobile/thoughts/$ARGUMENTS-research.md`.

**Kein Code schreiben.** Offene Fragen, die die Umsetzung wesentlich ändern, dem Nutzer stellen.
