# Video-Shorts

Pipeline für Kurzvideos (TikTok, Reels, Shorts) aus echten App-Bildschirmen und synthetischer Sprecherstimme.
Plan, Regeln und Reihenfolge: Issue #575 und `thoughts/video-shorts-plan.md`.

Stand: Schritt S0 (Hörtest der Stimmen). Videokomposition und App-Bilder folgen.

## Hörtest der Stimmen

```bash
cd marketing/shorts/tts
python3 -m venv .venv-piper && .venv-piper/bin/pip install -r requirements-piper.txt
.venv-piper/bin/python hoertest.py piper           # Sekunden
python3 -m venv .venv-cb && .venv-cb/bin/pip install --extra-index-url https://download.pytorch.org/whl/cpu -r requirements-chatterbox.txt
.venv-cb/bin/python hoertest.py chatterbox         # einige Minuten, lädt ca. 3 GB Modelle
.venv-piper/bin/python -m unittest test_sprechtext
```

Die Proben liegen danach unter `out/hoertest/` (nicht eingecheckt). Getrennte Umgebungen, weil Chatterbox feste
Versionen von PyTorch verlangt.

- `hoertest.txt`: der Testtext, so wie er später im Untertitel stünde.
- `aussprache.yaml` + `sprechtext.py`: schreiben Uhrzeiten, Salden und Zahlen für die Stimme aus.
- `LIZENZEN.md`: Lizenzen der Kandidaten, Messwerte und Auffälligkeiten.
