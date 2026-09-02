# Versionshinweise für den Play Store

`de-DE.txt` enthält die Versionshinweise (Änderungsprotokoll), die
`flutter-production.yml` beim Play-Store-Upload als „Neuigkeiten in dieser
Version" für den jeweiligen Track hinterlegt (Input `whatsNewDirectory` der
Action `r0adkll/upload-google-play`).

**Vor jedem Release aktualisieren:** Bevor der Release-Branch
(`release/v<Version>-<Charakter>`) nach `main` gemerged wird, `de-DE.txt`
mit den Versionshinweisen für genau dieses Release überschreiben und
committen.

- Max. 500 Zeichen (Play-Store-Limit).
- Nur Deutsch (`de-DE`) — die App hat kein i18n-System.
- Der Inhalt gilt für den kompletten Upload-Schritt, unabhängig vom
  Track-Namen — es gibt keine Historie über mehrere Releases hinweg, die
  Datei beschreibt immer nur das *aktuell hochzuladende* Release.
