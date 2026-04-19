# /web-design — Phase 2: Web-UI mit Stitch API generieren

Aktiviere den Web-UI-Designer-Agenten (lies `.claude/agents/web-ui-designer.md` vollständig).

Feature: $ARGUMENTS

## Voraussetzung
Prüfe ob `web/thoughts/$ARGUMENTS-research.md` existiert. Falls nicht: `/web-analyze $ARGUMENTS` zuerst ausführen.

## Aufgabe

1. Lese Research-Datei: `web/thoughts/$ARGUMENTS-research.md`

2. Erstelle für jeden Screen des Features einen Stitch-API-Prompt:
   - Alle UI-States abdecken (loading / data / empty / error)
   - Responsive Anforderungen (Mobile / Tablet / Desktop)
   - Deutsche Beschriftungen
   - Angular Material Design System

3. Rufe die Stitch API auf:
   ```bash
   curl -s -X POST "https://stitch.withgoogle.com/api/v1/generate" \
     -H "Authorization: Bearer $STITCH_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"prompt": "...", "framework": "angular", "style": "material"}'
   ```

4. Passe das generierte HTML/SCSS für Angular an:
   - Statische Daten → `{{ signal() }}` Bindings
   - CSS-Klassen → Angular Material oder projektspezifisches SCSS
   - Alle `*ngIf` → `@if`, alle `*ngFor` → `@for`
   - `ChangeDetectionStrategy.OnPush` sicherstellen

5. Prüfe Accessibility-Checkliste (aria-labels auf Deutsch, Kontrast, Tab-Reihenfolge)

6. Speichere Dateien:
   - `web/src/app/features/$ARGUMENTS/` — HTML + SCSS Dateien
   - `web/thoughts/$ARGUMENTS-ui-report.md` — UI-Bericht
