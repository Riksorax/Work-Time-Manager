# CLAUDE.md – Video-Shorts (`marketing/shorts/`)

Anleitung für das Modell, das ein neues Kurzvideo (TikTok, Reels, Shorts) baut. Übersicht und Reihenfolge der
Videos: Issue #575. Aufruf und Felder der Videobeschreibung: `README.md` in diesem Ordner. Das Flutter-Werkzeug
für die App-Aufnahmen: `mobile/CLAUDE.md`, „App-Bilder für Kurzvideos (#575)“.

## Vorlage: `videos/de/feierabend-rechnen.yaml`

Dieses Video hat der Repo-Inhaber am 16.11.2026 abgenommen („echt nice“). Neue Videos folgen seinem Muster:

1. **Problem als Frage, über der laufenden App** (ca. 4 s). Eine Situation, die man kennt, in drei kurzen Zeilen:
   „Du bist um 8:07 gekommen. / 45 Minuten Pause. / Wann darfst du gehen?“ (Der Inhaber will die direkte Anrede „Du bist um …“ am Anfang.) Die Stimme spricht dieselbe Frage. Die Platte mit
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
- **Stimme:** Nur Deutsch. **Achtung, Stand 17.11.2026:** Die bisher gewählte Engine OmniVoice darf für Werbung
  nicht verwendet werden (Modellgewichte CC-BY-NC, siehe `tts/LIZENZEN.md`). Videos mit dieser Stimme werden nicht
  veröffentlicht; eine neue Stimme ist offen. Bis dahin dient die eingestellte Stimme nur der internen Abnahme von
  Bild und Tempo.
- **Echte Bewegung:** Bildfolgen aus der App (Timer tickt, Gesten sind echte Gesten), keine Standbilder mit Zoom.
- Nur Aussagen, die in `fastlane/metadata/android/de-DE/full_description.txt` stehen. Premium-Funktionen mit
  `premium: true` kennzeichnen. Keine Preise, kein iOS, keine Rechts- oder Steuerauskunft. Teaser ohne Datum und
  ohne nachgebaute Oberfläche.

## Harte Kriterien (ein Verstoß heißt: nicht übergeben, erst beheben)

Jedes Kriterium ist am fertigen Video zu prüfen, nicht an der Absicht. Im Bericht je Kriterium eine Zeile: erfüllt
oder nicht, und woran geprüft.

1. **Eine Aussage, ein Schild.** Ein Video hebt genau eine Zahl oder ein Ergebnis hervor. Zwei Schilder, zwei
   Funktionen oder „und außerdem …“ sind zwei Videos. Free und Premium nie im selben Video: Ein Premium-Video zeigt
   nur die Premium-Funktion.
2. **Länge 11 bis 15 Sekunden** (`ffprobe`). Über 15 Sekunden wird gekürzt, indem Inhalt wegfällt (ein Satz, eine
   Szene), nie durch schnelleres Sprechen oder kürzere Pausen. Richtwert: Frage bis 4 s, Antwort bis 4 s,
   Schlusskarte 3 s, höchstens vier Sätze.
3. **Das Schild verdeckt keine rote Zahl.** Das Schild steht unter seiner Quelle und deckt, was dort liegt. Am
   Einzelbild in voller Größe mit Schild prüfen, was darunter verschwindet. Liegt dort eine rote Zahl (z. B.
   „Heutige Überstunden −03:21“ direkt unter „Überstunden Gesamt“), einen anderen Zustand der App aufnehmen, in dem
   an dieser Stelle nichts Rotes steht (z. B. abends, wenn der Tag im Plus ist), oder die Seite in der Folge so
   scrollen, dass unter der Quelle nur Eingabefelder oder Listen liegen. Die rote Zahl wegzulassen oder zu
   überdecken ist keine Lösung.
4. **Jedes Wort der Frage stimmt mit dem Bild überein.** Vor dem Schreiben der Frage das erste Bild in voller Größe
   ansehen und alles lesen, was sichtbar bleibt: Tageszeit und Timer-Stand, „Heutige Überstunden“, Orte, der Schalter
   „Von zu Hause gearbeitet“, Start- und Endzeit. Die Frage darf nichts behaupten, dem das Bild widerspricht
   („im Büro“ bei eingeschaltetem Home-Office-Schalter; „diese Woche“, wenn die Antwort der Gesamtsaldo ist).
   Zeitraum der Frage = Zeitraum der gezeigten Zahl.
5. **Die Frage wird genau von der hervorgehobenen Zahl beantwortet**, mit derselben Einheit und demselben Begriff,
   den die App an dieser Stelle zeigt (Beschriftung der App als kleine Zeile des Schilds).
6. **Unter und über der Platte schaut nichts Halbes hervor.** Eine Zahl ohne ihre Beschriftung (oder umgekehrt) am
   Rand der Platte ist ein Fehler: den `zoom`-Ausschnitt so legen, dass die Platte in einer Lücke beginnt und endet.
   Die Antwort selbst liegt unter der Platte.
7. **Eine Seite der App je Video.** Ein Schnitt von einer Seite auf eine andere (Dashboard → Berichte) ohne sichtbare
   Bedienung wirkt wie ein Sprung. Entweder bleibt das Video auf einer Seite, oder die Bildfolge enthält den echten
   Wechsel (Tipp auf den Reiter als Teil der Folge).
8. **Werte abgelesen, Aussage belegt:** Fundstelle aus `full_description.txt` in der YAML, Werte aus dem Trace der
   Folge.
9. **Checks ausgeführt und genannt:** `npm test`; nach Änderungen unter `mobile/tool/` zusätzlich
   `flutter analyze --no-fatal-infos`, `dart format tool`, `dart run custom_lint`, die Folge ein zweites Mal unter
   einer anderen Zeitzone (`TZ=America/Los_Angeles`, gleiche Prüfsummen) und der Prüfsummenvergleich aller schon
   vorhandenen Dateien unter `frames/de/` und der Store-Screenshots (vorher/nachher). Was nicht ausgeführt wurde,
   steht als nicht ausgeführt im Bericht.

## Ablauf für ein neues Video

1. **Aussage wählen** (Tabelle in #575) und den Satz in `full_description.txt` suchen, der sie deckt. Den Fundort
   als Kommentar an den Anfang der YAML schreiben.
2. **Situation festlegen:** Welche Frage stellt sich jemand, und welche Stelle der App beantwortet sie? Gesucht ist
   ein krummer, alltäglicher Fall (später gekommen, lange Pause), nicht der glatte, den man im Kopf rechnet.
   Enthält das Video eine Geste oder einen Tipp, zuerst nur den Ton erzeugen
   (`python tts/synth.py videos/de/<id>.yaml`): Die Satzlängen aus `out/<id>/stimme/dauer.json` braucht man, um
   Wisch und Tipp in der Folge auf das richtige Wort zu legen.
3. **Bildfolge aus der App** in `mobile/tool/shorts_sequences/` ergänzen (Vorbild `feierabend_mittags`): Eintrag
   und feste Uhr in `shorts_data.dart`, 30 Bilder/s, Uhr läuft je Bild weiter. **Den angezeigten Wert ablesen,
   nicht ausrechnen** (`--dart-define=SHORTS_SEQUENCE_TRACE=true` gibt die Texte aus) und im Code nachsehen, wie
   die App ihn bildet. Weicht er von der Erwartung ab, wird der Sprechtext angepasst, nicht der Datensatz gebogen.
   Die Ausschnitte in der JSON kommen aus gemessenen Widget-Positionen.
4. **Videobeschreibung** `videos/de/<id>.yaml` schreiben. Sätze kurz, Du-Form, Uhrzeiten als „16:52 Uhr“ (die
   Stimme bekommt sie über `tts/aussprache.yaml` ausgeschrieben).
5. **Rendern:** `SHORTS_PYTHON=<python mit omnivoice> npm run render -- <id>`. Je neuem Satz eine bis zwei Minuten in
   der Cloud-Umgebung (auf langsamen Rechnern bis 15 Minuten), danach rund eine Minute fürs Bild. Nie zwei Render- oder Syntheseläufe gleichzeitig (Speicher).
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
- **Je Szene ein Einzelbild in voller Größe mit Schild bzw. Platte** und dazu aufschreiben, was Schild und Platte
  verdecken und was an ihren Rändern hervorschaut (Kriterien 3 und 6). Der verkleinerte Bildbogen reicht dafür nicht.
- **Frage gegen das erste Bild lesen** (Kriterium 4): Home-Office-Schalter, Orte, rote oder grüne Tageszahl,
  Tageszeit.
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
| Platte schnitt halbe App-Zeilen oben und unten an (`pausen`) | `zoom`-Ausschnitt so wählen, dass die Platte (ca. 350 px bei drei Zeilen) in einer Lücke der App beginnt und endet; am Standbild in voller Größe prüfen |
| Wisch begann auf einem Schalter, die Zeile leuchtete auf (`pausen`) | Wischgesten auf einer leeren Stelle beginnen (neben einer Überschrift) |
| Schild ließ links ein „P“ der Überschrift stehen (`pausen`, Zoom 1.08) | Zoom nur so weit, dass das Schild (x 70 bis 1010) die Nachbarzeilen ganz deckt |
| Runde Ecke des Schilds ließ unten links das „P“ von „Pausen“ stehen (`pausen-lang`) | eigenen Ausschnitt in der YAML, oben einige Pixel tiefer als die Quelle: Das Schild rückt mit herunter (es steht 36 px über dem Ausschnitt) |
| Frage in vier Zeilen passte in keine Lücke der App (`pausen-lang`) | drei Zeilen; die Platte ist bei drei Zeilen gut 350 px hoch, gemessene Lücken am Seitenanfang: unter „+19:35“ (bis y 649) und über „Startzeit“ (ab y 1030) |
| Schild „+19:35“ lag über der roten Zahl „Heutige Überstunden −03:21“ (`ueberstunden`, erster Entwurf) | Kriterium 3: Zustand ohne rote Zahl an dieser Stelle aufnehmen |
| Zwei Aussagen (Gleitzeitkonto und Prognose) in einem Video, 16,6 s (`ueberstunden`, erster Entwurf) | Kriterien 1 und 2: zwei Videos, eines Free, eines Premium |
| Frage „diese Woche … im Büro“, Antwort war der Gesamtsaldo, im Bild war der Home-Office-Schalter an (`ueberstunden`, erster Entwurf) | Kriterien 4 und 5: Frage aus dem lesen, was im Bild steht |
| Rote Zahl ohne Beschriftung schaute unter der Platte hervor (`ueberstunden`, erster Entwurf) | Kriterium 6 |
| Schnitt vom Dashboard in den Insights-Tab ohne sichtbaren Wechsel (`ueberstunden`, erster Entwurf) | Kriterium 7: eine Seite je Video |
| Platte war höher als gerechnet und schnitt die Beschriftung „Startzeit“ an (`ueberstunden`) | Höhe ≈ 130 px (Innenabstand und Marke) + 3,42 × Schrift bei drei Zeilen (120 px Schrift: 540 px; 92 px: 444 px); sie wächst während der Frage von Skala 0,97 auf 1,02 um ihre Mitte. Beide Lagen müssen in die Lücken passen; über die Länge der längsten Zeile (`aufhaengerSchrift`) die Höhe wählen, über `hoehe` des `zoom`-Ausschnitts die Lage. Ränder mit Standbildern nachmessen |
| Premium-Kennzeichen lag nach dem Wisch über einer Textzeile und blendete beim Szenenwechsel neu ein (`prognose`) | Wischweg so wählen, dass neben dem Kennzeichen (y 280 bis 356, rechts) nur eine kurze Überschrift steht; bei Fortsetzung derselben Folge bleibt es jetzt stehen |

## Bekannte Grenzen und offene Punkte

- **Beispieldaten:** „Überstunden Gesamt“ zeigt in `feierabend_mittags` +19:35, in `start_morgens` nach dem Start
  +11:35 (der Renderer legt den Saldo mit Stand „heute“ ab). Eine Angleichung bräuchte einen eigenen Parameter in
  `mobile/tool/shared/screen_renderer.dart`, damit die Store-Screenshots gleich bleiben.
- **Zeile „Mit Gleitzeit-Bilanz auf 0 …“** steht direkt unter der Feierabend-Zeile und zeigt oft eine Uhrzeit in
  der Vergangenheit. Das Schild rahmt beide Zeilen; die zweite nie eigens hervorheben.
- **Platte des Aufhängers** ist zu 88 % deckend: Die verdeckten App-Zeilen scheinen schwach durch (in
  `pausen` „Heutige Überstunden +00:48“ und die Feierabend-Zeilen, in `ueberstunden` „+19:35“ hinter der ersten
  Zeile der Frage, in `prognose` die Texte der Prognose-Karte). Eine Änderung in `src/bausteine.jsx` träfe
  alle Videos.
- **Ergebnis vor dem Schild:** Zeigt die App das Ergebnis erst nach einem Tipp, ist es zwischen Tipp und Schild
  kurz ohne Hervorhebung zu sehen (in `pausen` rund 1,3 s, davon 0,5 s halb in der Schutzzone, bis der Wisch die
  Karte hochholt). Das ist der echte Ablauf; das Schild kommt mit `nach` so früh wie möglich.
  `pausen-lang` (zwei Karten) kürzt das: Die Folge zieht die Karten mit `_dragBy` ohne Ausschwingen hoch,
  die Marke `ergaenzt` steht auf dem ersten ruhigen Bild und das Schild hat `bei: 0`. Ergebnis 0,87 s
  zwischen dem Erscheinen der Karten und dem Schild, davon 0,53 s mit der zweiten Karte ganz oder teils in der
  Schutzzone (bis die Seite steht).
- **Rechenzeit:** OmniVoice braucht ohne Grafikkarte in der Cloud-Umgebung eine bis zwei Minuten je Satz, auf einem
  Windows-Rechner wurden rund 15 Minuten je Satz gemessen. Mit CUDA-PyTorch nutzt `synth.py` die Grafikkarte von
  selbst (`SHORTS_GERAET=cpu|cuda` erzwingt ein Gerät; der Grafikkarten-Pfad ist ungetestet). Unveränderte Sätze unter
  `out/<id>/stimme/` werden wiederverwendet; den Ordner nicht ohne Grund löschen.
- **Lizenzen:** `tts/LIZENZEN.md`. OmniVoice ist nicht gewerblich nutzbar (CC-BY-NC, festgestellt am 17.11.2026);
  eine frühere Fassung nannte es fälschlich nutzbar. Jede Stimm-Engine nur nach vollständigem Lesen von Modellkarte
  und README einsetzen. Remotion kostenlos für Einzelpersonen; vor Remotion 5 neu prüfen.
- **Reichweite:** Ob ein Video Installationen bringt, zeigt erst das Posten. Mehrere Varianten derselben Aussage
  sind erwünscht; welche läuft, entscheidet der Inhaber nach den Zahlen der Plattform.
