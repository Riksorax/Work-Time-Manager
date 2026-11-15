"""Hörtest: denselben Text mit mehreren Stimmen vertonen (#575, Schritt S0).

Aufruf (aus `marketing/shorts/tts/`):

    python hoertest.py piper        # braucht requirements-piper.txt
    python hoertest.py chatterbox   # braucht requirements-chatterbox.txt

Schreibt WAV-Dateien nach `../out/hoertest/` und gibt je Stimme Rechenzeit und
Länge aus. Stimmmodelle werden beim ersten Lauf geladen (Piper nach
`stimmen/`, nicht eingecheckt).
"""

from __future__ import annotations

import subprocess
import sys
import time
import urllib.request
import wave
from pathlib import Path

from sprechtext import sprechtext

HIER = Path(__file__).parent
AUS = HIER.parent / "out" / "hoertest"
STIMMEN = HIER / "stimmen"
PIPER_QUELLE = "https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE"

# (Dateiname der Probe, Pfad des Modells unter PIPER_QUELLE, Sprecher-Nummer)
PIPER_STIMMEN = [
    ("piper-thorsten-high", "thorsten/high/de_DE-thorsten-high", None),
    ("piper-thorsten-emotional-neutral", "thorsten_emotional/medium/de_DE-thorsten_emotional-medium", 4),
    ("piper-thorsten-emotional-amused", "thorsten_emotional/medium/de_DE-thorsten_emotional-medium", 0),
    ("piper-kerstin-low", "kerstin/low/de_DE-kerstin-low", None),
]  # fmt: skip


def saetze() -> list[str]:
    zeilen = (HIER / "hoertest.txt").read_text(encoding="utf-8").splitlines()
    return [sprechtext(z.strip()) for z in zeilen if z.strip()]


def laenge(datei: Path) -> float:
    with wave.open(str(datei)) as w:
        return w.getnframes() / w.getframerate()


def piper_modell(pfad: str) -> Path:
    STIMMEN.mkdir(exist_ok=True)
    ziel = STIMMEN / f"{Path(pfad).name}.onnx"
    for endung in (".onnx", ".onnx.json"):
        datei = ziel.with_name(Path(pfad).name + endung)
        if not datei.exists():
            print(f"lade {datei.name} …")
            urllib.request.urlretrieve(f"{PIPER_QUELLE}/{pfad}{endung}", datei)
    return ziel


def piper() -> None:
    text = "\n".join(saetze())
    for name, pfad, sprecher in PIPER_STIMMEN:
        ziel = AUS / f"{name}.wav"
        befehl = [sys.executable, "-m", "piper", "-m", str(piper_modell(pfad)),
                  "-f", str(ziel), "--sentence-silence", "0.3"]  # fmt: skip
        if sprecher is not None:
            befehl += ["-s", str(sprecher)]
        start = time.monotonic()
        subprocess.run(befehl, input=text, text=True, check=True)
        melde(name, ziel, time.monotonic() - start)


def chatterbox() -> None:
    import torch
    import torchaudio
    from chatterbox.mtl_tts import ChatterboxMultilingualTTS

    modell = ChatterboxMultilingualTTS.from_pretrained(device="cpu")
    pause = torch.zeros(1, int(modell.sr * 0.3))
    # Ohne Vorlage spricht das Modell mit seiner (englisch geprägten)
    # Standardstimme. Mit einer deutschen Vorlage übernimmt es deren Klang;
    # als Vorlage dient die Piper-Probe (Thorsten, CC0), falls vorhanden.
    vorlage = AUS / "piper-thorsten-high.wav"
    varianten = [("chatterbox-standardstimme", None)]
    if vorlage.exists():
        varianten.append(("chatterbox-vorlage-thorsten", str(vorlage)))
    for name, prompt in varianten:
        ziel = AUS / f"{name}.wav"
        start = time.monotonic()
        teile = []
        for satz in saetze():
            ton = modell.generate(satz, language_id="de", audio_prompt_path=prompt)
            teile += [ton, pause]
        torchaudio.save(str(ziel), torch.cat(teile, dim=1), modell.sr)
        melde(name, ziel, time.monotonic() - start)


def melde(name: str, datei: Path, rechenzeit: float) -> None:
    print(f"{name}: {laenge(datei):.1f} s Ton, {rechenzeit:.1f} s Rechenzeit")


if __name__ == "__main__":
    engines = {"piper": piper, "chatterbox": chatterbox}
    if len(sys.argv) != 2 or sys.argv[1] not in engines:
        sys.exit(f"Aufruf: python hoertest.py <{'|'.join(engines)}>")
    AUS.mkdir(parents=True, exist_ok=True)
    engines[sys.argv[1]]()
