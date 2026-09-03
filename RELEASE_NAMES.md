# Release-Namen
 
Jedes Release im geschlossenen Test (Play-Track `<Version> <Charakter>`) trägt den Namen
`<Version> <Charakter>` — der Charakter stammt aus Kingdom Hearts.
 
## Wie ein Name vergeben wird
 
Der Charakter kommt aus dem Namen des Release-Branches:
 
```
release/v1.3.2-Vanitas        ->  Release- und Track-Name "1.3.2 Vanitas"
release/v1.4.0-Micky-Maus     ->  Release- und Track-Name "1.4.0 Micky Maus"
```
 
Alles vor dem ersten `-` ist die Version, alles danach der Charakter;
Bindestriche im Charakternamen werden zu Leerzeichen.
 
`version-bump.yml` prüft beim Push auf den Release-Branch, ob der Charakter
unter „Noch frei" steht, verschiebt ihn nach „Vergeben" und committet das
zusammen mit der Versionsnummer. `flutter-production.yml` liest den Namen
später aus der Tabelle unten und übergibt ihn beim Play-Upload als `track` und
`releaseName` — der Branch-Name ist zu diesem Zeitpunkt nicht mehr verfügbar,
weil der Workflow auf `main` läuft.
 
> **Wichtig:** Der geschlossene Test-Track mit dem Namen `<Version> <Charakter>`
> (z. B. `1.3.2 Vanitas`) muss vorab in der Google Play Console unter
> *Testen > Geschlossene Tests* erstellt und mit Testern verknüpft sein!
> Die Play Developer API kann keine neuen Tracks anlegen — das ist nur
> manuell in der Console möglich.

Steht der Charakter nicht in der Frei-Liste, bricht der Bump mit einer
Fehlermeldung ab. Namen werden also nie doppelt vergeben.

Vor dem Mergen des Release-Branches nach `main` außerdem
`mobile/whatsnew/de-DE.txt` mit den Versionshinweisen für dieses Release
aktualisieren — siehe `mobile/whatsnew/README.md`. `flutter-production.yml`
lädt den Inhalt beim Play-Upload automatisch als Änderungsprotokoll mit hoch.

## Vergeben

| Version | Charakter | Datum |
| --- | --- | --- |
| 1.3.4 | Marluxia | 2026-09-03 |
| 1.3.3 | Larxene | 2026-09-01 |
| 1.3.2 | Vanitas | 2026-08-24 |
| 1.3.1 | — | 2026-08-21 |
| 1.1.0 | Micky Maus | 2026-05-25 |
| 0.24.1 | Sora | 2026-05-13 |
| 0.24.1 | Chirithy | 2026-03-15 |
| 0.24.0 | Axel | 2026-03-14 |
| 0.18.1 | Ansem the Wise | 2026-01-07 |
| 0.17.0 | Xemnas | 2025-12-31 |
| 0.16.0 | Master Xehanort | 2025-12-30 |
| 0.15.0 | Roxas | 2025-12-30 |
| 0.13.3 | Xion | 2025-12-22 |
| 0.11.1 | Namine | 2025-10-26 |
| 0.06.0 | Ventus | 2025-10-21 |
| 0.05.0 | Terra | 2025-10-19 |
| 0.03.0 | Aqua | 2025-10-04 |
| 0.02.3 | Kairi | 2025-09-30 |
| 0.02.2 | Riku | 2025-09-30 |

> Zwei Anmerkungen zu den Altdaten:
>
> - Der Release-Name von Sora lautet in der Console „0.24.1 Sora", die
>   App-Version war jedoch 1.0.0. Die Versionsspalte gibt hier den
>   Release-Namen wieder, nicht die App-Version — deshalb steht 0.24.1
>   zweimal in der Tabelle.
> - 1.3.1 ging als „Alpha" heraus, weil der Workflow damals noch keinen
>   Release-Namen übergab. Genau das ist inzwischen behoben.

## Noch frei

Einige Einträge sind alternative Identitäten derselben Figur (Lea/Axel,
Isa/Saix). Ist eine Variante vergeben, sollte die andere nicht mehr
verwendet werden, auch wenn die Prüfung sie formal durchlässt.

- Luxord
- Demyx
- Zexion
- Lexaeus
- Vexen
- Xigbar
- Xaldin
- Saix
- Isa
- Lea
- Eraqus
- Ienzo
- Even
- Aeleus
- Dilan
- Braig
- Donald
- Goofy
- Minnie Maus
- Daisy
- Pluto
- Chip
- Chap
- Jiminy
- Yen Sid
- Merlin
- Cid
- Leon
- Yuffie
- Aerith
- Tifa
- Cloud
- Sephiroth
- Strelitzia
- Ephemer
- Skuld
- Lauriam
- Elrena
- Brain
- Ava
- Invi
- Gula
- Aced
- Ira
- Luxu
