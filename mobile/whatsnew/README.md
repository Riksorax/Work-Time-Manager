# Versionshinweise für den Play Store

`whatsnew-de-DE` enthält die Versionshinweise (Änderungsprotokoll), die
`flutter-production.yml` beim Play-Store-Upload als „Neuigkeiten in dieser
Version" für den jeweiligen Track hinterlegt (Input `whatsNewDirectory` der
Action `r0adkll/upload-google-play`).

**Vor jedem Release aktualisieren:** Bevor der Release-Branch
(`release/v<Version>-<Charakter>`) nach `main` gemerged wird, `whatsnew-de-DE`
mit den Versionshinweisen für genau dieses Release überschreiben und
committen.

- Max. 500 Zeichen (Play-Store-Limit).
- Nur Deutsch (`de-DE`). Die App selbst ist seit #221 zweisprachig, im Play Store
  wird aber bisher nur der deutsche Text hinterlegt.
- Der Inhalt gilt für den kompletten Upload-Schritt, unabhängig vom
  Track-Namen — es gibt keine Historie über mehrere Releases hinweg, die
  Datei beschreibt immer nur das *aktuell hochzuladende* Release.

## Dateiname (wichtig)

Die Action `r0adkll/upload-google-play` liest aus `whatsNewDirectory` **nur** Dateien nach dem
Muster `whatsnew-<LOCALE>` (BCP 47, ohne Dateiendung), z. B. `whatsnew-de-DE`. Eine Datei mit
anderem Namen wird stillschweigend ignoriert: Bis 1.8.3 hieß sie `de-DE.txt`, der Upload lief
grün durch, und in der Play Console kamen keine Versionshinweise an. Eine weitere Sprache
bräuchte eine zusätzliche Datei, z. B. `whatsnew-en-US`.
