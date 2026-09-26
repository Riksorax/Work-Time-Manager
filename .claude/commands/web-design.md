# /web-design — Phase 2: Web-UI entwerfen

Issue: $ARGUMENTS

Voraussetzung: `web/thoughts/$ARGUMENTS-research.md` existiert. Falls nicht: `/web-analyze $ARGUMENTS`.

Starte den Subagent `web-ui-designer` (Agent-Tool, `subagent_type: web-ui-designer`) mit diesem Auftrag:

> Für Issue #$ARGUMENTS das Flutter-UI laut `web/thoughts/$ARGUMENTS-research.md` nach Angular
> portieren: alle UI-States, responsive (Mobile / Tablet / Desktop), Texte als ngx-translate-Keys
> (de + en), Angular Material. Stitch API versuchen; sie antwortet aktuell mit HTTP 405 — dann
> manuell nach der Flutter-Vorlage bauen. Accessibility-Checkliste prüfen.
> Ergebnis: HTML + SCSS in `web/src/app/features/<feature>/` (Ordner laut Research-Datei) und
> `web/thoughts/$ARGUMENTS-ui-report.md`.

Nächster Schritt: `/web-plan $ARGUMENTS`.
