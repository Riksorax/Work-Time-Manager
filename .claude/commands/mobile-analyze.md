# /mobile-analyze — Phase 1: Mobile-Aufgabe analysieren

Issue: $ARGUMENTS

Starte den Subagent `mobile-analyst` (Agent-Tool, `subagent_type: mobile-analyst`) mit diesem Auftrag:

> Issue #$ARGUMENTS in `Riksorax/Work-Time-Manager` analysieren (GitHub-MCP `issue_read` bzw.
> `gh issue view $ARGUMENTS --comments`). Betroffene Dateien in `mobile/lib/` und `mobile/test/`
> finden, Datenfluss und bei Bugs die Ursache beschreiben, prüfen ob Web oder Backend
> mitbetroffen sind, offene Fragen und Risiken listen.
> Ergebnis: `mobile/thoughts/$ARGUMENTS-research.md`. Kein Code.

Danach in der Hauptsession: Die zurückgegebenen offenen Fragen dem Nutzer stellen und die
Antworten in der Research-Datei ergänzen. Nächster Schritt: `/mobile-plan $ARGUMENTS`.
