"""Sprecherstimme für ein Video erzeugen (#575, Schritt S1).

Aufruf (aus `marketing/shorts/`, in der Umgebung mit `requirements-piper.txt`):

    python tts/synth.py videos/de/<id>.yaml [--engine piper] [--stimme de_DE-thorsten-high]

Schreibt je Satz eine WAV-Datei nach `out/<id>/stimme/<nr>.wav` und dazu
`dauer.json` mit der Länge jedes Satzes; daraus entsteht die Zeitsteuerung
des Videos. Die Sätze werden über alle Szenen durchnummeriert (01, 02, …).

Liegt unter `videos/de/<id>/stimme/<nr>.wav` schon eine Datei (selbst
eingesprochen oder von einem anderen Dienst), wird sie genommen statt
synthetisiert. Engine und Stimme stehen in `einstellungen.yaml` (`stimme:`).
Die Stimme bekommt den Sprechtext aus `sprechtext.py`, in `dauer.json` steht
zusätzlich der Originaltext für den Untertitel.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import wave
from pathlib import Path
from typing import Callable

import yaml

from sprechtext import sprechtext

HIER = Path(__file__).parent
WURZEL = HIER.parent
STIMMEN = HIER / "stimmen"

# Eine Engine vertont eine Liste (Sprechtext, Zieldatei) mit der gewählten Stimme.
Engine = Callable[[list[tuple[str, Path]], dict], None]


def saetze(beschreibung: dict) -> list[str]:
    """Alle Sätze in Sprechreihenfolge (wie `saetzeMitNummer` in lib/schema.mjs)."""
    ergebnis = []
    for szene in beschreibung.get("szenen") or []:
        for satz in szene.get("saetze") or []:
            if not isinstance(satz, str) or not satz.strip():
                raise ValueError(f"Leerer Satz in Szene „{szene.get('art')}“")
            ergebnis.append(satz.strip())
    return ergebnis


def laenge(datei: Path) -> float:
    try:
        with wave.open(str(datei)) as w:
            return w.getnframes() / w.getframerate()
    except (wave.Error, EOFError) as fehler:
        raise ValueError(f"{datei}: keine lesbare WAV-Datei (PCM erwartet): {fehler}") from fehler


def piper(auftraege: list[tuple[str, Path]], stimme: dict) -> None:
    modell = STIMMEN / f"{stimme['stimme']}.onnx"
    if not modell.exists():
        raise FileNotFoundError(
            f"Stimmmodell {modell} fehlt. `python hoertest.py piper` lädt die Piper-Stimmen."
        )
    for text, ziel in auftraege:
        befehl = [sys.executable, "-m", "piper", "-m", str(modell), "-f", str(ziel)]
        if stimme.get("sprecher") is not None:
            befehl += ["-s", str(stimme["sprecher"])]
        subprocess.run(befehl, input=text, text=True, check=True)


def chatterbox(auftraege: list[tuple[str, Path]], stimme: dict) -> None:
    import torchaudio
    from chatterbox.mtl_tts import ChatterboxMultilingualTTS

    modell = ChatterboxMultilingualTTS.from_pretrained(device="cpu")
    vorlage = stimme.get("stimme") or None
    for text, ziel in auftraege:
        ton = modell.generate(text, language_id="de", audio_prompt_path=vorlage)
        # 16 Bit PCM, damit `wave` die Länge lesen kann.
        torchaudio.save(str(ziel), ton, modell.sr, encoding="PCM_S", bits_per_sample=16)


ENGINES: dict[str, Engine] = {"piper": piper, "chatterbox": chatterbox}


def vertone(
    beschreibung: dict,
    vorlagen: Path,
    aus: Path,
    stimme: dict,
    engines: dict[str, Engine] | None = None,
    regeln: list[dict] | None = None,
) -> dict:
    """Schreibt die WAV-Dateien und `dauer.json` nach `aus`, gibt den Inhalt zurück."""
    engines = ENGINES if engines is None else engines
    if stimme.get("engine") not in engines:
        raise ValueError(f"Unbekannte Engine „{stimme.get('engine')}“ (erlaubt: {', '.join(engines)})")
    aus.mkdir(parents=True, exist_ok=True)
    kennung = {k: stimme.get(k) for k in ("engine", "stimme", "sprecher")}
    try:
        alt = json.loads((aus / "dauer.json").read_text(encoding="utf-8"))
        vorher = {e["nr"]: e for e in alt["saetze"]} if alt.get("stimme") == kennung else {}
    except (OSError, ValueError, KeyError):
        vorher = {}

    eintraege, auftraege = [], []
    for i, text in enumerate(saetze(beschreibung), start=1):
        nr = f"{i:02d}"
        ziel = aus / f"{nr}.wav"
        eintrag = {"nr": nr, "datei": ziel.name, "text": text, "sprechtext": sprechtext(text, regeln)}
        vorlage = vorlagen / f"{nr}.wav"
        if vorlage.exists():
            laenge(vorlage)  # unlesbare Vorlage früh und mit Pfad melden
            shutil.copyfile(vorlage, ziel)
            eintrag["quelle"] = "vorlage"
        else:
            eintrag["quelle"] = "synthese"
            alter = vorher.get(nr, {})
            unveraendert = alter.get("quelle") == "synthese" and alter.get("sprechtext") == eintrag["sprechtext"]
            if not (unveraendert and ziel.exists()):
                auftraege.append((eintrag["sprechtext"], ziel))
        eintraege.append(eintrag)

    if auftraege:
        engines[stimme["engine"]](auftraege, stimme)
    for eintrag in eintraege:
        ziel = aus / eintrag["datei"]
        if not ziel.exists():
            raise FileNotFoundError(f"Satz {eintrag['nr']}: die Engine hat {ziel} nicht geschrieben")
        eintrag["sekunden"] = round(laenge(ziel), 3)
    # Reste eines früheren, längeren Sprechtexts entfernen.
    gueltig = {e["datei"] for e in eintraege}
    for rest in aus.glob("*.wav"):
        if rest.name not in gueltig:
            rest.unlink()

    ergebnis = {"stimme": kennung, "saetze": eintraege}
    (aus / "dauer.json").write_text(json.dumps(ergebnis, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return ergebnis


def main() -> None:
    parser = argparse.ArgumentParser(description="Sprecherstimme je Satz erzeugen")
    parser.add_argument("beschreibung", type=Path, help="videos/<sprache>/<id>.yaml")
    parser.add_argument("--engine", choices=sorted(ENGINES))
    parser.add_argument("--stimme")
    parser.add_argument("--aus", type=Path, help="Zielordner (Standard: out/<id>/stimme)")
    args = parser.parse_args()

    einstellungen = yaml.safe_load((WURZEL / "einstellungen.yaml").read_text(encoding="utf-8")) or {}
    stimme = dict(einstellungen.get("stimme") or {})
    if args.engine:
        stimme["engine"] = args.engine
    if args.stimme is not None:
        stimme["stimme"] = args.stimme

    beschreibung = yaml.safe_load(args.beschreibung.read_text(encoding="utf-8")) or {}
    video_id = args.beschreibung.stem
    aus = args.aus or WURZEL / "out" / video_id / "stimme"
    try:
        ergebnis = vertone(beschreibung, args.beschreibung.with_suffix("") / "stimme", aus, stimme)
    except (ValueError, FileNotFoundError) as fehler:
        sys.exit(f"Fehler: {fehler}")
    for e in ergebnis["saetze"]:
        print(f"{e['nr']}  {e['sekunden']:6.2f} s  {e['quelle']:8}  {e['text']}")
    print(f"{len(ergebnis['saetze'])} Sätze, {sum(e['sekunden'] for e in ergebnis['saetze']):.1f} s Ton -> {aus}")


if __name__ == "__main__":
    main()
