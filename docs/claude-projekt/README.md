# Claude-Projekt einrichten

Zwei Dateien ergeben ein Projekt in claude.ai:

| Datei | Wohin in claude.ai |
|---|---|
| `anweisung.md` (Text unterhalb der ersten `---`-Linie) | Projekt → **Anweisungen festlegen** |
| `kontext.md` | Projekt → **Dateien hinzufügen** (Projektwissen) |

Schritte:

1. In claude.ai **Projekte → Neues Projekt**, Name z. B. „Work-Time-Manager".
2. Beschreibung: „Arbeitszeit-App (Flutter, Angular, .NET, Firebase) — Planung, Review, Architekturfragen."
3. Den Anweisungstext einfügen, `kontext.md` hochladen.
4. Optional zusätzlich hochladen, je nach Aufgabe: `CLAUDE.md` (Root), `server/CLAUDE.md`,
   `mobile/CLAUDE.md`, `web/CLAUDE.md`, `CONTRIBUTING.md`, `RELEASE_NAMES.md`. Diese Dateien sind die
   Quelle der Wahrheit; `kontext.md` ist die kompakte Zusammenfassung.

Pflege: Ändern sich Architektur, Endpunkte oder Ablauf, `kontext.md` (Stand-Datum oben) aktualisieren
und im Projekt neu hochladen. Für Arbeit direkt am Code ist Claude Code mit `CLAUDE.md` der bessere Weg;
das Claude-Projekt ist für Planung, Design, Reviews und Texte gedacht.
