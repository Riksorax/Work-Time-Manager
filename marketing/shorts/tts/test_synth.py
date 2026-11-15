import json
import tempfile
import unittest
import wave
from pathlib import Path

from synth import saetze, vertone


def schreibe_wav(datei: Path, sekunden: float, rate: int = 22050) -> None:
    with wave.open(str(datei), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"\0\0" * int(rate * sekunden))


BESCHREIBUNG = {
    "szenen": [
        {"art": "aufhaenger", "text": "Frage?", "saetze": ["Frage?"]},
        {"art": "app", "bild": "b.png", "saetze": ["Fertig um 16:40 Uhr.", "Dritter Satz."]},
        {"art": "schluss"},
    ]
}
STIMME = {"engine": "test", "stimme": "a", "sprecher": None}


class VertoneTest(unittest.TestCase):
    def setUp(self):
        self.ordner = tempfile.TemporaryDirectory()
        self.addCleanup(self.ordner.cleanup)
        self.vorlagen = Path(self.ordner.name) / "vorlagen"
        self.aus = Path(self.ordner.name) / "aus"
        self.vorlagen.mkdir()
        self.gesprochen: list[str] = []

    def engine(self, auftraege, stimme):
        for text, ziel in auftraege:
            self.gesprochen.append(text)
            schreibe_wav(ziel, 1.5)

    def vertone(self, beschreibung=BESCHREIBUNG, stimme=STIMME):
        return vertone(beschreibung, self.vorlagen, self.aus, stimme, engines={"test": self.engine})

    def test_saetze_in_reihenfolge(self):
        self.assertEqual(saetze(BESCHREIBUNG), ["Frage?", "Fertig um 16:40 Uhr.", "Dritter Satz."])

    def test_je_satz_eine_datei_und_dauer(self):
        ergebnis = self.vertone()
        self.assertEqual([e["nr"] for e in ergebnis["saetze"]], ["01", "02", "03"])
        self.assertEqual([e["sekunden"] for e in ergebnis["saetze"]], [1.5, 1.5, 1.5])
        self.assertTrue((self.aus / "03.wav").exists())
        self.assertEqual(json.loads((self.aus / "dauer.json").read_text(encoding="utf-8")), ergebnis)

    def test_stimme_bekommt_sprechtext_untertitel_das_original(self):
        ergebnis = self.vertone()
        self.assertEqual(self.gesprochen[1], "Fertig um sechzehn Uhr vierzig.")
        self.assertEqual(ergebnis["saetze"][1]["text"], "Fertig um 16:40 Uhr.")

    def test_vorlage_ersetzt_synthese(self):
        schreibe_wav(self.vorlagen / "02.wav", 3.0, rate=48000)
        ergebnis = self.vertone()
        self.assertEqual(len(self.gesprochen), 2)
        self.assertEqual(ergebnis["saetze"][1]["quelle"], "vorlage")
        self.assertEqual(ergebnis["saetze"][1]["sekunden"], 3.0)

    def test_unveraendertes_wird_nicht_neu_vertont(self):
        self.vertone()
        self.vertone()
        self.assertEqual(len(self.gesprochen), 3)
        geaendert = {"szenen": [BESCHREIBUNG["szenen"][0], {"art": "app", "saetze": ["Neuer Satz."]}]}
        ergebnis = self.vertone(geaendert)
        self.assertEqual(self.gesprochen[3:], ["Neuer Satz."])
        self.assertEqual(len(ergebnis["saetze"]), 2)
        self.assertFalse((self.aus / "03.wav").exists())

    def test_andere_stimme_vertont_alles_neu(self):
        self.vertone()
        self.vertone(stimme={**STIMME, "stimme": "b"})
        self.assertEqual(len(self.gesprochen), 6)

    def test_fehler(self):
        with self.assertRaisesRegex(ValueError, "Unbekannte Engine"):
            self.vertone(stimme={"engine": "gibtsnicht"})
        (self.vorlagen / "01.wav").write_bytes(b"kein Ton")
        with self.assertRaisesRegex(ValueError, "keine lesbare WAV-Datei"):
            self.vertone()


if __name__ == "__main__":
    unittest.main()
