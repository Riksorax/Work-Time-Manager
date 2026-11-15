"""Sprechtext für die Sprachsynthese aufbereiten (#575).

Wendet die Regeln aus `aussprache.yaml` an und schreibt Zahlen als deutsche
Zahlwörter aus. Ohne Abhängigkeit von Datum, Uhrzeit oder Zeitzone.
"""

from __future__ import annotations

import re
from pathlib import Path

import yaml

_EINER = [
    "null", "eins", "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht",
    "neun", "zehn", "elf", "zwölf", "dreizehn", "vierzehn", "fünfzehn",
    "sechzehn", "siebzehn", "achtzehn", "neunzehn",
]  # fmt: skip
_ZEHNER = [
    "", "", "zwanzig", "dreißig", "vierzig", "fünfzig", "sechzig", "siebzig",
    "achtzig", "neunzig",
]  # fmt: skip


def zahlwort(n: int) -> str:
    """Ganze Zahl von 0 bis 9999 als deutsches Zahlwort."""
    if not 0 <= n <= 9999:
        raise ValueError(f"Zahl außerhalb 0–9999: {n}")
    if n < 20:
        return _EINER[n]
    if n < 100:
        zehner, einer = divmod(n, 10)
        if einer == 0:
            return _ZEHNER[zehner]
        vorne = "ein" if einer == 1 else _EINER[einer]
        return f"{vorne}und{_ZEHNER[zehner]}"
    if n < 1000:
        hunderter, rest = divmod(n, 100)
        vorne = "ein" if hunderter == 1 else _EINER[hunderter]
        return f"{vorne}hundert{zahlwort(rest) if rest else ''}"
    tausender, rest = divmod(n, 1000)
    vorne = "ein" if tausender == 1 else _EINER[tausender]
    return f"{vorne}tausend{zahlwort(rest) if rest else ''}"


def lade_regeln(pfad: Path | None = None) -> list[dict]:
    pfad = pfad or Path(__file__).with_name("aussprache.yaml")
    daten = yaml.safe_load(pfad.read_text(encoding="utf-8")) or {}
    regeln = daten.get("regeln", [])
    for regel in regeln:
        unbekannt = set(regel) - {"muster", "ersatz", "zahlwort"}
        if unbekannt or "muster" not in regel or "ersatz" not in regel:
            raise ValueError(f"Ungültige Ausspracheregel: {regel}")
    return regeln


def sprechtext(text: str, regeln: list[dict] | None = None) -> str:
    """Text so umschreiben, wie die Stimme ihn sprechen soll."""
    regeln = lade_regeln() if regeln is None else regeln
    for regel in regeln:
        muster = re.compile(regel["muster"])
        if regel.get("zahlwort"):

            def ersetze(treffer: re.Match, ersatz: str = regel["ersatz"]) -> str:
                return re.sub(
                    r"\\(\d)",
                    lambda g: zahlwort(int(treffer.group(int(g.group(1))))),
                    ersatz,
                )

            text = muster.sub(ersetze, text)
        else:
            text = muster.sub(regel["ersatz"], text)
    return text
