# Sprachsynthese: Lizenzen und Ergebnis des Hörtests (#575, S0)

Abgerufen am 15.11.2026. Die Videos sind Werbung; Programm und Stimmmodell müssen gewerbliche Nutzung erlauben.

| Kandidat | Programm | Stimmmodell | Gewerblich nutzbar | Quelle |
|---|---|---|---|---|
| Piper 1.8.0, Stimme „Thorsten“ (high) | GPL-3.0-or-later | CC0 | ja | PyPI-Metadaten `piper-tts`; `MODEL_CARD` unter `huggingface.co/rhasspy/piper-voices`, `de/de_DE/thorsten/high` |
| Piper, „Thorsten emotional“ (medium, 8 Stimmungen) | wie oben | CC0 | ja | `de/de_DE/thorsten_emotional/medium/MODEL_CARD` |
| Piper, „Kerstin“ (low) | wie oben | CC0 | ja | `de/de_DE/kerstin/low/MODEL_CARD` |
| Chatterbox Multilingual 0.1.7 | MIT | MIT | ja | PyPI-Metadaten `chatterbox-tts`; Modellkarte `huggingface.co/ResembleAI/chatterbox` |
| Qwen3-TTS 1.7B (VoiceDesign, CustomVoice) | Apache-2.0 | Apache-2.0 | ja | Modellkarten `huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-*` |
| **OmniVoice 0.2.1** (Standard-Engine der App „VoiceStudio“) | Apache-2.0 | Modellkarte ohne Lizenzangabe; der enthaltene Audio-Tokenizer steht unter der „Boson Higgs Audio 2 Community License“ | ja, mit Auflagen (siehe unten) | PyPI-Metadaten `omnivoice`; `huggingface.co/k2-fsa/OmniVoice`, Datei `audio_tokenizer/LICENSE` |

Hinweise:

- Piper steht unter der GPL. Die Pipeline ruft Piper als eigenes Programm auf (`python -m piper`) und liefert es nicht
  mit aus; die erzeugten Tondateien fallen nicht unter die GPL. Piper-Code wird nicht in dieses Repo kopiert.
- Chatterbox versieht jede Ausgabe mit einem unhörbaren Wasserzeichen (Perth), das sie als KI-erzeugt kennzeichnet.
- OmniVoice, Lizenz des Audio-Tokenizers (gelesen am 15.11.2026): Nutzung, auch gewerblich, ist gebührenfrei erlaubt.
  Ab mehr als 100.000 jährlich aktiven Nutzern der eigenen Produkte braucht es eine erweiterte Lizenz von Boson AI
  (Abschnitt 2). Wer das Modell oder ein Produkt, das es verwendet, weitergibt, muss die Lizenz beilegen und einen
  Herkunftshinweis zeigen (Abschnitt 1.b.i); dieses Repo gibt das Modell nicht weiter, es wird beim ersten Lauf von
  Hugging Face geladen. Ausgaben dürfen nicht zum Verbessern anderer Sprachmodelle dienen. Das ist eine Lesart des
  Lizenztexts, keine Rechtsberatung; die Modellkarte selbst nennt keine Lizenz für die Gewichte.
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

15.11.2026, Repo-Inhaber: Piper und Chatterbox klingen nicht gut genug; **OmniVoice** ist bisher die beste Stimme.
Offen ist, welche der drei OmniVoice-Stimmen (Mann, Frau, Mann tief) es wird.

Umsetzung: Ein Stimmentwurf per Beschreibung fällt bei jedem Lauf anders aus. Deshalb liegt je Stimme eine kurze
Vorlage (ca. 6 s, die ersten beiden Sätze der Hörprobe) unter `referenz/`, und `synth.py` erzeugt jeden Satz als Klon
dieser Vorlage. Vier Sätze brauchen ohne Grafikkarte rund 3 Minuten; mit der ungekürzten 21-s-Vorlage waren es 8,5.
