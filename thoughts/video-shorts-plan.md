# Plan: Video-Shorts für Work Time Manager (Deutsch)

Stand: 15.11.2026. Arbeitsplan für ein Modell (Sonnet/Opus 5.5), das die Schritte nacheinander als eigene PRs
gegen `develop` umsetzt. Jeder Schritt ist für sich lesbar; wer bei Schritt S3 einsteigt, liest „Ziel“,
„Festlegungen“ und den Schritt selbst.

## Ziel

Kurzvideos (TikTok, Instagram Reels, YouTube Shorts) bringen neue Nutzer in die App und einen Teil davon ins
Premium-Abo. Bild und Ton entstehen aus dem Repo heraus, per Befehl und wiederholbar, damit nach jedem Release
neue Videos ohne Handarbeit am Schnitt entstehen.

Erste Charge: die Pipeline und 5 Videos auf Deutsch. Englisch ist nicht Teil dieses Plans, die Pipeline soll es
aber nicht verbauen (Sprache als Ordner bzw. Parameter).

## Festlegungen (mit dem Repo-Inhaber abgestimmt)

| Thema | Entscheidung |
|---|---|
| Sprache | nur Deutsch |
| Ton | Sprecherstimme per quelloffener, lokal laufender Sprachsynthese. Erst ein Hörtest (S0), der Inhaber wählt die Stimme. Reicht keine, wird die Stimme getauscht (bezahlter Dienst oder selbst eingesprochen), ohne die Pipeline umzubauen. |
| Bild | echte App-Bildschirme mit Beispieldaten, per Skript animiert (Zoom, Texteinblendung, Untertitel). Keine KI-generierten Szenen, keine erfundene Oberfläche. |
| Umfang | Pipeline + 5 Videos, Video 1 ist das Pilotvideo mit Abnahme |
| Künftige Funktionen | als Teaser „Kommt bald“, ohne Datum |
| Stimme (15.11.2026) | OmniVoice (Standard-Engine von VoiceStudio) mit fester Stimmvorlage; Piper und Chatterbox sind im Hörtest durchgefallen. Welche der drei Stimmen, ist offen. |
| Untertitel (16.11.2026) | keine, in keinem Short. Einblendungen und Hervorhebungen einzelner Kernaussagen bleiben. |
| Bewegung (16.11.2026) | echte Bildfolgen aus der App (Timer tickt, Tipp löst den Zustandswechsel aus) statt Standbilder mit Zoom; die App ist ab dem ersten Bild zu sehen, eine Aussage je Video, Ziel 11 bis 15 Sekunden. |

## Was es schon gibt (wiederverwenden, nicht neu bauen)

- `mobile/tool/store_screenshots/`: rendert die echten Flutter-Seiten als PNG 1080 × 1920, ohne Android-SDK
  (`flutter test tool/store_screenshots`). `store_data.dart` enthält einen erfundenen, stimmigen Datensatz und eine
  feste Uhr (Mi 11.11.2026, 16:40). Beschreibung: `mobile/CLAUDE.md`, „Store-Screenshots (#559)“.
- `branding/`: Logo als SVG, Primärfarbe `#1565C0`, Schrift Open Sans, Slogan „Deine Arbeitszeit. Dein Überblick.“
- `fastlane/metadata/android/de-DE/full_description.txt`: die geprüfte Liste dessen, was die App kann und was
  Free bzw. Premium ist. Sie ist die Quelle für jede Aussage in einem Video.
- `ffmpeg` ist in der Cloud-Umgebung installiert, Chromium und Playwright ebenfalls.

## Regeln für alle Videos

1. **Nur wahre Aussagen.** Ein Video behauptet nur, was in der Store-Beschreibung steht und in der
   veröffentlichten Version funktioniert. Vor jedem Video gegen `full_description.txt` prüfen.
2. **Free und Premium sauber trennen.** Zeigt ein Video eine Premium-Funktion, sagt oder zeigt es das („mit Premium“).
3. **Keine Preise**, solange der Inhaber keinen nennt. Kein „kostenlos“ für Premium-Funktionen.
4. **Keine Rechts- oder Steuerberatung.** Pausenregel nur als das, was die App tut („ergänzt 30 Minuten ab
   6 Stunden“), nicht als Rechtsauskunft. Die App ersetzt keine betriebliche Zeiterfassung; das darf kein Video
   anders darstellen.
5. **Nur Android und Web.** Es gibt keine iOS-App. Schlusskarte: „Kostenlos bei Google Play“ und
   `work-time-manager.app`. Kein Apple-Logo, kein „im App Store“.
6. **Teaser** zeigen keine nachgebaute Oberfläche einer Funktion, die es noch nicht gibt, und nennen kein Datum.
7. **Keine echten Daten.** Nur der Datensatz aus `store_data.dart`.
8. **Sprache:** Du-Form, kurze Sätze, kein Werbe-Superlativ. Ein Video dauert 11 bis 15 Sekunden (erste Fassung des
   Plans: 20 bis 35; nach dem ersten Pilotvideo verkürzt).

## Technisches Format

- 1080 × 1920 (9:16), 30 Bilder/s, MP4 (H.264, `yuv420p`), Ton AAC 48 kHz, Lautheit auf −14 LUFS normalisiert.
- Schutzzonen: oben 250 px und unten 420 px ohne wichtigen Text (dort liegen die Bedienelemente der Plattformen).
  Der App-Bildschirm steht deshalb verkleinert (ca. 78 % Breite, abgerundete Ecken, Schatten) auf Markengrund,
  nicht formatfüllend.
- Aufbau jedes Videos: Aufhänger in den ersten 2 Sekunden als Text über der laufenden App (keine eigene Textkarte),
  eine Aussage mit zwei bis drei Szenen aus echten Bildfolgen, Schlusskarte mit Logo und Handlungsaufruf (ca. 2,5 s).
- Keine Untertitel (Entscheidung 16.11.2026). Die Kernaussage steht als große Hervorhebung im Bild.
- Zeitsteuerung kommt aus dem Ton: Jeder Satz wird einzeln synthetisiert, seine Länge bestimmt die Szenendauer.
  Dadurch braucht es keine nachträgliche Wort-Ausrichtung.

## Ordnerstruktur (neu)

```
marketing/shorts/
  README.md            Aufruf, Aufbau einer Videobeschreibung, Regeln oben in Kurzform
  videos/de/<id>.yaml  eine Datei je Video: Szenen, Sprechtext, Bild, Bewegung, Untertitel
  frames/de/           App-Bilder aus dem Flutter-Werkzeug (eingecheckt, wie die Store-Screenshots)
  tts/                 Sprachsynthese: Skript, Aussprache-Liste, Lizenzangaben
  src/                 Videokomposition
  posts/de/<id>.md     Beitragstext, Hashtags, Vorschaubild-Text je Video
  out/                 fertige MP4 und Zwischendateien (nicht eingecheckt, .gitignore)
mobile/tool/shorts_frames/   Flutter-Werkzeug für die App-Bilder (neben store_screenshots)
```

## Schritte

Reihenfolge: S0, S1 und S2 können gleichzeitig starten. S3 braucht alle drei. Danach S4, S5, S6.

| Schritt | Inhalt | Modell | Abnahme durch Inhaber |
|---|---|---|---|
| S0 | Hörtest Sprachsynthese | Sonnet | ja, Stimme wählen |
| S1 | Videokomposition (Grundgerüst) | Opus | nein |
| S2 | App-Bilder aus Flutter | Opus | nein |
| S3 | Pilotvideo (Video 1) | Opus | ja, Stil, Tempo, Ton |
| S4 | Videos 2 bis 4 | Sonnet | ja, je Video |
| S5 | Teaser (Video 5) | Sonnet | ja |
| S6 | Dauerbetrieb: Workflow, Release-Schritt, Themenliste | Sonnet | nein |

### S0 – Hörtest Sprachsynthese

**Ziel:** Der Inhaber hört dieselben Sätze von zwei bis drei Stimmen und wählt eine.

- Kandidaten (alle lokal lauffähig): **Piper** mit deutscher Stimme (z. B. „Thorsten“; sehr schnell auf der CPU),
  **Chatterbox Multilingual** (klingt natürlicher, rechnet länger). Ein dritter Kandidat nach eigener Recherche
  ist erlaubt.
- **Lizenz zuerst prüfen**, getrennt für Programm und Stimmmodell: Die Videos sind Werbung, die Stimme muss
  gewerblich nutzbar sein. Modelle mit „nur nicht-kommerziell“ scheiden aus (das betrifft nach heutigem
  Kenntnisstand z. B. XTTS-v2 und die F5-TTS-Gewichte; selbst nachprüfen, nicht aus diesem Plan übernehmen).
  Ergebnis als Tabelle in `marketing/shorts/tts/LIZENZEN.md` mit Link und Abrufdatum.
- Testtext (fest, damit Stimmen vergleichbar sind): drei Sätze mit den schwierigen Wörtern, z. B. „Work Time
  Manager“, „Home-Office“, „Überstunden-Saldo“, „PDF“, „16:40 Uhr“, „plus 12 Stunden 45“.
- `marketing/shorts/tts/aussprache.yaml`: Ersetzungsliste vor der Synthese (Uhrzeiten, Zahlen, englische Wörter,
  Abkürzungen), damit die Stimme sie richtig spricht.
- Schnittstelle, die später alle Schritte nutzen: `tts/synth` nimmt eine Videobeschreibung und schreibt je Satz
  eine WAV-Datei plus `dauer.json`. Liegt für einen Satz schon eine Datei unter `videos/de/<id>/stimme/` (selbst
  eingesprochen oder von einem anderen Dienst), wird sie genommen statt synthetisiert.
- **Übergabe:** die WAV-Dateien der Kandidaten an den Inhaber, dazu Rechenzeit je Satz und die Lizenztabelle.
- **Fertig, wenn:** der Inhaber eine Stimme gewählt hat oder entscheidet, selbst einzusprechen bzw. einen
  bezahlten Dienst zu nehmen. In beiden Fällen bleibt die Schnittstelle gleich.

### S1 – Videokomposition (Grundgerüst)

**Ziel:** `npm run render -- <id>` in `marketing/shorts/` erzeugt aus `videos/de/<id>.yaml` ein fertiges MP4.

- Werkzeug: **Remotion** (React, rendert über Chromium, verbreitet und gut dokumentiert). Vorher prüfen: (a) die
  Lizenz erlaubt die Nutzung (für Einzelpersonen und sehr kleine Firmen kostenlos; aktuellen Text lesen),
  (b) ein 2-Sekunden-Probevideo rendert in der Cloud-Umgebung mit dem vorinstallierten Chromium
  (`/opt/pw-browsers/chromium`). Scheitert eines von beiden: gleiche Bausteine als HTML/CSS-Seite, Bild für Bild
  mit Playwright aufgenommen und mit `ffmpeg` zusammengesetzt. Die Videobeschreibung bleibt in beiden Fällen gleich.
- Bausteine: Aufhänger-Karte, Szene mit App-Bild (Einblenden, langsamer Zoom auf einen benannten Ausschnitt,
  Tipp-Markierung), Texteinblendung, Untertitel, Premium-Kennzeichen, Schlusskarte, Teaser-Karte „Kommt bald“.
- Farben, Schrift und Logo aus `branding/` beziehen, nicht kopieren und nicht neu festlegen.
- Videobeschreibung (YAML) mit Schema und Prüfung: unbekannte Felder, fehlendes Bild oder ein Satz ohne Ton sind
  Fehler mit klarer Meldung, kein stilles Weiterrendern.
- Tonspur: Sätze in Reihenfolge, optional Musik aus `musik/` (leiser unter der Stimme), Lautheit normalisieren.
  Ohne Musikdatei entsteht das Video ohne Musik.
- Kleine Tests (`node --test`) für Schema-Prüfung und Zeitberechnung; keine Abhängigkeit von Datum oder Zeitzone.
- **Fertig, wenn:** ein Probevideo mit Platzhalterbild und Testton durchläuft und das README den Aufruf beschreibt.

### S2 – App-Bilder aus Flutter

**Ziel:** `flutter test tool/shorts_frames` (aus `mobile/`) schreibt alle benötigten App-Bilder nach
`marketing/shorts/frames/de/`.

- Aufbau wie `tool/store_screenshots/`; `store_data.dart` und die Hilfen daraus gemeinsam nutzen (auslagern statt
  kopieren). Die Store-Screenshots dürfen sich dadurch nicht ändern (vorher/nachher vergleichen).
- Bilder mit sprechendem Namen statt Nummer, z. B. `dashboard_timer_laeuft.png`, `dashboard_vor_start.png`,
  `stop_pause_ergaenzt.png`, `tagesbericht.png`, `wochenbericht.png`, `trend_prognose.png`, `jahresvergleich.png`,
  `jahr_pdf_menue.png`, `arbeitsorte.png`, `einstellungen_profile.png`, `dashboard_dunkel.png`. Die genaue Liste
  ergibt sich aus den Videos unten; nur erzeugen, was ein Video braucht.
- Zustände „vorher/nachher“ (z. B. vor und nach dem Tippen auf Start) als zwei Bilder; die Bewegung dazwischen
  macht die Komposition. Echte Bildfolgen aus Flutter (Bild für Bild über `tester.pump`) nur, wenn das Pilotvideo
  zeigt, dass Standbilder zu statisch wirken.
- Feste Uhr und fester Datensatz wie bei den Store-Screenshots, damit die Bilder nicht vom Ausführungstag abhängen.
- Checks: `flutter analyze --no-fatal-infos`, `dart format tool/shorts_frames tool/store_screenshots`; Abschnitt in
  `mobile/CLAUDE.md` neben „Store-Screenshots“ ergänzen.
- **Fertig, wenn:** jedes Bild angesehen wurde (kein Überlauf, keine leeren Karten, keine Fehlermeldung im Bild).

### S3 – Pilotvideo (Video 1)

**Ziel:** ein fertiges Video zur Abnahme von Stil, Tempo und Stimme, bevor vier weitere entstehen.

- Video 1 aus der Tabelle unten vollständig: Sprechtext, Videobeschreibung, Ton, Rendern, Beitragstext.
- Vor der Übergabe selbst prüfen: Video Bild für Bild an drei Stellen ansehen (Anfang, Mitte, Schlusskarte),
  Untertitel decken sich mit dem Ton, nichts liegt in den Schutzzonen, Lautheit stimmt, Länge 20 bis 35 s.
- **Übergabe:** das MP4 an den Inhaber (`SendUserFile`), dazu der Sprechtext.
- **Fertig, wenn:** der Inhaber abgenommen hat. Änderungswünsche an Stil und Tempo fließen in die Bausteine aus
  S1, nicht nur in dieses eine Video.

### S4 – Videos 2 bis 4

Je Video ein kleiner PR: Sprechtext, Videobeschreibung, ggf. neue App-Bilder, Beitragstext. Sprechtext vor dem
Rendern gegen die „Regeln für alle Videos“ prüfen. Jedes Video geht einzeln zur Abnahme.

### S5 – Teaser (Video 5)

Baustein „Kommt bald“ aus S1 nutzen. Gezeigt werden vorhandene Bildschirme (z. B. Arbeitszeit-Profile als das,
was es heute schon gibt) und Schrift, keine Oberfläche der neuen Funktion. Kein Datum, keine Zusage zum Umfang.

### S6 – Dauerbetrieb

- GitHub-Workflow `shorts.yml` mit `workflow_dispatch` (Eingabe: Video-ID oder „alle“): rendert und lädt die MP4
  als Artefakt hoch. So kommt der Inhaber ohne Cloud-Session an die Dateien. Kein Lauf bei Push, kein Teil der CI.
- `.claude/release.md` bzw. `CONTRIBUTING.md`, „Release“: neuer Punkt „App-Bilder für Shorts neu erzeugen, falls
  sich eine gezeigte Seite geändert hat; für die wichtigste neue Funktion ein Video anlegen“.
- `marketing/shorts/THEMEN.md`: Themenliste (unten) mit Status, dazu ein einfacher Redaktionsplan (Vorschlag:
  3 Beiträge je Woche, dasselbe Video auf allen drei Plattformen).
- Beitragstexte: je Video Titel, 1 bis 2 Sätze, 3 bis 5 Hashtags (z. B. `#arbeitszeit #überstunden #zeiterfassung
  #homeoffice #gleitzeit`), Link-Hinweis.

## Die ersten 5 Videos

Die Aufhänger sind Vorschläge; der endgültige Sprechtext entsteht im jeweiligen Schritt und wird abgenommen.

| Nr. | ID | Aufhänger | Zeigt | Free/Premium |
|---|---|---|---|---|
| 1 | `feierabend` | „Wann hast du heute eigentlich Feierabend?“ | Start per Tipp, laufender Timer, voraussichtliche Feierabendzeit, Überstunden live, Widget erwähnen | Free |
| 2 | `pausen` | „Pause vergessen einzutragen? Schon wieder?“ | Stoppen ohne Pause, App ergänzt 30 Min. ab 6 Std. bzw. 45 Min. ab 9 Std., Pausen-Timer | Free |
| 3 | `ueberstunden` | „Wie viele Überstunden hast du wirklich?“ | Gleitzeitkonto Soll/Ist (Free), dann Trend und Prognose zum Jahresende (Premium, gekennzeichnet) | Free → Premium |
| 4 | `pdf` | „Dein Stundenzettel als PDF. In zehn Sekunden.“ | Jahres-Tab, PDF-Export-Menü, Wochen-/Monats-/Jahresbericht, Home-Office-Auswertung | Premium |
| 5 | `teaser-projekte` | „Freelancer? Das hier kommt bald.“ | Teaser für Projekte/Kunden (#286): Zeiten je Projekt, Auswertung je Projekt | Teaser |

Video 1 und 2 sollen Installationen bringen (breites Problem, kostenlose Lösung), 3 und 4 zeigen den Wert von
Premium, 5 spricht eine neue Zielgruppe an.

### Weitere Themen (für `THEMEN.md`, nach der ersten Charge)

Home-Office-Tage fürs Jahr zählen (passt zum Jahreswechsel; ohne Steuer-Aussagen), Feiertage nach Bundesland,
Urlaub für eine ganze Woche in einem Schritt, Haupt- und Nebenjob mit getrennten Profilen, Timer per Google
Assistant, Home-Screen-Widget, Jahresvergleich mit dem Vorjahr, Insights (Wochentage, Startzeiten),
„Keine Werbung, keine Datenweitergabe“ mit App-Sperre, Web-App im Browser, Dunkelmodus. Teaser: Kalender-Export
(#275), weitere Widgets (#281), eigene Pausenregeln (#283).

## Was der Inhaber von Hand macht

- Stimme wählen (S0) und Videos abnehmen (S3 bis S5).
- Konten bei TikTok, Instagram und YouTube anlegen; hochladen und veröffentlichen. Das Modell lädt nichts hoch.
- Beim Hochladen die Kennzeichnungsregeln der Plattform für KI-erzeugte Inhalte beachten (synthetische Stimme).
- Falls Musik gewünscht: eine Datei mit Lizenz für gewerbliche Nutzung in `marketing/shorts/musik/` legen, mit
  Quelle und Lizenz in einer Textdatei daneben. Alternativ die Musik der Plattform beim Hochladen wählen.
- Erfolg messen: Play-Store-Link im Profil mit Kampagnen-Parameter
  (`…&referrer=utm_source%3Dtiktok%26utm_medium%3Dshort`), Auswertung in der Play Console unter Nutzergewinnung.

## Offene Entscheidungen (mit Empfehlung; das Modell arbeitet mit der Empfehlung weiter, bis anders entschieden)

- Musik: Empfehlung zunächst ohne eigene Musik rendern und die Musik der Plattform nutzen.
- Remotion-Lizenz: Empfehlung nutzen, wenn die Prüfung in S1 sie für ein Ein-Personen-Projekt bestätigt.
- Teaser-Thema: Empfehlung Projekte/Kunden (#286), weil es mit Freelancern eine neue Zielgruppe anspricht.
- Fertige MP4 im Repo: Empfehlung nein (Größe); Ablage als Workflow-Artefakt, Beschreibung und Bilder im Repo.

## Nicht Teil dieses Plans

Englische Videos, bezahlte Anzeigen, automatisches Hochladen, Videos mit Personen, Änderungen an der App selbst.
