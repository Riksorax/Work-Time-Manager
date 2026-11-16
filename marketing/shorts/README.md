# Video-Shorts

Pipeline für Kurzvideos (TikTok, Reels, Shorts) aus echten App-Bildschirmen und synthetischer Sprecherstimme.
Plan, Regeln und Reihenfolge: Issue #575 und `thoughts/video-shorts-plan.md`.

Stand: S0 (Hörtest der Stimmen), S1 (Videokomposition) und S2 (App-Bilder) sind umgesetzt. Die Stimme kommt von
OmniVoice (Ergebnis des Hörtests, siehe `tts/LIZENZEN.md`).

## Video rendern

```bash
cd marketing/shorts
npm ci
npm run render -- probe        # videos/de/probe.yaml -> out/probe.mp4
npm test                       # Schema, Zeitberechnung, Lage der Bausteine, Tonmischung (node --test)
```

Voraussetzungen: Node 20 oder neuer, `ffmpeg` im Pfad, ein Python mit der gewählten Engine und `pyyaml`
(`tts/.venv-omnivoice` bzw. `tts/.venv-piper` werden von selbst gefunden, sonst `SHORTS_PYTHON=/pfad/zu/python`).
OmniVoice einrichten: `python3 -m venv tts/.venv-omnivoice && tts/.venv-omnivoice/bin/pip install --extra-index-url
https://download.pytorch.org/whl/cpu -r tts/requirements-omnivoice.txt`; das Modell (ca. 3 GB) lädt der erste Lauf. Als Browser dient das vorinstallierte Chromium
der Cloud-Umgebung (`/opt/pw-browsers/chromium`) oder der Pfad in `SHORTS_CHROMIUM`; fehlt beides, lädt Remotion
beim ersten Lauf selbst einen Browser.

Ergebnis: MP4 mit 1080 × 1920, 30 Bildern/s, H.264 (`yuv420p`), Ton AAC 48 kHz, Lautheit −14 LUFS. Ein Video von
12 s rendert in der Cloud-Umgebung in etwa vier Minuten (ohne Sprachsynthese). Zwischendateien liegen unter
`out/<id>/`. Untertitel gibt es nicht (Entscheidung vom 16.11.2026, für alle Shorts); die Kernaussage steht als
Hervorhebung groß im Bild.

Ablauf von `render.mjs`:

1. Videobeschreibung lesen und prüfen (`lib/schema.mjs`). Fehler brechen ab, es wird nichts gerendert.
2. Stimme: `tts/synth.py` schreibt je Satz eine WAV-Datei nach `out/<id>/stimme/`, schneidet die Stille am Anfang
   und Ende ab und schreibt die Längen nach `dauer.json`.
3. Zeitplan aus den Satzlängen (`lib/zeit.mjs`): Die Länge des Tons bestimmt die Dauer jeder Szene.
4. Tonspur mit ffmpeg (`lib/ton.mjs`): Sätze an ihre Startzeit, ein Klick je Tipp, optional Musik darunter,
   Lautheit einstellen.
5. Bild mit Remotion (`src/`), danach Bild und Ton verbinden.

### Werkzeug: Remotion

Entscheidung am 15.11.2026: Remotion **4.0.543** (exakt gepinnt, wie resvg in `branding/`). Beide Bedingungen aus
dem Plan sind erfüllt:

- **Lizenz:** Die „Free License“ erlaubt die Nutzung ohne Kosten, auch gewerblich, für Einzelpersonen,
  gewinnorientierte Organisationen mit höchstens 3 Beschäftigten und gemeinnützige Organisationen, zum Erstellen
  von Videos und Bildern. Nicht erlaubt ist, ein eigenes Remotion-Derivat zu verkaufen oder zu lizenzieren. Quelle:
  <https://github.com/remotion-dev/remotion/blob/main/LICENSE.md>, abgerufen am 15.11.2026. Der Text kündigt für
  Remotion 5.0 eine Änderung an; vor einem Wechsel der Hauptversion und sobald mehr als 3 Personen beschäftigt
  sind, neu prüfen (dann ist eine „Company License“ nötig).
- **Lauffähigkeit:** Ein 2-Sekunden-Probevideo rendert in der Cloud-Umgebung mit dem vorinstallierten Chromium
  (`chromeMode: chrome-for-testing`), ohne Browser-Download.

Die im Plan genannte Ausweichlösung (HTML-Seite, Bild für Bild mit Playwright, ffmpeg) ist deshalb nicht gebaut.
Sollte sie nötig werden: Videobeschreibung, Prüfung, Zeitplan und Tonspur (`lib/`, `tts/`) hängen nicht an
Remotion, nur `src/` und der Renderaufruf in `render.mjs`.

### Videobeschreibung (`videos/de/<id>.yaml`)

Eine Datei je Video. `videos/de/probe.yaml` zeigt jeden Baustein einmal. Unbekannte Felder, ein fehlendes Bild, eine
fehlende Folge und ein Satz ohne Ton sind Fehler.

```yaml
id: feierabend                # wie der Dateiname
titel: Wann ist Feierabend?   # optional, nur zur Orientierung
musik: ruhig.mp3              # optional, Datei aus musik/; fehlt sie, entsteht das Video ohne Musik
ausschnitte:                  # benannte Rechtecke im App-Bild, Anteil von Breite und Höhe (0 bis 1)
  oben: { x: 0.1, y: 0.1, breite: 0.8, hoehe: 0.4 }
szenen:
  - art: app                  # App ab dem ersten Bild, die Frage liegt darüber
    folge: start_morgens
    bis: 0
    aufhaenger: Wann hast du heute eigentlich Feierabend?
    saetze:
      - Wann hast du heute eigentlich Feierabend?
  - art: app                  # dieselbe Folge läuft weiter, kein Übergang
    folge: start_morgens
    zoom: { auf: start_knopf, faktor: 1.0 }
    tipp: { auf: start_knopf }
    saetze:
      - Morgens einmal auf Start tippen.
  - art: app
    folge: start_morgens
    zoom: { auf: oben, faktor: 1.1 }
    hervorhebung: { auf: feierabend_zeile, zeile: Feierabend heute, wert: "16:22 Uhr" }
    saetze:
      - Die App sagt dir sofort, wann du fertig bist. Heute um 16:22 Uhr.
  - art: schluss
    saetze:
      - Work Time Manager. Kostenlos bei Google Play.
```

Felder aller Szenen:

| Feld | Bedeutung |
|---|---|
| `art` | `app`, `schluss`, `teaser` oder `aufhaenger` |
| `saetze` | Liste der gesprochenen Sätze, je Eintrag eine Tondatei. Geschrieben wie gelesen („16:40 Uhr“); die Stimme bekommt den Sprechtext aus `tts/sprechtext.py` |
| `dauer` | Sekunden. Pflicht, wenn die Szene keinen Satz hat (außer `schluss`), sonst Mindestdauer |

Felder je Art:

| Art | Feld | Bedeutung |
|---|---|---|
| `app` | `bild` oder `folge` (genau eines) | `bild`: PNG-Dateiname aus `frames/de/`. `folge`: Name einer Bildfolge, siehe unten |
| `app` | `ab`, `bis` | nur mit `folge`: gezeigter Abschnitt, je eine Bildnummer (ab 0) oder der Name einer Marke. Ohne `ab` beginnt die Folge bei Bild 0 bzw. setzt dort fort, wo die Szene davor mit derselben Folge aufgehört hat. Ohne `bis` läuft sie bis zum letzten Bild. Ist die Szene länger als der Abschnitt, bleibt das letzte Bild stehen (`bis: 0` = Standbild des ersten Bilds) |
| `app` | `zoom: { auf, faktor, dauer }` | Kamerafahrt auf den Ausschnitt `auf`; `faktor` 1 bis 2.5 (Standard 1.25), `dauer` der Fahrt in Sekunden (Standard 0.6). Liegt der Ausschnitt sonst in einer Schutzzone (Knopf am unteren Bildrand), rückt das Bild so weit, dass er frei liegt, auch bei `faktor: 1`. Ohne `zoom` zeigt die Szene das Bild in voller Breite |
| `app` | `tipp: { auf, bei }` | Tipp-Markierung in der Mitte des Ausschnitts, dazu ein Klick im Ton. Bei `bild`: `bei` ist der Zeitpunkt als Anteil der Szenendauer (Standard 0.5). Bei `folge`: Der Zeitpunkt ist die Marke `tipp` der Folge; `bei` ist optional und hält das erste Bild so lange an, bis die Marke auf diesen Anteil fällt (früher als von selbst kommt der Tipp nie) |
| `app` | `aufhaenger` | Frage in großer Schrift über dem abgedunkelten, unscharfen App-Bild, höchstens 60 Zeichen. Verschwindet nach dem ersten Satz der Szene. Für die erste Szene: Die App ist ab dem ersten Bild zu sehen |
| `app` | `hervorhebung: { auf, zeile, wert, bei }` | Kernaussage als großes Schild: `zeile` klein (optional, höchstens 28 Zeichen), `wert` sehr groß (höchstens 12 Zeichen, in Anführungszeichen). Der Ausschnitt `auf` bekommt einen Rahmen, das Schild wächst daraus hervor und zeigt mit einer Spitze darauf. Es liegt direkt unter dem Ausschnitt (sonst darüber), nie in einer Schutzzone, und verdeckt dort die App. `bei`: Beginn als Anteil der Szenendauer (Standard 0.2) |
| `app` | `einblendung` | Text über dem App-Bild, höchstens 44 Zeichen; die Karte beginnt dann tiefer. Nicht zusammen mit `aufhaenger` |
| `app` | `premium` | `true` zeigt das Premium-Kennzeichen (Pflicht bei Premium-Funktionen, Regel 2 im Plan) |
| `schluss` | – | Logo auf weißem Träger, „Kostenlos bei Google Play“, `work-time-manager.app`; ohne Satz 2,5 s |
| `teaser` | `text` (Pflicht) | Text unter dem Schild „Kommt bald“; kein Datum, keine Oberfläche der neuen Funktion |
| `aufhaenger` | `text` (Pflicht) | Frage in großer Schrift auf Markengrund, ohne App. Nicht mehr der übliche Einstieg: dafür das Feld `aufhaenger` einer `app`-Szene nehmen |

Ausschnitte: `zoom`, `tipp` und `hervorhebung` nennen einen Ausschnitt per Name. Gesucht wird erst unter
`ausschnitte:` der Videobeschreibung, dann in der Folge der Szene.

#### Bildfolgen

Eine Folge ist ein kurzer, echter Ablauf der App: `frames/de/<name>.mp4` (H.264, 30 Bilder/s, 1080 × 1920, ohne Ton)
und `frames/de/<name>.json`:

```json
{
  "fps": 30,
  "bilder": 216,
  "marken": { "tipp": 45, "gestartet": 51 },
  "ausschnitte": { "start_knopf": { "x": 0.08, "y": 0.86, "breite": 0.84, "hoehe": 0.07 } }
}
```

`fps` muss zur Bildrate des Videos passen, `marken` sind Bildnummern ab 0, `ausschnitte` wie in der
Videobeschreibung. Die Folgen schreibt `flutter test tool/shorts_sequences` (aus `mobile/`). Mehrere Szenen
nacheinander mit derselben Folge (oder demselben Bild) gelten als ein Stück: kein Übergang, das Bild läuft
durch, die Kamera fährt von der Lage der Szene davor weiter. `frames/de/platzhalter_folge.*` gehört zum Probevideo
(`npm run platzhalter-folge`, aus zwei App-Bildern, ohne echte Bewegung).

#### Zeit und Tempo

Jede Szene mit Sätzen dauert Vorlauf + Sätze mit Pause dazwischen + Nachlauf. Die Satz-Dateien sind bis auf
`ton_rest` (50 ms) frei von Stille am Anfang und Ende; zusammen mit `vorlauf`, `nachlauf` und `pause_nach_satz`
liegen zwischen zwei Sätzen im fertigen Video rund 0,3 s Stille. Diese Werte, Bildrate, Lautheit, Musikpegel und
das Tipp-Geräusch (`tipp_ton: false` schaltet es ab) stehen in `einstellungen.yaml`. Nachmessen:
`ffmpeg -i out/<id>.mp4 -af silencedetect=noise=-40dB:d=0.1 -f null -`.

Szenen wechseln mit hartem Schnitt. Eine neue Karte kommt in 5 Bildern herein, nichts blendet aus.

#### Bild und Maße

Leinwand 1080 × 1920. Oben 250 px und unten 420 px sind Schutzzonen (dort liegen die Bedienelemente der
Plattformen); die freie Fläche dazwischen reicht von y = 250 bis 1500.

- **App-Karte:** x 40 bis 1040 (1000 px, 93 % der Breite), y 102 bis 1880, runde Ecken (48 px), Schatten. Ein
  Bild im Format 9:16 passt bei Skala 1 genau hinein. Die Karte ragt oben und unten in die Schutzzonen; Aufhänger,
  Schild, Einblendung, Premium-Kennzeichen und das Ziel jeder Kamerafahrt liegen in der freien Fläche.
- **Kamerafahrt:** Die Mitte des Ausschnitts kommt in die Mitte der freien Fläche (y = 875), soweit das Bild die
  Karte dabei ausfüllt. Ein Ausschnitt hält 40 px Abstand zu den Schutzzonen; dafür darf das Bild über den
  Kartenrahmen hinaus rücken, die Karte endet dann früher.
- **Schild der Hervorhebung:** x 70 bis 1010 (940 px), Zeile 58 px, Zahl bis 210 px (bei „16:22 Uhr“ 166 px,
  Schild 346 px hoch), 36 px unter dem Ausschnitt.
- **Aufhänger:** 88 bis 124 px je nach Länge, mittig in der freien Fläche.
- **Schlusskarte:** Logo 364 px auf weißem Kreis (400 px), Name 88 px, Knopf 60 px, Adresse 54 px.

Maße und Rechenwege: `src/layout.mjs`. `render.mjs` meldet einen Hinweis, wenn Tipp oder Hervorhebung am Ende der
Kamerafahrt in einer Schutzzone liegen. Farben, Schrift und Logo liest `lib/marke.mjs` aus `branding/src/` und
`mobile/assets/fonts/`; sie sind hier nicht noch einmal festgelegt. Feste Texte der Bausteine: `src/texte.mjs`.

### Stimme

```bash
python tts/synth.py videos/de/probe.yaml      # macht `npm run render` von selbst
```

- Engine und Stimme stehen in `einstellungen.yaml` unter `stimme:` (oder `--engine`, `--stimme`). Standard:
  OmniVoice mit einer festen Stimmvorlage aus `tts/referenz/` (`<name>.wav` und `<name>.txt` mit dem gesprochenen
  Text); jeder Satz entsteht als Klon dieser Vorlage, damit die Stimme über alle Videos gleich bleibt. `piper` und
  `chatterbox` bleiben als Engines wählbar. Ohne Grafikkarte braucht OmniVoice knapp eine Minute je Satz.
- Die Sätze werden über alle Szenen durchnummeriert (`01.wav`, `02.wav`, …).
- Eigene Aufnahme oder anderer Dienst: Liegt `videos/de/<id>/stimme/<nr>.wav` (PCM-WAV), wird diese Datei genommen
  statt synthetisiert; ihre Länge bestimmt die Szenendauer.
- Unveränderte Sätze werden beim nächsten Lauf nicht neu vertont.
- Stille am Anfang und Ende jeder Datei (auch einer eigenen Aufnahme) wird bis auf `ton_rest` Sekunden
  abgeschnitten; `dauer.json` trägt die gekürzte Länge. Als Stille gilt alles unter −42 dB zum lautesten Wert.

### Musik

Optional: Datei mit Lizenz für gewerbliche Nutzung nach `musik/` legen (Quelle und Lizenz in einer Textdatei
daneben) und in der Videobeschreibung unter `musik:` nennen. Sie läuft leiser unter der Stimme (`musik_db`), wird
bei Bedarf wiederholt und am Ende ausgeblendet.

### Platzhalter

`frames/de/platzhalter.png` und `frames/de/platzhalter_folge.*` gehören zum Probevideo. Neu erzeugen:
`npm run platzhalter` bzw. `npm run platzhalter-folge` (braucht `dashboard_vor_start.png` und
`dashboard_gestartet.png`). Die echten App-Bilder schreibt `flutter test tool/shorts_frames`, die Bildfolgen
`flutter test tool/shorts_sequences` (beide aus `mobile/`) nach `frames/de/`.

## Hörtest der Stimmen

```bash
cd marketing/shorts/tts
python3 -m venv .venv-piper && .venv-piper/bin/pip install -r requirements-piper.txt
.venv-piper/bin/python hoertest.py piper           # Sekunden
python3 -m venv .venv-cb && .venv-cb/bin/pip install --extra-index-url https://download.pytorch.org/whl/cpu -r requirements-chatterbox.txt
.venv-cb/bin/python hoertest.py chatterbox         # einige Minuten, lädt ca. 3 GB Modelle
.venv-piper/bin/python -m unittest test_sprechtext test_synth
```

Die Proben liegen danach unter `out/hoertest/` (nicht eingecheckt). Getrennte Umgebungen, weil Chatterbox feste
Versionen von PyTorch verlangt.

- `hoertest.txt`: der Testtext in Schreibweise („16:40 Uhr“), nicht als Sprechtext.
- `aussprache.yaml` + `sprechtext.py`: schreiben Uhrzeiten, Salden und Zahlen für die Stimme aus.
- `LIZENZEN.md`: Lizenzen der Kandidaten, Messwerte und Auffälligkeiten.
