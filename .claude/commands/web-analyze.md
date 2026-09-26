# /web-analyze — Phase 1: Flutter-Feature für Web-Port analysieren

Issue: $ARGUMENTS

Starte den Subagent `web-analyst` (Agent-Tool, `subagent_type: web-analyst`) mit diesem Auftrag:

> Issue #$ARGUMENTS in `Riksorax/Work-Time-Manager` lesen (GitHub-MCP `issue_read`, lokal
> `gh issue view $ARGUMENTS --comments`). Feature-Ordner festlegen (`web/src/app/features/<feature>/`)
> und oben in die Research-Datei eintragen. Relevante Flutter-Quellen lesen
> (`mobile/lib/presentation/screens|view_models/`, `domain/entities|services/`,
> `data/repositories/`), Flutter → Angular-Mapping erstellen, alle UI-States
> (loading / data / empty / error / premium-locked) und Web-Spezifika erfassen, offene Fragen
> und Risiken listen. Ergebnis: `web/thoughts/$ARGUMENTS-research.md`. Kein Code.

Danach in der Hauptsession: offene Fragen dem Nutzer stellen, Antworten in der Research-Datei
ergänzen. Nächster Schritt: `/web-design $ARGUMENTS`.
