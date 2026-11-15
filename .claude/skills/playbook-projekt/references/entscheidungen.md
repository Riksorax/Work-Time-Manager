# Work-Time-Manager — Architektur-Entscheidungen

Dauerhafte Entscheidungen des Repo-Inhabers. Sie gelten für jedes Issue, solange das Issue nichts anderes festlegt.
Einzelheiten zu einem Feature (Vertrag, Kriterien) stehen im jeweiligen Issue, nicht hier.

## Logik ins Backend (14.11.2026)

- Neue Rechen- und Auswertungslogik entsteht **nur** in `server/.../Domain/`. Web und Mobile rufen den Endpunkt auf und
  stellen dar; sie rechnen nicht nach. Das gilt auch für abgeleitete Werte wie Differenzen, Prozentwerte, Summen je Monat
  oder zusammengefasste Zeiträume: Sie gehören in die Antwort des Endpunkts.
- **Angemeldete Nutzer, Free wie Premium,** bekommen berechnete Werte vom Backend. Ziel ist, die Last und die Logik in den
  Clients klein zu halten und Abweichungen zwischen den Plattformen auszuschließen.
- **Im Client bleibt nur:**
  - der Gast-Modus (nicht angemeldet, kein Server): lokale Speicherung und lokale Berechnung der Free-Funktionen. Diese
    lokale Rechnung folgt denselben Regeln wie das Backend;
  - alles, was im Sekundentakt oder ohne Netz reagieren muss (laufender Timer, voraussichtliches Arbeitsende);
  - Darstellung: Formatierung, Sprache, Diagramm-Zeichnung, Sortierung bereits geladener Daten.
- Für neue, vom Backend gerechnete Funktionen gibt es **keinen Offline-Fallback** im Client: Lade-, Fehler- (mit „Erneut
  versuchen“) und Leerzustand.
- Bezugsdatum („heute“) schickt der Client im Request mit. Das Backend rechnet nicht mit der Server-Uhr, damit die Regeln
  testbar bleiben.

## Premium

- Das Premium-Gate liegt **nur in den Clients** (`isPremiumProvider`, `ProfileService.isPremium`). Das Backend prüft Premium
  bei keinem Endpunkt. Eine Prüfung im Backend wäre eine eigene Entscheidung und ein eigenes Issue.
- Premium setzt die Anmeldung voraus. Premium-Funktionen brauchen deshalb keinen Gast-Modus.

## API-Verträge und Felder

- Nur additive Änderungen. Play-Store-Versionen im Umlauf senden ältere Formen.
- **Optionale Felder beim Schreiben:** fehlt das Feld oder ist es `null`, bleibt der gespeicherte Wert erhalten (im Backend über
  `MergeFields`, Vorbild `isHomeOffice`). Ein Text-Feld wird mit `""` gelöscht (Vorbild `bundesland`). Ein Client sendet ein
  Feld nur, wenn der Nutzer es in diesem Vorgang gesetzt hat; Schnelleintrag und Batch senden es nicht.
- **Optionale Felder beim Lesen:** fehlend = Standardwert. Keine Migration von Bestandsdaten.
- Bestehende Endpunkte werden erweitert, wenn die neuen Daten fachlich dazugehören; sonst ein neuer Endpunkt. Bestehende
  Felder ändern nie ihre Bedeutung.
- Kalendertage ohne Uhrzeit gehen als `yyyy-MM-dd` über die Leitung, Zeiträume in Berichten als UTC-Mitternacht wie in den
  bestehenden Report-DTOs, Dauern in Millisekunden.

## Berichte und Auswertungen

- **Es gibt keine Historie des Gleitzeit-Saldos.** Gespeichert ist nur der aktuelle Stand (`overtime/balance`), der auch von
  Hand korrigiert wird. Auswertungen zeigen deshalb Überstunden eines Zeitraums, nie einen rekonstruierten historischen Saldo.
- Das Soll entsteht nur für Tage mit Eintrag an einem Vertrags-Wochentag; das Backend kennt keine Feiertagslogik. Neue
  Auswertungen übernehmen diese Regel, statt eine zweite einzuführen. **Ausnahme Abwesenheit (#535):** Ein Eintrag Urlaub,
  Krank oder Feiertag gilt an jedem Tag, auch an einem freien, mit dem Tagessoll als geleistet und als Soll; er erzeugt nie
  Über- oder Minusstunden (manuelle Überstunden am Eintrag zählen weiter). Ein Tag zählt höchstens einmal.
- **Monats-Gesamtüberstunden = gespeicherter Gleitzeit-Saldo (#535).** Der Saldo enthält den laufenden Monat schon; die
  Monatsüberstunden werden nicht dazugerechnet.
- Frühere Einstellungen (Wochenstunden, Arbeitstage, Urlaubsanspruch) sind nicht gespeichert. Auswertungen über vergangene
  Zeiträume rechnen mit den heutigen Einstellungen und sagen das, wo es das Ergebnis beeinflusst (z. B. Resturlaub nur für das
  laufende Jahr).
- Wochen sind ISO-Wochen; Schlüssel `yyyy-Www` mit ISO-Wochenjahr.

## Oberfläche

- **Schlank bleiben.** Das Dashboard bekommt keine zusätzlichen Auswertungen, Diagramme oder Prognosen. Auswertungen gehören
  in die Berichte. Neue Elemente im Dashboard brauchen die Zustimmung des Repo-Inhabers und sind, wo sinnvoll, über die
  Einstellungen abschaltbar (Standard: an, wenn es das bisherige Verhalten ist).
- **Screenshots für jede UI- und UX-Änderung (14.11.2026):** Der Repo-Inhaber will jede sichtbare Änderung ansehen, bevor sie
  gemergt wird. Jeder PR, der Oberfläche oder Bedienung ändert (neuer Bildschirm, Dialog, Bottom Sheet, Karte, Button, Text mit
  Layout-Wirkung, geänderter Ablauf), liefert Screenshots: vorher und nachher, wo es ein Vorher gibt; die wichtigen Zustände
  (leer, gefüllt, Fehler, gesperrt/Free); Hell- und Dunkelmodus; Deutsch, dazu Englisch, wenn der Text das Layout verändert;
  im Web zusätzlich eine schmale (Handy-)Breite. Web: mit Playwright aufnehmen. Mobile: in Cloud-Sessions gibt es kein Gerät,
  deshalb den Bildschirm im Widget-Test als Bild rendern; ein Bild vom echten Gerät ersetzt das nicht und wird im PR als offen
  vermerkt. Reine Logik-, Backend- und Test-PRs brauchen keine Screenshots.
- **Diagramme:** Web als eigene SVG-Komponente ohne Chart-Bibliothek; Mobile mit `fl_chart`. Jedes Diagramm hat eine
  Textalternative für Screenreader und funktioniert im Hell- und Dunkelmodus.
- **Export:** Mobile erzeugt PDFs mit `pdf`/`printing` (`pdf_report_service.dart`). Das Web hat keine PDF-Bibliothek und nutzt
  eine Druckansicht (`window.print()`, Druck-CSS `.print-area`/`.print-only`).
- **Sprachsteuerung (Android):** eine Capability `OPEN_APP_FEATURE` mit Stichwort-Abgleich in `AssistantTimerIntent`. Antworten
  erscheinen als Ansicht in der App; eine Sprachausgabe gibt es nicht. Der Abgleich prüft mit „enthält“: Neue Stichwörter
  immer gegen die vorhandenen prüfen (das Stop-Wort „end“ steckt z. B. in „Trend“).

## Plattformen

- Nur Android und Web. iOS ausschließlich nach Freigabe (`konventionen.md`, #484).
- Funktionen erscheinen auf Web und Mobile, außer sie hängen an einer Geräte-Fähigkeit (Widgets, Assistant, Benachrichtigungen).
