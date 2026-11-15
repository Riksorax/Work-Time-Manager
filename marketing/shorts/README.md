# Video-Shorts

Pipeline für Kurzvideos (TikTok, Reels, Shorts) aus echten App-Bildschirmen und synthetischer Sprecherstimme.
Plan, Regeln und Reihenfolge: Issue #575 und `thoughts/video-shorts-plan.md`.

Stand: Schritt S0 (Hörtest der Stimmen) und S1 (Videokomposition, Grundgerüst). Die Stimme ist noch nicht gewählt,
bis dahin spricht Piper `de_DE-thorsten-high`. Echte Videos folgen ab S3.

## Video rendern

```bash
cd marketing/shorts
npm ci
npm run render -- probe        # videos/de/probe.yaml -> out/probe.mp4
npm test                       # Schema, Zeitberechnung, Lage der Bausteine (node --test)
```

Voraussetzungen: Node 20 oder neuer, `ffmpeg` im Pfad, ein Python mit `piper-tts` und `pyyaml` (die Umgebung
`tts/.venv-piper` aus dem Hörtest wird von selbst gefunden, sonst `SHORTS_PYTHON=/pfad/zu/python`) und die
Piper-Stimme unter `tts/stimmen/` (lädt `python hoertest.py piper`). Als Browser dient das vorinstallierte Chromium
der Cloud-Umgebung (`/opt/pw-browsers/chromium`) oder der Pfad in `SHORTS_CHROMIUM`; fehlt beides, lädt Remotion
beim ersten Lauf selbst einen Browser.

Ergebnis: MP4 mit 1080 × 1920, 30 Bildern/s, H.264 (`yuv420p`), Ton AAC 48 kHz, Lautheit −14 LUFS. Das Probevideo
(19 s) rendert in der Cloud-Umgebung in etwa zwei Minuten. Zwischendateien liegen unter `out/<id>/`.

Ablauf von `render.mjs`:

1. Videobeschreibung lesen und prüfen (`lib/schema.mjs`). Fehler brechen ab, es wird nichts gerendert.
2. Stimme: `tts/synth.py` schreibt je Satz eine WAV-Datei nach `out/<id>/stimme/` und die Längen nach `dauer.json`.
3. Zeitplan aus den Satzlängen (`lib/zeit.mjs`): Die Länge des Tons bestimmt die Dauer jeder Szene.
4. Tonspur mit ffmpeg (`lib/ton.mjs`): Sätze an ihre Startzeit, optional Musik darunter, Lautheit einstellen.
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

Eine Datei je Video. `videos/de/probe.yaml` zeigt jeden Baustein einmal. Unbekannte Felder, ein fehlendes Bild und
ein Satz ohne Ton sind Fehler.

```yaml
id: feierabend                # wie der Dateiname
titel: Wann ist Feierabend?   # optional, nur zur Orientierung
musik: ruhig.mp3              # optional, Datei aus musik/; fehlt sie, entsteht das Video ohne Musik
ausschnitte:                  # benannte Rechtecke im App-Bild, Anteil von Breite und Höhe (0 bis 1)
  timer: { x: 0.1, y: 0.2, breite: 0.8, hoehe: 0.15 }
szenen:
  - art: aufhaenger
    text: Wann hast du heute eigentlich Feierabend?
    saetze:
      - Wann hast du heute eigentlich Feierabend?
  - art: app
    bild: dashboard_timer_laeuft.png
    zoom: { auf: timer, faktor: 1.3 }
    saetze:
      - Die App zeigt dir, dass du um 16:40 Uhr fertig bist.
  - art: schluss
```

Felder aller Szenen:

| Feld | Bedeutung |
|---|---|
| `art` | `aufhaenger`, `app`, `teaser` oder `schluss` |
| `saetze` | Liste der gesprochenen Sätze. Je Eintrag eine Tondatei und ein Untertitel; der Untertitel zeigt den Text wie geschrieben („16:40 Uhr“), die Stimme bekommt den Sprechtext aus `tts/sprechtext.py` |
| `dauer` | Sekunden. Pflicht, wenn die Szene keinen Satz hat (außer `schluss`), sonst Mindestdauer |
| `untertitel` | `true`/`false`. Standard: an bei `app` und `teaser`, aus bei `aufhaenger` und `schluss` (dort steht der Text schon groß im Bild) |

Felder je Art:

| Art | Feld | Bedeutung |
|---|---|---|
| `aufhaenger` | `text` (Pflicht) | Frage oder Problem in großer Schrift |
| `app` | `bild` (Pflicht) | PNG-Dateiname aus `frames/de/` |
| `app` | `zoom: { auf, faktor }` | langsamer Zoom auf den Ausschnitt `auf`; `faktor` 1 bis 2.5, Standard 1.25 |
| `app` | `tipp: { auf, bei }` | Tipp-Markierung in der Mitte des Ausschnitts; `bei` ist der Zeitpunkt als Anteil der Szenendauer, Standard 0.5 |
| `app` | `einblendung` | Text über dem App-Bild, höchstens 44 Zeichen |
| `app` | `premium` | `true` zeigt das Premium-Kennzeichen (Pflicht bei Premium-Funktionen, Regel 2 im Plan) |
| `teaser` | `text` (Pflicht) | Text unter dem Schild „Kommt bald“; kein Datum, keine Oberfläche der neuen Funktion |
| `schluss` | – | Logo, „Kostenlos bei Google Play“, `work-time-manager.app`; ohne Satz 2,5 s |

Zeit: Jede Szene mit Sätzen dauert Vorlauf + Sätze mit Pause dazwischen + Nachlauf. Die Werte dazu, Bildrate,
Zeilenlänge der Untertitel, Lautheit und Musikpegel stehen in `einstellungen.yaml`. Untertitel haben höchstens zwei
Zeilen; ein längerer Satz wird in mehrere Teile geteilt, die nacheinander erscheinen.

Bild: Das App-Bild steht als Karte (78 % Breite, runde Ecken, Schatten) auf Markengrund. Oben 250 px und unten
420 px bleiben frei von wichtigem Text (Schutzzonen); die Karte ragt unten hinein, der Untertitel liegt darüber.
Maße: `src/layout.mjs`. Farben, Schrift und Logo liest `lib/marke.mjs` aus `branding/src/` und
`mobile/assets/fonts/`; sie sind hier nicht noch einmal festgelegt. Feste Texte der Bausteine: `src/texte.mjs`.

### Stimme

```bash
python tts/synth.py videos/de/probe.yaml      # macht `npm run render` von selbst
```

- Engine und Stimme stehen in `einstellungen.yaml` unter `stimme:` (oder `--engine`, `--stimme`). Standard bis zur
  Wahl im Hörtest: Piper `de_DE-thorsten-high`. `chatterbox` ist als zweite Engine angelegt.
- Die Sätze werden über alle Szenen durchnummeriert (`01.wav`, `02.wav`, …).
- Eigene Aufnahme oder anderer Dienst: Liegt `videos/de/<id>/stimme/<nr>.wav` (PCM-WAV), wird diese Datei genommen
  statt synthetisiert; ihre Länge bestimmt die Szenendauer.
- Unveränderte Sätze werden beim nächsten Lauf nicht neu vertont.

### Musik

Optional: Datei mit Lizenz für gewerbliche Nutzung nach `musik/` legen (Quelle und Lizenz in einer Textdatei
daneben) und in der Videobeschreibung unter `musik:` nennen. Sie läuft leiser unter der Stimme (`musik_db`), wird
bei Bedarf wiederholt und am Ende ausgeblendet.

### Platzhalterbild

`frames/de/platzhalter.png` gehört zum Probevideo und ist kein App-Bild. Neu erzeugen: `npm run platzhalter`.
Die echten App-Bilder schreibt `flutter test tool/shorts_frames` (aus `mobile/`) nach `frames/de/`.

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

- `hoertest.txt`: der Testtext, so wie er später im Untertitel stünde.
- `aussprache.yaml` + `sprechtext.py`: schreiben Uhrzeiten, Salden und Zahlen für die Stimme aus.
- `LIZENZEN.md`: Lizenzen der Kandidaten, Messwerte und Auffälligkeiten.
