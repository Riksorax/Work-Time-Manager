# Sprachsynthese: Lizenzen und Ergebnis des Hörtests (#575, S0)

Abgerufen am 15.11.2026. Die Videos sind Werbung; Programm und Stimmmodell müssen gewerbliche Nutzung erlauben.

| Kandidat | Programm | Stimmmodell | Gewerblich nutzbar | Quelle |
|---|---|---|---|---|
| Piper 1.8.0, Stimme „Thorsten“ (high) | GPL-3.0-or-later | CC0 | ja | PyPI-Metadaten `piper-tts`; `MODEL_CARD` unter `huggingface.co/rhasspy/piper-voices`, `de/de_DE/thorsten/high` |
| Piper, „Thorsten emotional“ (medium, 8 Stimmungen) | wie oben | CC0 | ja | `de/de_DE/thorsten_emotional/medium/MODEL_CARD` |
| Piper, „Kerstin“ (low) | wie oben | CC0 | ja | `de/de_DE/kerstin/low/MODEL_CARD` |
| Chatterbox Multilingual 0.1.7 | MIT | MIT | ja | PyPI-Metadaten `chatterbox-tts`; Modellkarte `huggingface.co/ResembleAI/chatterbox` |

Hinweise:

- Piper steht unter der GPL. Die Pipeline ruft Piper als eigenes Programm auf (`python -m piper`) und liefert es nicht
  mit aus; die erzeugten Tondateien fallen nicht unter die GPL. Piper-Code wird nicht in dieses Repo kopiert.
- Chatterbox versieht jede Ausgabe mit einem unhörbaren Wasserzeichen (Perth), das sie als KI-erzeugt kennzeichnet.
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

Folgen für die Pipeline, unabhängig von der Wahl:

- Chatterbox ist nicht deterministisch und fügt gelegentlich Wörter ein. Wird es gewählt, liest die Pipeline jeden Satz
  per Spracherkennung zurück und erzeugt ihn bei Abweichung neu.
- Englische Wörter, die eine Stimme deutsch ausspricht (z. B. „live“), kommen in `aussprache.yaml`
  (Regeln je Stimme erst anlegen, wenn die Stimme feststeht).

## Entscheidung

Offen: Der Repo-Inhaber wählt nach dem Anhören (siehe #575).
