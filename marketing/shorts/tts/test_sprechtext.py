import unittest

from sprechtext import sprechtext, zahlwort


class ZahlwortTest(unittest.TestCase):
    def test_zahlen(self):
        faelle = {
            0: "null", 1: "eins", 12: "zwölf", 16: "sechzehn", 17: "siebzehn",
            21: "einundzwanzig", 30: "dreißig", 45: "fünfundvierzig",
            100: "einhundert", 101: "einhunderteins", 2026: "zweitausendsechsundzwanzig",
        }  # fmt: skip
        for zahl, wort in faelle.items():
            self.assertEqual(zahlwort(zahl), wort)

    def test_ausserhalb(self):
        with self.assertRaises(ValueError):
            zahlwort(10000)


class SprechtextTest(unittest.TestCase):
    def test_uhrzeit(self):
        self.assertEqual(sprechtext("um 16:40 Uhr fertig"), "um sechzehn Uhr vierzig fertig")
        self.assertEqual(sprechtext("ab 8:00 Uhr"), "ab acht Uhr")
        self.assertEqual(sprechtext("um 9:05 Uhr"), "um neun Uhr fünf")

    def test_saldo(self):
        self.assertEqual(
            sprechtext("bei +12:45 Stunden"), "bei plus zwölf Stunden fünfundvierzig"
        )
        self.assertEqual(sprechtext("bei -3:30 Stunden"), "bei minus drei Stunden dreißig")

    def test_einfache_zahlen(self):
        self.assertEqual(
            sprechtext("30 Minuten ab 6 Stunden"), "dreißig Minuten ab sechs Stunden"
        )

    def test_text_ohne_zahlen_bleibt(self):
        satz = "Kostenlos bei Google Play."
        self.assertEqual(sprechtext(satz), satz)


if __name__ == "__main__":
    unittest.main()
