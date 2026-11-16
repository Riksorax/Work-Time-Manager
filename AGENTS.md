# AGENTS.md

Einstieg für Coding-Agenten, die keine `CLAUDE.md` einlesen (z. B. Gemini/Antigravity, Codex). Die Regeln dieses
Repos stehen in den `CLAUDE.md`-Dateien; diese Datei wiederholt sie nicht, sondern sagt, welche zu lesen ist.
**Lies die genannten Dateien vollständig, bevor du etwas änderst.**

| Arbeit an | Zuerst lesen |
|---|---|
| allem | `CLAUDE.md` (Aufbau des Repos, Checks je Plattform, übergreifende Regeln) und `CONTRIBUTING.md` (Branches, Commits, PRs) |
| `mobile/` (Flutter-App) | `mobile/CLAUDE.md` |
| `web/` (Angular, Cloud Functions) | `web/CLAUDE.md` |
| `server/` (.NET-Backend) | `server/CLAUDE.md` |
| `marketing/shorts/` (Kurzvideos) | `marketing/shorts/CLAUDE.md`, `marketing/shorts/README.md` und in `mobile/CLAUDE.md` den Abschnitt „App-Bilder für Kurzvideos (#575)“ |

Was in den `CLAUDE.md`-Dateien nur für Claude Code gilt (Slash-Befehle wie `/issue`, Subagents, Hooks, Skills unter
`.claude/`), kannst du überspringen. Alles Fachliche gilt für jeden Agenten: Regeln, Checks, Entscheidungen des
Repo-Inhabers.

## Für alle Aufgaben

- Sprache im Repo: Deutsch (Doku, Commit-Nachrichten, Issue- und PR-Texte).
- PRs gehen gegen `develop`, nie direkt nach `main` (ein Push auf `main` deployt). Nicht mergen, nicht pushen und
  keinen PR anlegen, ohne dass der Repo-Inhaber es verlangt.
- Vor der Übergabe die Checks der betroffenen Plattform ausführen (Tabelle in `CLAUDE.md`) und ehrlich berichten:
  was ausgeführt wurde, was nicht, was fehlgeschlagen ist.
- Tests dürfen nicht von Datum, Wochentag oder Zeitzone abhängen.

## Kurzvideos (`marketing/shorts/`)

Die Anleitung ist `marketing/shorts/CLAUDE.md`: abgenommene Vorlage, verbindliche Entscheidungen, Ablauf in Schritten,
Prüfliste, Lehren aus verworfenen Fassungen. Übersicht und offene Videos: Issue #575.

Einrichtung auf einem eigenen Rechner (einmalig; Flutter, Node 20 oder neuer und `ffmpeg` müssen installiert sein):

```bash
cd mobile && flutter pub get
cd ../marketing/shorts && npm ci
python3 -m venv tts/.venv-omnivoice
tts/.venv-omnivoice/bin/pip install --extra-index-url https://download.pytorch.org/whl/cpu -r tts/requirements-omnivoice.txt
```

Unter Windows liegt das Python der Umgebung unter `tts\\.venv-omnivoice\\Scripts\\python.exe` (statt `bin/python`) und
`pip` entsprechend unter `Scripts\\pip.exe`; `render.mjs` findet beide Lagen von selbst. Die Pipeline ist bisher nur
unter Linux gelaufen.

Der erste Lauf lädt das Stimmmodell (rund 3 GB). Ohne Grafikkarte braucht die Stimme etwa eine Minute je Satz, auf
langsameren Rechnern deutlich mehr; den Fortschritt zeigen die Dateien unter `out/<id>/stimme/`. Remotion braucht einen Chromium: entweder den Pfad in
`SHORTS_CHROMIUM` angeben oder Remotion beim ersten Lauf selbst einen laden lassen.

```bash
cd marketing/shorts
npm test                               # Schema, Zeitplan, Layout
npm run render -- feierabend-rechnen   # die abgenommene Vorlage -> out/feierabend-rechnen.mp4
cd ../../mobile && flutter test tool/shorts_sequences   # Bildfolgen aus der echten App (braucht ffmpeg)
```

Bestehende Videos zum Vergleich: `feierabend-rechnen` (Vorlage), `feierabend`, `pausen`, `pausen-lang`
(`marketing/shorts/videos/de/`).

**Prüfen des Ergebnisses:** Die Prüfliste in `marketing/shorts/CLAUDE.md` geht davon aus, dass der Agent ein Video
weder abspielen noch anhören kann, und prüft deshalb an Einzelbildern, Messwerten und per Spracherkennung. Kannst du
Video und Ton direkt auswerten, tu das zusätzlich und berichte gesondert, was du in Bewegung gesehen und gehört hast:
Tempo, Übergänge, Aussprache (besonders Uhrzeiten und Zahlen), ob Tipp und Wort zusammenfallen. Die Prüfliste
ersetzt das nicht.

Nicht eingecheckt wird `marketing/shorts/out/` (fertige Videos, Ton). Eingecheckt werden die Videobeschreibung
(`videos/de/<id>.yaml`), die Bildfolge (`frames/de/<name>.mp4` und `.json`) und Code.
