import array
import json
import tempfile
import unittest
import wave
from pathlib import Path

from synth import kuerze, laenge, saetze, vertone


def schreibe_wav(datei: Path, sekunden: float, rate: int = 22050) -> None:
    with wave.open(str(datei), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"\0\0" * int(rate * sekunden))


def schreibe_ton(datei: Path, stille_davor: float, ton: float, stille_danach: float, rate: int = 24000) -> None:
    """Rechteckton zwischen zwei Stücken Stille (mit leisem Grundrauschen)."""
    leise = array.array("h", [3, -3] * int(rate * 0.5))
    with wave.open(str(datei), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(leise[: int(rate * stille_davor)].tobytes())
        w.writeframes(array.array("h", [8000, -8000] * int(rate * ton / 2)).tobytes())
        w.writeframes(leise[: int(rate * stille_danach)].tobytes())


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

    def test_stimme_bekommt_sprechtext_dauer_json_das_original(self):
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

    def test_stille_wird_bis_auf_den_rest_abgeschnitten(self):
        datei = Path(self.ordner.name) / "ton.wav"
        schreibe_ton(datei, 0.4, 1.0, 0.3)
        self.assertTrue(kuerze(datei, 0.05))
        self.assertAlmostEqual(laenge(datei), 1.1, places=3)
        # zweiter Lauf ändert nichts, eine Datei ohne Ton bleibt unverändert
        self.assertFalse(kuerze(datei, 0.05))
        self.assertAlmostEqual(laenge(datei), 1.1, places=3)
        schreibe_wav(datei, 1.5)
        self.assertFalse(kuerze(datei, 0.05))
        self.assertEqual(laenge(datei), 1.5)

    def test_dauer_json_traegt_die_gekuerzte_laenge(self):
        def engine(auftraege, stimme):
            for _, ziel in auftraege:
                schreibe_ton(ziel, 0.4, 1.0, 0.3)

        ergebnis = vertone(BESCHREIBUNG, self.vorlagen, self.aus, STIMME, engines={"test": engine}, rest=0.05)
        self.assertEqual([e["sekunden"] for e in ergebnis["saetze"]], [1.1, 1.1, 1.1])
        self.assertAlmostEqual(laenge(self.aus / "01.wav"), 1.1, places=3)
        ungekuerzt = vertone(BESCHREIBUNG, self.vorlagen, Path(self.ordner.name) / "roh", STIMME, engines={"test": engine})
        self.assertEqual(ungekuerzt["saetze"][0]["sekunden"], 1.7)

    def test_fehler(self):
        with self.assertRaisesRegex(ValueError, "Unbekannte Engine"):
            self.vertone(stimme={"engine": "gibtsnicht"})
        (self.vorlagen / "01.wav").write_bytes(b"kein Ton")
        with self.assertRaisesRegex(ValueError, "keine lesbare WAV-Datei"):
            self.vertone()


if __name__ == "__main__":
    unittest.main()
