# CLAUDE.md – Video-Shorts (`marketing/shorts/`)

Anleitung für das Modell, das ein neues Kurzvideo (TikTok, Reels, Shorts) baut. Übersicht und Reihenfolge der
Videos: Issue #575. Aufruf und Felder der Videobeschreibung: `README.md` in diesem Ordner. Das Flutter-Werkzeug
für die App-Aufnahmen: `mobile/CLAUDE.md`, „App-Bilder für Kurzvideos (#575)“.

## Vorlage: `videos/de/feierabend-rechnen.yaml`

Dieses Video hat der Repo-Inhaber am 16.11.2026 abgenommen („echt nice“). Neue Videos folgen seinem Muster:

1. **Problem als Frage, über der laufenden App** (ca. 4 s). Eine Situation, die man kennt, in drei kurzen Zeilen:
   „8:07 gekommen. / 45 Minuten Pause. / Wann darfst du gehen?“ Die Stimme spricht dieselbe Frage. Die Platte mit
   der Frage liegt über der Stelle, an der die App die Antwort zeigt.
2. **Die App hat die Antwort schon** (ca. 4 s). Die Frage verschwindet, ein großes Schild wächst aus der Zeile der
   App heraus: kleine Zeile „Feierabend heute“, große Zahl „16:52 Uhr“. Ein Satz dazu, der die Zahl nennt.
3. **Schlusskarte** (ca. 3 s): Logo, „Kostenlos bei Google Play“, `work-time-manager.app`, ein Satz.

Länge 11 bis 15 Sekunden, drei bis vier Sätze, eine Aussage. `videos/de/feierabend.yaml` (Start per Tipp) ist die
zweite Form: Bedienung zeigen, mit echter Wischgeste und Tipp.

## Entscheidungen des Repo-Inhabers (verbindlich)

- **Keine Untertitel**, in keinem Video. Die Frage am Anfang und das Schild mit der Kernzahl sind keine Untertitel.
- **App bildfüllend, kein blauer Hintergrund** in App-Szenen. Nur die Schlusskarte ist die blaue Markenkarte.
- **Nichts retuschieren.** Rote Zahlen (z. B. „Heutige Überstunden −03:21“) sind normales App-Verhalten und
  bleiben sichtbar; das Schild darf sie nicht überdecken.
- **Stimme:** OmniVoice, Vorlage `omnivoice-mann` (`einstellungen.yaml`). Nur Deutsch.
- **Echte Bewegung:** Bildfolgen aus der App (Timer tickt, Gesten sind echte Gesten), keine Standbilder mit Zoom.
- Nur Aussagen, die in `fastlane/metadata/android/de-DE/full_description.txt` stehen. Premium-Funktionen mit
  `premium: true` kennzeichnen. Keine Preise, kein iOS, keine Rechts- oder Steuerauskunft. Teaser ohne Datum und
  ohne nachgebaute Oberfläche.

## Ablauf für ein neues Video

1. **Aussage wählen** (Tabelle in #575) und den Satz in `full_description.txt` suchen, der sie deckt. Den Fundort
   als Kommentar an den Anfang der YAML schreiben.
2. **Situation festlegen:** Welche Frage stellt sich jemand, und welche Stelle der App beantwortet sie? Gesucht ist
   ein krummer, alltäglicher Fall (später gekommen, lange Pause), nicht der glatte, den man im Kopf rechnet.
3. **Bildfolge aus der App** in `mobile/tool/shorts_sequences/` ergänzen (Vorbild `feierabend_mittags`): Eintrag
   und feste Uhr in `shorts_data.dart`, 30 Bilder/s, Uhr läuft je Bild weiter. **Den angezeigten Wert ablesen,
   nicht ausrechnen** (`--dart-define=SHORTS_SEQUENCE_TRACE=true` gibt die Texte aus) und im Code nachsehen, wie
   die App ihn bildet. Weicht er von der Erwartung ab, wird der Sprechtext angepasst, nicht der Datensatz gebogen.
   Die Ausschnitte in der JSON kommen aus gemessenen Widget-Positionen.
4. **Videobeschreibung** `videos/de/<id>.yaml` schreiben. Sätze kurz, Du-Form, Uhrzeiten als „16:52 Uhr“ (die
   Stimme bekommt sie über `tts/aussprache.yaml` ausgeschrieben).
5. **Rendern:** `SHORTS_PYTHON=<python mit omnivoice> npm run render -- <id>`. Knapp eine Minute je neuem Satz,
   danach rund eine Minute fürs Bild. Nie zwei Render- oder Syntheseläufe gleichzeitig (Speicher).
6. **Selbst prüfen** (Liste unten), Fehler beheben, neu rendern.
7. **Abnahme:** MP4 mit `SendUserFile` an den Inhaber, dazu der Sprechtext und was beim Prüfen aufgefallen ist.
   `out/` wird nicht eingecheckt; eingecheckt werden YAML, Bildfolge (`frames/de/<name>.mp4` + `.json`) und Code.

## Prüfliste vor jeder Übergabe

Das Modell kann das Video weder abspielen noch anhören. Deshalb an Bildern und Messwerten prüfen und im Bericht
sagen, dass es so geprüft wurde.

- **Bildbogen:** `ffmpeg -i out/<id>.mp4 -vf "fps=3,scale=250:-1,tile=9x4" -frames:v 1 bogen.png` ansehen, dazu das
  erste Bild und je ein Bild pro Szene in voller Größe.
- **Erstes Bild:** Frage lesbar (Plattformen nehmen es als Vorschaubild), und die Antwort ist darin nicht zu sehen.
- **Kernzahl** ist die größte Schrift im Bild und stimmt mit dem überein, was die App in der Folge zeigt.
- **Nichts Wichtiges in den Schutzzonen** (oben 250 px, unten 420 px). `render.mjs` meldet Tipp und Schild dort.
- **Kein Hintergrund** hinter der App, kein Sprung zwischen Szenen derselben Folge.
- **Zahlen im Bild widersprechen dem Sprechtext nicht** (Uhrzeit, Timer-Stand, Tageszeit der Situation).
- **Ton zurücklesen:** das MP4 durch eine Spracherkennung schicken (z. B. `faster-whisper`, Modell „small“, den
  Ton vorher mit ffmpeg auf 16 kHz mono wandeln) und mit dem Sprechtext vergleichen. OmniVoice war bisher
  fehlerfrei, andere Engines fügten Wörter ein.
- **Messwerte:** `ffprobe` (1080 × 1920, 30 fps, yuv420p, AAC 48 kHz), Lautheit −14 LUFS, Stille zwischen den
  Sätzen ca. 0,3 s (`silencedetect`), Länge 11 bis 15 s.
- **Tests:** `npm test` hier; nach Änderungen am Flutter-Werkzeug die Checks aus `mobile/CLAUDE.md` und der
  Prüfsummenvergleich von Standbildern, bestehenden Folgen und Store-Screenshots.

## Lehren aus den ersten Fassungen

| Fehler | Jetzt |
|---|---|
| 3 s Text auf blauer Fläche als Einstieg | App ab dem ersten Bild, Frage als Platte darüber |
| Standbilder mit Zoom wirkten wie eine Diashow | Bildfolge aus der App, Timer tickt |
| Untertitel verdeckten die Stelle, um die es ging | keine Untertitel; Platte und Schild gezielt gesetzt |
| Kernzahl war graue Kleinschrift der App | Schild mit großer Zahl, wächst aus der App-Zeile |
| Sprechtext „16:22 Uhr“ zu einem Bild von 16:40 Uhr | Situation und Uhrzeit der Folge passen zum Text |
| 1 s Stille zwischen den Sätzen | Stille an den Satzenden abgeschnitten, ca. 0,3 s |
| Vier Funktionen in 20 s | eine Aussage in 11 bis 15 s |
| Tipp auf einen Knopf am unteren Bildrand | echte Wischgeste davor, Tipp in der freien Mitte |
| Die Antwort war vor dem Schild schon lesbar | Platte liegt über der Antwortzeile, Kamera steht dabei still (`zoom.faktor: 1.0`) |
| Frage brach mitten im Satz um | feste Zeilen mit `\n` im `aufhaenger` |

## Bekannte Grenzen und offene Punkte

- **Beispieldaten:** „Überstunden Gesamt“ zeigt in `feierabend_mittags` +19:35, in `start_morgens` nach dem Start
  +11:35 (der Renderer legt den Saldo mit Stand „heute“ ab). Eine Angleichung bräuchte einen eigenen Parameter in
  `mobile/tool/shared/screen_renderer.dart`, damit die Store-Screenshots gleich bleiben.
- **Zeile „Mit Gleitzeit-Bilanz auf 0 …“** steht direkt unter der Feierabend-Zeile und zeigt oft eine Uhrzeit in
  der Vergangenheit. Das Schild rahmt beide Zeilen; die zweite nie eigens hervorheben.
- **Rechenzeit:** OmniVoice braucht ohne Grafikkarte knapp eine Minute je Satz. Unveränderte Sätze unter
  `out/<id>/stimme/` werden wiederverwendet; den Ordner nicht ohne Grund löschen.
- **Lizenzen:** `tts/LIZENZEN.md` (OmniVoice mit Auflagen), Remotion kostenlos für Einzelpersonen; vor Remotion 5
  neu prüfen.
- **Reichweite:** Ob ein Video Installationen bringt, zeigt erst das Posten. Mehrere Varianten derselben Aussage
  sind erwünscht; welche läuft, entscheidet der Inhaber nach den Zahlen der Plattform.
