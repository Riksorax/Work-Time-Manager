# Sprachsynthese: Lizenzen und Ergebnis des Hörtests (#575, S0)

Abgerufen am 15.11.2026. Die Videos sind Werbung; Programm und Stimmmodell müssen gewerbliche Nutzung erlauben.

| Kandidat | Programm | Stimmmodell | Gewerblich nutzbar | Quelle |
|---|---|---|---|---|
| Piper 1.8.0, Stimme „Thorsten“ (high) | GPL-3.0-or-later | CC0 | ja | PyPI-Metadaten `piper-tts`; `MODEL_CARD` unter `huggingface.co/rhasspy/piper-voices`, `de/de_DE/thorsten/high` |
| Piper, „Thorsten emotional“ (medium, 8 Stimmungen) | wie oben | CC0 | ja | `de/de_DE/thorsten_emotional/medium/MODEL_CARD` |
| Piper, „Kerstin“ (low) | wie oben | CC0 | ja | `de/de_DE/kerstin/low/MODEL_CARD` |
| Chatterbox Multilingual 0.1.7 | MIT | MIT | ja | PyPI-Metadaten `chatterbox-tts`; Modellkarte `huggingface.co/ResembleAI/chatterbox` |
| Qwen3-TTS 1.7B (VoiceDesign, CustomVoice, Base) und Tokenizer | Apache-2.0 (`github.com/QwenLM/Qwen3-TTS`, Datei `LICENSE`) | Apache-2.0 (Metadatenfeld der Modellkarten; die Modellkarten enthalten keinen einschränkenden Lizenz- oder Nutzungsabschnitt, am 17.11.2026 vollständig durchsucht) | ja | Modellkarten `huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-{VoiceDesign,Base,CustomVoice}` und `Qwen3-TTS-Tokenizer-12Hz` |
| **OmniVoice 0.2.1** (Standard-Engine der App „VoiceStudio“) | Apache-2.0 | **CC-BY-NC** (Modellkarte, Abschnitt „License“: „The pre-trained model is licensed under the CC-BY-NC due to constraints from its training data (e.g., Emilia)“); der enthaltene Audio-Tokenizer zusätzlich unter der „Boson Higgs Audio 2 Community License“ | **nein** (nur nicht-kommerziell) | `huggingface.co/k2-fsa/OmniVoice`, README, Abschnitt „License“, gelesen am 17.11.2026; PyPI-Metadaten `omnivoice` |

Hinweise:

- Piper steht unter der GPL. Die Pipeline ruft Piper als eigenes Programm auf (`python -m piper`) und liefert es nicht
  mit aus; die erzeugten Tondateien fallen nicht unter die GPL. Piper-Code wird nicht in dieses Repo kopiert.
- Chatterbox versieht jede Ausgabe mit einem unhörbaren Wasserzeichen (Perth), das sie als KI-erzeugt kennzeichnet.
- **Korrektur vom 17.11.2026 (Hinweis des Repo-Inhabers):** OmniVoice ist für Werbung nicht nutzbar. Die Modellkarte
  nennt im Abschnitt „License“ am Ende der Seite CC-BY-NC für das vortrainierte Modell. Die erste Fassung dieser
  Tabelle (15.11.2026) nannte „Modellkarte ohne Lizenzangabe“ und „ja, mit Auflagen“; das war falsch: Geprüft worden
  waren nur das Metadatenfeld `license` der Modellkarte (leer), die Apache-Lizenz des Programms und die Lizenz des
  Audio-Tokenizers, nicht der Text der Modellkarte bis zum Ende. Auch das Lizenzverzeichnis von VoiceStudio führt
  OmniVoice als nicht-kommerziell.
- **Folge:** Videos mit OmniVoice-Stimme werden nicht veröffentlicht. Das gilt für alle bis zum 17.11.2026 gerenderten
  Videos (`feierabend`, `feierabend-rechnen`, `pausen`, `pausen-lang`, `ueberstunden`, `prognose`) und für die
  Stimmvorlagen unter `referenz/omnivoice-*.wav` (selbst OmniVoice-Ausgaben; nicht als Vorlage für eine andere
  Engine verwenden). Bild, Bildfolgen und Sprechtexte sind davon nicht betroffen; nur die Tonspur muss neu entstehen.
- **Regel für jede künftige Engine:** die Modellkarte und das README des Programms vollständig lesen (Abschnitte
  „License“, „Disclaimer“, Angaben zu Trainingsdaten), nicht nur das Metadatenfeld. Lizenz des Programms und Lizenz
  der Gewichte getrennt notieren, mit wörtlichem Zitat und Datum.
- VoiceStudio (debpalash/VoiceStudio, AGPL-3.0) ist eine Desktop-App, die mehrere Engines bündelt. Getestet wurde
  nicht die App, sondern ihre Standard-Engine OmniVoice direkt.
- Nicht geprüft und nicht verwendet: XTTS-v2 und F5-TTS (laut Plan wegen Lizenzen „nur nicht-kommerziell“ ausgeschlossen;
  vor einer späteren Aufnahme selbst nachlesen).

## Messwerte (4 Kerne, ohne Grafikkarte, Testtext `hoertest.txt`, ca. 20 s Ton)

| Probe | Rechenzeit | Rücklesen per Spracherkennung (Whisper „small“) |
|---|---|---|
| `piper-thorsten-high` | 7 s | fehlerfrei bis auf ein eingefügtes „von“ vor „45“ (am Ohr prüfen) |
| `piper-thorsten-emotional-neutral` / `-amused` | 2 s | „live“ wird deutsch gesprochen („liebe“), „Tippen“ undeutlich |
| `piper-kerstin-low` | 2 s | „live“ wird deutsch gesprochen; 16 kHz, hörbar dumpfer |
| `chatterbox-standardstimme` | 75–85 s | zwei Läufe, zwei Ergebnisse: einmal mit eingefügten englischen Wörtern und doppeltem Schluss, einmal sauber |
| `chatterbox-vorlage-thorsten` | 108 s | ein eingefügtes Wort nach dem ersten Satz, sonst sauber |
| `qwen-design-mann` / `-frau` | 120–220 s | fehlerfrei |
| `qwen-sprecher-ryan` / `-serena` | 100–130 s | mehrere Aussprachefehler (mitgelieferte Sprecher sind nicht deutsch) |
| `omnivoice-mann` / `-frau` / `-mann-tief` | 110 s | fehlerfrei |

Folgen für die Pipeline, unabhängig von der Wahl:

- Chatterbox ist nicht deterministisch und fügt gelegentlich Wörter ein. Wird es gewählt, liest die Pipeline jeden Satz
  per Spracherkennung zurück und erzeugt ihn bei Abweichung neu.
- Englische Wörter, die eine Stimme deutsch ausspricht (z. B. „live“), kommen in `aussprache.yaml`
  (Regeln je Stimme erst anlegen, wenn die Stimme feststeht).

## Entscheidung

- 15.11.2026, Repo-Inhaber: Piper und Chatterbox klingen nicht gut genug; OmniVoice war die beste Stimme.
- 16.11.2026: Männerstimme (`omnivoice-mann`).
- **17.11.2026: OmniVoice scheidet wegen der Lizenz (CC-BY-NC) aus.** Eine neue Stimme ist offen. Kandidaten mit
  Lizenz für gewerbliche Nutzung: Qwen3-TTS (Apache-2.0; im Hörtest fehlerfrei, Stimmentwurf einmal erzeugen und
  danach mit dem Base-Modell als feste Vorlage klonen), ein bezahlter Dienst mit gewerblicher Lizenz, oder selbst
  einsprechen (`videos/de/<id>/stimme/<nr>.wav`). Bis zur Entscheidung bleibt `einstellungen.yaml` unverändert, damit
  die Pipeline lauffähig ist; ihre Ausgabe ist nur für die interne Abnahme von Bild und Tempo.
